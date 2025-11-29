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

  // [NUEVO] Semáforo para evitar doble ejecución (Race Condition)
  bool _isSyncing = false;

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
      // ESTRICTO OFFLINE-FIRST:
      // Leemos SOLO de local. ¿Por qué?
      // 1. Velocidad instantánea.
      // 2. Consistencia: Si borramos un item offline ('pending_delete'), Floor lo oculta.
      //    Si leyéramos de la nube (remote), el item "reviviría" porque aún no se ha borrado en Firestore.
      // 3. El SyncWorker se encarga en segundo plano de traer novedades y actualizar Floor.
      
      final localArticles = await _appDatabase.articleDAO.getArticlesByUser(user.uid);
      return localArticles;

    } catch (e) {
      print("ERROR GETTING ARTICLES: $e");
      return [];
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

  // --- NUEVO: UPDATE (Offline First) ---
  @override
  Future<void> updateLocalArticle(ArticleEntity article) {
    final user = _auth.currentUser;
    
    // Al editar, lo ponemos en 'pending' para que el SyncWorker lo suba (Upsert)
    // Mantenemos el mismo URL (ID) para sobrescribir.
    final model = ArticleModel.fromEntity(article).copyWith(
      userId: user?.uid,
      syncStatus: 'pending', 
    );
    
    return _appDatabase.articleDAO.insertArticle(model); // Insert con Replace
  }

  // --- NUEVO: DELETE (Offline First - Soft Delete) ---
  @override
  Future<void> deleteLocalArticle(ArticleEntity article) async {
    // No borramos físicamente. Marcamos como 'pending_delete'.
    // El DAO de lectura filtrará esto para que desaparezca de la UI inmediatamente.
    await _appDatabase.articleDAO.updateSyncStatus(article.url!, 'pending_delete');
  }

  // --- SYNC ENGINE BLINDADO (Mutex Lock) ---
  @override
  Future<void> syncPendingArticles() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. [CRÍTICO] Verificar si ya hay una sincronización en curso
    if (_isSyncing) {
      print("⏳ SYNC: Sincronización en curso. Ignorando llamada duplicada.");
      return;
    }

    // 2. Bloquear el semáforo
    _isSyncing = true;

    try {
      // ---------------------------------------------------------
      // PASO 1: PUSH (SUBIDA) - Enviar cambios locales a la nube
      // ---------------------------------------------------------
      final pendingArticles = await _appDatabase.articleDAO.getPendingArticlesByUser(user.uid);

      if (pendingArticles.isNotEmpty) {
        print("SYNC PUSH: Procesando ${pendingArticles.length} cambios locales...");
        
        for (final article in pendingArticles) {
          try {
            // --- LÓGICA DE BORRADO ---
            if (article.syncStatus == 'pending_delete') {
              print("SYNC: Borrando ${article.title} de la nube...");
              
              // Borrar imagen
              if (article.urlToImage != null && article.urlToImage!.contains('firebase')) {
                try {
                  await _storage.refFromURL(article.urlToImage!).delete();
                } catch (e) { print("Error borrando imagen (no crítica): $e"); }
              }
              
              // Borrar documento(s)
              final q = await _firestore.collection('articles').where('url', isEqualTo: article.url).get();
              for (var doc in q.docs) {
                await doc.reference.delete();
              }
              
              // Borrar local
              await _appDatabase.articleDAO.deleteArticle(article);
              continue;
            }

            // --- LÓGICA DE CREACIÓN / EDICIÓN ---
            
            // [FIX ADICIONAL] Doble check: Verificar si ya existe en Firestore ANTES de subir imagen
            // Esto ayuda si el semáforo fallara por alguna razón extrema (reinicio de app a mitad de proceso)
            final qCheck = await _firestore.collection('articles').where('url', isEqualTo: article.url).get();
            
            String imageUrl = article.urlToImage ?? "";
            
            // Subir imagen solo si es local
            if (article.localImagePath != null && article.localImagePath!.isNotEmpty) {
              final file = File(article.localImagePath!);
              if (await file.exists()) {
                // Si ya existe el doc remoto y tiene imagen, tratamos de no duplicar basura en Storage,
                // pero por simplicidad subimos la nueva versión.
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

            DocumentReference docRef;
            if (qCheck.docs.isNotEmpty) {
               docRef = qCheck.docs.first.reference;
            } else {
               docRef = _firestore.collection('articles').doc();
            }

            await docRef.set({
              'userId': user.uid,
              'author': article.author,
              'title': article.title,
              'description': article.description,
              'category': article.category ?? 'General',
              'content': article.content,
              'publishedAt': article.publishedAt,
              'urlToImage': imageUrl,
              'likesCount': article.likesCount ?? 0,
              'syncStatus': 'synced',
              'url': article.url
            }, SetOptions(merge: true));

            final syncedArticle = article.copyWith(
              urlToImage: imageUrl,
              syncStatus: 'synced',
              localImagePath: null 
            );
            await _appDatabase.articleDAO.insertArticle(syncedArticle);
            print("SYNC PUSH: Sincronizado ${article.title}");

          } catch (e) {
            print("SYNC PUSH ERROR en ${article.title}: $e");
          }
        }
      }

      // ---------------------------------------------------------
      // PASO 2: PULL (BAJADA) - Traer artículos de la nube al local
      // ---------------------------------------------------------
      // ... (El código de PULL se mantiene exactamente igual) ...
      print("SYNC PULL: Buscando artículos remotos para rehidratar local...");
      try {
        final remoteSnapshot = await _firestore
            .collection('articles')
            .where('userId', isEqualTo: user.uid)
            .get();

        for (final doc in remoteSnapshot.docs) {
          final remoteData = doc.data();
          remoteData['syncStatus'] = 'synced'; 
          
          final remoteModel = ArticleModel.fromJson(remoteData);
          final localArticle = await _appDatabase.articleDAO.findArticleByUrl(remoteModel.url!);

          if (localArticle == null) {
            await _appDatabase.articleDAO.insertArticle(remoteModel);
            print("SYNC PULL: Descargado ${remoteModel.title}");
          } else {
            if (localArticle.syncStatus == 'synced') {
               final merged = remoteModel.copyWith(
                 id: localArticle.id,
                 isSaved: localArticle.isSaved,
                 isLiked: localArticle.isLiked,
                 localImagePath: localArticle.localImagePath
               );
               await _appDatabase.articleDAO.insertArticle(merged);
            }
          }
        }
      } catch (e) {
        print("SYNC PULL ERROR: $e");
      }

    } finally {
      // 3. [CRÍTICO] Liberar el semáforo SIEMPRE, haya error o no.
      _isSyncing = false;
      print("🏁 SYNC: Proceso finalizado. Semáforo libre.");
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
      final savedSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_articles')
          .get();

      if (savedSnapshot.docs.isEmpty) return;

      for (final doc in savedSnapshot.docs) {
        final articleUrl = doc.data()['articleUrl'] as String?;
        if (articleUrl == null) continue;

        // A. Verificar si ya lo tenemos en local
        final localArticle = await _appDatabase.articleDAO.findArticleByUrl(articleUrl);
        
        // PRESERVAMOS EL LIKE SI YA EXISTE
        final bool preserveLiked = localArticle?.isLiked ?? false; // [NUEVO]
        final int currentLikes = localArticle?.likesCount ?? 0;

        if (localArticle != null) {
          // Si existe, actualizamos isSaved=true manteniendo isLiked
          if (localArticle.isSaved != true) {
             final updated = ArticleModel(
                userId: user.uid, 
                id: localArticle.id,
                author: localArticle.author,
                title: localArticle.title,
                description: localArticle.description,
                url: localArticle.url,
                urlToImage: localArticle.urlToImage,
                publishedAt: localArticle.publishedAt,
                content: localArticle.content,
                
                likesCount: currentLikes, // Mantenemos contador
                syncStatus: localArticle.syncStatus,
                localImagePath: localArticle.localImagePath,
                category: localArticle.category,
                
                isSaved: true,     // <--- ACTIVAMOS
                isLiked: preserveLiked // <--- PRESERVAMOS [CRÍTICO]
             );
             await _appDatabase.articleDAO.insertArticle(updated);
          }
        } else {
          // B. Si NO existe en local, descargamos
          final articleQuery = await _firestore
              .collection('articles')
              .where('url', isEqualTo: articleUrl)
              .limit(1)
              .get();

          if (articleQuery.docs.isNotEmpty) {
            final articleData = articleQuery.docs.first.data();
            articleData['syncStatus'] = 'synced';
            
            var newModel = ArticleModel.fromJson(articleData);
            newModel = ArticleModel(
                userId: user.uid, 
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
                
                isSaved: true,  // <--- ACTIVAMOS
                isLiked: false, // Por defecto false, SyncLiked lo arreglará si es necesario
            );
            await _appDatabase.articleDAO.insertArticle(newModel);
          }
        }
      }
    } catch (e) {
      print("SYNC SAVED ERROR: $e");
    }
  }

  @override
  Future<void> syncLikedArticles() async {
    final user = _auth.currentUser;
    if (user == null) return;

    print("SYNC: Descargando LIKES de la nube...");
    try {
      final likedSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('liked_articles')
          .get();

      if (likedSnapshot.docs.isEmpty) return;

      for (final doc in likedSnapshot.docs) {
        final articleId = doc.id;

        // 1. Descargar info remota
        final remoteArticleSnap = await _firestore.collection('articles').doc(articleId).get();
        if (!remoteArticleSnap.exists) continue;

        final articleData = remoteArticleSnap.data()!;
        articleData['syncStatus'] = 'synced';
        var model = ArticleModel.fromJson(articleData);

        // 2. [CORRECCIÓN CRÍTICA] VERIFICAR ESTADO LOCAL PREVIO
        // Antes de sobrescribir, miramos si SyncSaved ya pasó por aquí
        final existingLocal = await _appDatabase.articleDAO.findArticleByUrl(model.url!);
        final bool preserveSaved = existingLocal?.isSaved ?? false; // Recuperamos estado Saved
        final String? existingLocalPath = existingLocal?.localImagePath;

        // 3. FUSIONAR ESTADO
        model = ArticleModel(
            userId: user.uid,
            url: model.url,
            author: model.author,
            title: model.title,
            description: model.description,
            content: model.content,
            urlToImage: model.urlToImage,
            publishedAt: model.publishedAt,
            likesCount: model.likesCount,
            category: model.category,
            syncStatus: 'synced',
            localImagePath: existingLocalPath, // Preservamos imagen local si hay
            
            isSaved: preserveSaved, // <--- AQUÍ ESTÁ EL FIX (Usamos el valor preservado)
            isLiked: true           // <--- ACTIVAMOS
        );

        await _appDatabase.articleDAO.insertArticle(model);
      }
      print("SYNC: Likes sincronizados correctamente.");
    } catch (e) {
      print("SYNC LIKES ERROR: $e");
    }
  }

  @override
  Future<List<ArticleEntity>> getLikedArticles() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    return _appDatabase.articleDAO.getLikedArticlesByUser(user.uid);
  }


  // --- CORRECCIÓN DE LA TRANSACCIÓN (Anti-Duplicados) ---
  @override
  Future<void> likeArticle(ArticleEntity article, bool isLiked) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Local (Optimista) - IGUAL QUE ANTES
    final localModel = ArticleModel(
        // ... copia tus campos ...
        userId: user.uid,
        id: article.id,
        author: article.author,
        title: article.title,
        description: article.description,
        url: article.url,
        urlToImage: article.urlToImage,
        publishedAt: article.publishedAt,
        content: article.content,
        // UI Optimista
        likesCount: (article.likesCount ?? 0) + (isLiked ? 1 : -1),
        syncStatus: 'synced',
        localImagePath: article.localImagePath,
        isSaved: article.isSaved,
        isLiked: isLiked, 
        category: article.category ?? 'General',
    );
    await _appDatabase.articleDAO.insertArticle(localModel);

    // 2. TRANSACCIÓN BLINDADA
    try {
       // Buscar referencia por URL si id no es confiable, o usar id si lo es.
       // Asumimos búsqueda por URL para consistencia
       QuerySnapshot snapshot = await _firestore.collection('articles').where('url', isEqualTo: article.url).get();
       if (snapshot.docs.isEmpty) return;
       
       final docRef = snapshot.docs.first.reference;
       // Referencia al registro de like del usuario
       final userLikeRef = _firestore.collection('users').doc(user.uid).collection('liked_articles').doc(snapshot.docs.first.id);

       await _firestore.runTransaction((transaction) async {
        final articleSnapshot = await transaction.get(docRef);
        final userLikeSnapshot = await transaction.get(userLikeRef); // LEEMOS SI YA EXISTE

        if (!articleSnapshot.exists) return;

        int currentLikes = articleSnapshot.data() is Map 
            ? (articleSnapshot.get('likesCount') ?? 0) : 0;

        // LÓGICA DE PROTECCIÓN:
        // Solo sumamos si la UI dice "Like" Y no existe registro en base de datos.
        // Esto previene que si la UI está desincronizada (botón gris) pero la DB dice que ya diste like, sumes doble.
        
        if (isLiked && !userLikeSnapshot.exists) {
           // Caso Real: Usuario da Like y no lo tenía
           transaction.update(docRef, {'likesCount': currentLikes + 1});
           transaction.set(userLikeRef, {'likedAt': FieldValue.serverTimestamp()});
        } 
        else if (!isLiked && userLikeSnapshot.exists) {
           // Caso Real: Usuario quita Like y sí lo tenía
           int newCount = currentLikes > 0 ? currentLikes - 1 : 0;
           transaction.update(docRef, {'likesCount': newCount});
           transaction.delete(userLikeRef);
        }
        // Si (isLiked && userLikeSnapshot.exists) -> La UI estaba mal (gris), pero ya tenía like. NO HACEMOS NADA en el contador remoto, pero la UI local ya se arregló en el paso 1.
      });

    } catch (e) {
      print("TRANSACTION ERROR: $e");
    }
  }

    @override
  Future<List<ArticleEntity>> searchLocalArticles(String query) async {
    return _appDatabase.articleDAO.searchArticles(query);
  }
}

// Extensión para copyWith (Ayuda a copiar objetos inmutables)
extension ArticleModelCopyWith on ArticleModel {
  ArticleModel copyWith({
    int? id, // <--- AÑADIDO: El parámetro que faltaba
    String? userId, String? author, String? title, String? description,
    String? url, String? urlToImage, String? publishedAt, String? content,
    int? likesCount, String? syncStatus, String? localImagePath,
    bool? isSaved, bool? isLiked, String? category
  }) {
    return ArticleModel(
      id: id ?? this.id, // <--- CORREGIDO: Usa el argumento o el actual
      userId: userId ?? this.userId,
      author: author ?? this.author,
      title: title ?? this.title,
      description: description ?? this.description,
      url: url ?? this.url,
      urlToImage: urlToImage ?? this.urlToImage,
      publishedAt: publishedAt ?? this.publishedAt,
      content: content ?? this.content,
      likesCount: likesCount ?? this.likesCount,
      syncStatus: syncStatus ?? this.syncStatus,
      localImagePath: localImagePath ?? this.localImagePath,
      isSaved: isSaved ?? this.isSaved,
      isLiked: isLiked ?? this.isLiked,
      category: category ?? this.category,
    );
  }

  
}