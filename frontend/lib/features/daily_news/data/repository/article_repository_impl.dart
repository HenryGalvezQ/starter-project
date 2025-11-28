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
  Future<void> saveArticle(ArticleEntity article) {
    final user = _auth.currentUser;
    
    // DATA ISOLATION: Guardamos el favorito firmado con el UID actual
    final model = ArticleModel(
      userId: user?.uid, // <--- CRÍTICO
      id: article.id,
      author: article.author,
      title: article.title,
      description: article.description,
      url: article.url,
      urlToImage: article.urlToImage,
      publishedAt: article.publishedAt,
      content: article.content,
      likesCount: article.likesCount,
      syncStatus: article.syncStatus ?? 'synced', 
      localImagePath: article.localImagePath,
      isSaved: true,
    );
    return _appDatabase.articleDAO.insertArticle(model);
  }

  @override
  Future<void> removeArticle(ArticleEntity article) {
    // Para borrar, convertimos a modelo. Floor usa la PrimaryKey (url) para borrar.
    return _appDatabase.articleDAO.deleteArticle(ArticleModel.fromEntity(article));
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

    // DATA ISOLATION: El reporte nace firmado por el autor
    final model = ArticleModel(
      userId: user?.uid, // <--- CRÍTICO
      url: article.url, 
      author: user?.displayName ?? article.author, // Usamos nombre real del Auth
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

    print("SYNC: Sincronizando ${pendingArticles.length} artículos de ${user.displayName}...");

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
          'author': user.displayName ?? "Symmetry Journalist",
          'title': article.title,
          'description': article.description,
          'content': article.content,
          'publishedAt': article.publishedAt,
          'urlToImage': imageUrl,
          'category': 'general', 
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
}