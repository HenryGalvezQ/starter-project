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

  @override
  Future<DataState<List<ArticleModel>>> getNewsArticles() async {
    try {
      // Leemos de Firestore (Feed Global)
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('articles')
          .orderBy('publishedAt', descending: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final articles = snapshot.docs.map((doc) {
          final data = doc.data();
          data['syncStatus'] = 'synced'; // Viene de la nube, ya está sincronizado
          return ArticleModel.fromJson(data);
        }).toList();
        return DataSuccess(articles);
      } else {
        return const DataSuccess([]);
      }
    } catch (e) {
      print("FIREBASE ERROR: $e");
      return const DataSuccess([]); // Fallback seguro
    }
  }

  // --- MÉTODOS LOCALES (Favoritos) ---

  @override
  Future<List<ArticleModel>> getSavedArticles() async {
    return _appDatabase.articleDAO.getSavedArticles();
  }

  @override
  Future<void> removeArticle(ArticleEntity article) {
    return _appDatabase.articleDAO.deleteArticle(ArticleModel.fromEntity(article));
  }

  @override
  Future<void> saveArticle(ArticleEntity article) {
    // FIX: Forzamos isSaved = true porque venimos del Feed donde es false/null
    final model = ArticleModel(
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
      isSaved: true, // <--- Importante para la pestaña Saved
    );
    return _appDatabase.articleDAO.insertArticle(model);
  }

  // --- MÉTODOS OFFLINE-FIRST (Fase 5 y 6) ---

  @override
  Future<List<ArticleEntity>> getMyArticles() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      // 1. Locales pendientes
      final localPending = await _appDatabase.articleDAO.getPendingArticles();

      // 2. Remotos (Nube)
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

      // 3. Fusionar (Locales primero)
      return [...localPending, ...remoteArticles];

    } catch (e) {
      print("ERROR GETTING MY ARTICLES: $e");
      // Fallback: solo locales si no hay red
      return await _appDatabase.articleDAO.getPendingArticles();
    }
  }

  @override
  Future<void> createLocalArticle(ArticleEntity article) {
    // Lógica para crear un nuevo reporte (nace pendiente)
    final model = ArticleModel(
      url: article.url, // UUID generado en la UI
      author: article.author,
      title: article.title,
      description: article.description,
      content: article.content,
      publishedAt: article.publishedAt,
      urlToImage: article.urlToImage ?? "", 
      
      // Valores críticos Offline
      syncStatus: 'pending',
      localImagePath: article.localImagePath,
      isSaved: false, // Es un reporte propio, no necesariamente un favorito
      likesCount: 0,
    );

    return _appDatabase.articleDAO.insertArticle(model);
  }

  @override
  Future<void> syncPendingArticles() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final pendingArticles = await _appDatabase.articleDAO.getPendingArticles();

    if (pendingArticles.isEmpty) {
      print("SYNC: Nada pendiente.");
      return;
    }

    print("SYNC: Iniciando sincronización de ${pendingArticles.length} artículos...");

    for (final article in pendingArticles) {
      try {
        String imageUrl = article.urlToImage ?? "";

        // PASO A: Subir Imagen (si existe localmente)
        if (article.localImagePath != null && article.localImagePath!.isNotEmpty) {
          final file = File(article.localImagePath!);
          if (await file.exists()) {
            final storageRef = _storage
                .ref()
                .child('media/articles/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
            
            await storageRef.putFile(
              file,
              SettableMetadata(
                contentType: 'image/jpeg',
                customMetadata: {'uploaded_by': user.uid},
              ),
            );
            imageUrl = await storageRef.getDownloadURL();
            print("SYNC: Imagen subida -> $imageUrl");
          } else {
            print("⚠️ SYNC: Archivo local no encontrado (se omitirá imagen).");
          }
        }

        // PASO B: Subir Data a Firestore
        final docRef = _firestore.collection('articles').doc(); // Auto-ID
        
        await docRef.set({
          'userId': user.uid,
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

        // PASO C: Actualizar Local DB a 'synced'
        await _appDatabase.articleDAO.updateSyncStatus(article.url!, 'synced');
        print("SYNC: Artículo '${article.title}' sincronizado.");

      } catch (e) {
        print("SYNC ERROR en ${article.title}: $e");
      }
    }
  }
}