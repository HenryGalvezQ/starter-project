import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:news_app_clean_architecture/core/resources/data_state.dart';
import 'package:news_app_clean_architecture/features/daily_news/data/models/article.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/repository/article_repository.dart';
import '../data_sources/local/app_database.dart';
import '../data_sources/remote/news_api_service.dart';
import 'package:dio/dio.dart';

class ArticleRepositoryImpl implements ArticleRepository {
  final NewsApiService _newsApiService;
  final AppDatabase _appDatabase;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  ArticleRepositoryImpl(
    this._newsApiService, 
    this._appDatabase, 
    this._firestore,
    this._auth,
    this._storage
  );

  // --- MÉTODOS PÚBLICOS (Feed Global) ---
  // Este no filtra por usuario porque es público para todos
  @override
  Future<DataState<List<ArticleModel>>> getNewsArticles() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('articles')
          .orderBy('publishedAt', descending: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final articles = snapshot.docs.map((doc) {
          final data = doc.data();
          data['syncStatus'] = 'synced';
          return ArticleModel.fromJson(data);
        }).toList();
        return DataSuccess(articles);
      } else {
        return const DataSuccess([]);
      }
    } catch (e) {
      print("FIREBASE ERROR: $e");
      return const DataSuccess([]);
    }
  }

  // --- MÉTODOS LOCALES (Favoritos) ---

  @override
  Future<List<ArticleModel>> getSavedArticles() async {
    final user = _auth.currentUser;
    if (user == null) return []; // Si no hay usuario, no hay favoritos

    // DATA ISOLATION: Solo traemos los favoritos de ESTE usuario
    return _appDatabase.articleDAO.getSavedArticlesByUser(user.uid);
  }

@override
  Future<void> saveArticle(ArticleEntity article) async {
    final user = _auth.currentUser;
    
    // 1. LOCAL: Guardamos en Floor (Siempre funciona, con o sin internet)
    final model = ArticleModel(
      userId: user?.uid,
      id: article.id,
      author: article.author,
      title: article.title,
      description: article.description,
      url: article.url, // Usamos esto como ID único
      urlToImage: article.urlToImage,
      publishedAt: article.publishedAt,
      content: article.content,
      likesCount: article.likesCount,
      syncStatus: article.syncStatus ?? 'synced', 
      localImagePath: article.localImagePath,
      isSaved: true,
      category: article.category ?? 'General',
    );
    
    await _appDatabase.articleDAO.insertArticle(model);

    // 2. CLOUD: Si estamos logueados, guardamos la referencia en Firestore
    if (user != null && article.url != null) {
      try {
        // Usamos encodeURIComponent o hash si la URL tiene caracteres raros, 
        // pero por simplicidad usaremos la URL tal cual como ID del documento si es segura,
        // o mejor, dejamos que Firestore genere el ID y guardamos la URL como campo.
        // ESTRATEGIA: Usar la URL como ID del documento requiere que sea válida para rutas.
        // Para evitar errores de caracteres invalidos en rutas URL, usaremos un hash o ID limpio.
        // Pero como tus URLs generadas son "symmetry://...", son seguras excepto por los slashes.
        // MEJOR OPCIÓN: Guardar el documento usando un ID generado o limpiado.
        // Para este MVP, guardaremos un documento con el campo 'articleUrl'.
        
        // Referencia: users/{uid}/saved_articles/{article_url_safe}
        // Truco: Reemplazamos / por _ para usarlo como ID de documento
        final safeId = article.url!.replaceAll('/', '_').replaceAll(':', '_');

        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('saved_articles')
            .doc(safeId) // ID del documento = URL "sanitizada"
            .set({
              'articleUrl': article.url,
              'savedAt': FieldValue.serverTimestamp(),
              'title': article.title, // Guardamos título para referencia rápida en consola
            });
            
        print("☁️ CLOUD: Artículo guardado en perfil de usuario.");
      } catch (e) {
        print("⚠️ CLOUD SAVE ERROR: $e (Pero se guardó localmente)");
        // No lanzamos excepción para no romper la UX local
      }
    }
  }

  @override
  Future<void> removeArticle(ArticleEntity article) async {
    final user = _auth.currentUser;

    // 1. LOCAL
    await _appDatabase.articleDAO.deleteArticle(ArticleModel.fromEntity(article));

    // 2. CLOUD
    if (user != null && article.url != null) {
      try {
        final safeId = article.url!.replaceAll('/', '_').replaceAll(':', '_');
        
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('saved_articles')
            .doc(safeId)
            .delete();
            
        print("☁️ CLOUD: Artículo eliminado del perfil.");
      } catch (e) {
        print("⚠️ CLOUD REMOVE ERROR: $e");
      }
    }
  }

  // --- MÉTODOS OFFLINE-FIRST ---

  @override
  Future<List<ArticleEntity>> getMyArticles() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      // 1. Locales pendientes (FILTRADO POR USUARIO)
      final localPending = await _appDatabase.articleDAO.getPendingArticlesByUser(user.uid);

      // 2. Remotos (Nube) - Ya filtra por userId en la query
      final remoteSnapshot = await _firestore
          .collection('articles')
          .where('userId', isEqualTo: user.uid)
          .orderBy('publishedAt', descending: true)
          .get();

      final remoteArticles = remoteSnapshot.docs.map((doc) {
        final data = doc.data();
        data['syncStatus'] = 'synced';
        return ArticleModel.fromJson(data);
      }).toList();

      // 3. Fusionar
      return [...localPending, ...remoteArticles];

    } catch (e) {
      print("ERROR GETTING MY ARTICLES: $e");
      // Fallback: Si no hay red, traemos TODO lo local de este usuario
      return await _appDatabase.articleDAO.getArticlesByUser(user.uid);
    }
  }

  @override
  Future<void> createLocalArticle(ArticleEntity article) {
    final user = _auth.currentUser;
    // Si displayName es null, usamos el email, o un default
    final String authorName = user?.displayName != null && user!.displayName!.isNotEmpty 
        ? user.displayName! 
        : (user?.email?.split('@')[0] ?? "Symmetry Reporter");

    // DATA ISOLATION: El reporte nace firmado por el autor
    final model = ArticleModel(
      userId: user?.uid, // <--- CRÍTICO
      url: article.url, 
      author: authorName,
      category: article.category ?? 'General',
      title: article.title,
      description: article.description,
      content: article.content,
      publishedAt: article.publishedAt,
      urlToImage: article.urlToImage ?? "", 
      syncStatus: 'pending',
      localImagePath: article.localImagePath,
      isSaved: false, 
      likesCount: 0,
    );

    return _appDatabase.articleDAO.insertArticle(model);
  }

  @override
  Future<void> syncPendingArticles() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // DATA ISOLATION: Solo subimos lo que pertenece al usuario actual
    final pendingArticles = await _appDatabase.articleDAO.getPendingArticlesByUser(user.uid);

    if (pendingArticles.isEmpty) {
      print("SYNC: Nada pendiente para el usuario ${user.email}.");
      return;
    }

    final userName = user.displayName ?? user.email ?? "Usuario";
    print("SYNC: Sincronizando ${pendingArticles.length} artículos de $userName...");

    for (final article in pendingArticles) {
      try {
        String imageUrl = article.urlToImage ?? "";

        // PASO A: Subir Imagen
        if (article.localImagePath != null && article.localImagePath!.isNotEmpty) {
          final file = File(article.localImagePath!);
          if (await file.exists()) {
            final storageRef = _storage
                .ref()
                .child('media/articles/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
            
            await storageRef.putFile(
              file,
              SettableMetadata(contentType: 'image/jpeg', customMetadata: {'uploaded_by': user.uid}),
            );
            imageUrl = await storageRef.getDownloadURL();
          }
        }

        // PASO B: Subir Data
        final docRef = _firestore.collection('articles').doc(); 
        
        await docRef.set({
          'userId': user.uid, // Firma en la nube
          'author': article.author, // Usamos el nombre local que ya inyectamos al crear
          'title': article.title,
          'description': article.description,
          'category': article.category ?? 'General',
          'content': article.content,
          'publishedAt': article.publishedAt,
          'urlToImage': imageUrl,
          'likesCount': 0,
          'syncStatus': 'synced',
          'url': 'symmetry://article/${docRef.id}' 
        });

        // PASO C: Actualizar Local
        await _appDatabase.articleDAO.updateSyncStatus(article.url!, 'synced');
        print("SYNC: Completado para ${article.title}");

      } catch (e) {
        print("SYNC ERROR: $e");
      }
    }
  }

  @override
  Future<void> clearLocalData() async {
    await _appDatabase.articleDAO.deleteAllArticles();
    print("🗑️ LOCAL DATA: Base de datos limpiada.");
  }
  
  @override
  Future<void> syncSavedArticles() async {
    final user = _auth.currentUser;
    if (user == null) return;

    print("SYNC: Descargando favoritos de la nube...");

    try {
      // 1. Obtener lista de IDs guardados por el usuario
      final savedSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_articles')
          .get();

      if (savedSnapshot.docs.isEmpty) return;

      // 2. Para cada guardado, asegurar que esté en local
      for (final doc in savedSnapshot.docs) {
        final articleUrl = doc.data()['articleUrl'] as String?;
        if (articleUrl == null) continue;

        // A. Verificar si ya lo tenemos en local
        final localArticle = await _appDatabase.articleDAO.findArticleByUrl(articleUrl);
        
        if (localArticle != null) {
          // Si existe, solo actualizamos el flag isSaved
          if (localArticle.isSaved != true) {
             // Truco: Re-insertar con isSaved=true (OnConflict.replace actualiza)
             final updated = ArticleModel(
                userId: user.uid, // Aseguramos propiedad
                id: localArticle.id,
                author: localArticle.author,
                title: localArticle.title,
                description: localArticle.description,
                url: localArticle.url,
                urlToImage: localArticle.urlToImage,
                publishedAt: localArticle.publishedAt,
                content: localArticle.content,
                likesCount: localArticle.likesCount,
                syncStatus: localArticle.syncStatus,
                localImagePath: localArticle.localImagePath,
                category: localArticle.category,
                isSaved: true, // <--- ACTIVAMOS
             );
             await _appDatabase.articleDAO.insertArticle(updated);
          }
        } else {
          // B. Si NO existe en local, hay que descargarlo de la colección 'articles'
          // (Esta es la parte difícil: buscar por URL en Firestore)
          final articleQuery = await _firestore
              .collection('articles')
              .where('url', isEqualTo: articleUrl)
              .limit(1)
              .get();

          if (articleQuery.docs.isNotEmpty) {
            final articleData = articleQuery.docs.first.data();
            articleData['syncStatus'] = 'synced'; // Viene de nube
            
            // Mapeamos a modelo
            var newModel = ArticleModel.fromJson(articleData);
            
            // Forzamos campos locales
            newModel = ArticleModel(
                userId: user.uid, // Asignamos al usuario actual para que lo vea
                url: newModel.url,
                author: newModel.author,
                title: newModel.title,
                description: newModel.description,
                content: newModel.content,
                urlToImage: newModel.urlToImage,
                publishedAt: newModel.publishedAt,
                likesCount: newModel.likesCount,
                category: newModel.category,
                syncStatus: 'synced',
                isSaved: true, // <--- IMPORTANTE
            );
            
            await _appDatabase.articleDAO.insertArticle(newModel);
            print("SYNC: Favorito descargado -> ${newModel.title}");
          }
        }
      }
    } catch (e) {
      print("SYNC SAVED ERROR: $e");
    }
  }
}