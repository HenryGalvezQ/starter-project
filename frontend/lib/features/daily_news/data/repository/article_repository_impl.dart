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
  final FirebaseAuth _auth;          // NUEVO: Para saber el UID del usuario
  final FirebaseStorage _storage;    // NUEVO: Para subir imágenes

  ArticleRepositoryImpl(
    this._newsApiService, 
    this._appDatabase, 
    this._firestore,
    this._auth,
    this._storage
  );

  // --- MÉTODOS EXISTENTES (Feed Global & Saved) ---

  @override
  Future<DataState<List<ArticleModel>>> getNewsArticles() async {
    try {
      // Leemos de Firestore (Feed Global)
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('articles')
          .orderBy('publishedAt', descending: true) // Ordenar por fecha
          .get();

      if (snapshot.docs.isNotEmpty) {
        final articles = snapshot.docs.map((doc) {
          final data = doc.data();
          // Importante: Asignar el status 'synced' porque vienen de la nube
          data['syncStatus'] = 'synced'; 
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
    // Como ArticleModel no tiene copyWith manual, lo reconstruimos:
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
      // Mantenemos status existente o default
      syncStatus: article.syncStatus ?? 'synced', 
      localImagePath: article.localImagePath,
      
      isSaved: true, // <--- AQUÍ ESTÁ LA CLAVE DEL ARREGLO
    );

    return _appDatabase.articleDAO.insertArticle(model);
  }

  // --- NUEVOS MÉTODOS OFFLINE-FIRST (Fase 5) ---

  @override
  Future<List<ArticleEntity>> getMyArticles() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      // 1. Obtener artículos LOCALES pendientes (Lo que aún no sube)
      final localPending = await _appDatabase.articleDAO.getPendingArticles();

      // 2. Obtener artículos REMOTOS (Lo que ya está en la nube)
      // Query: articles where userId == my_uid
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

      // 3. Fusionar listas (Locales primero para feedback inmediato)
      return [...localPending, ...remoteArticles];

    } catch (e) {
      print("ERROR GETTING MY ARTICLES: $e");
      // Si falla la red, al menos retornamos los locales pendientes
      return await _appDatabase.articleDAO.getPendingArticles();
    }
  }

  @override
  Future<void> syncPendingArticles() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Obtener cola de salida
    final pendingArticles = await _appDatabase.articleDAO.getPendingArticles();

    if (pendingArticles.isEmpty) {
      print("SYNC: Nada pendiente.");
      return;
    }

    print("SYNC: Iniciando sincronización de ${pendingArticles.length} artículos...");

    for (final article in pendingArticles) {
      try {
        String imageUrl = article.urlToImage ?? "";

        // PASO A: Subir Imagen (Si hay una ruta local)
        if (article.localImagePath != null && article.localImagePath!.isNotEmpty) {
          final file = File(article.localImagePath!);
          if (await file.exists()) {
            // Ruta Storage: media/articles/{uid}/{timestamp}.jpg
            final storageRef = _storage
                .ref()
                .child('media/articles/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
            
            await storageRef.putFile(file);
            imageUrl = await storageRef.getDownloadURL();
            print("SYNC: Imagen subida -> $imageUrl");
          }
        }

        // PASO B: Subir Data a Firestore
        // Importante: Usamos el UID del Auth para cumplir el Schema
        final docRef = _firestore.collection('articles').doc(); // Auto-ID
        
        await docRef.set({
          'userId': user.uid,
          'author': user.displayName ?? "Symmetry Journalist",
          'title': article.title,
          'description': article.description,
          'content': article.content,
          'publishedAt': article.publishedAt,
          'urlToImage': imageUrl,
          'category': 'general', // Default o mapeado
          'likesCount': 0,
          'syncStatus': 'synced',
          // Usamos el ID del documento como 'url' lógica para deep-linking futuro
          'url': 'symmetry://article/${docRef.id}' 
        });

        // PASO C: Actualizar Local DB
        // Cambiamos estado a 'synced' para que no se vuelva a subir
        await _appDatabase.articleDAO.updateSyncStatus(article.url!, 'synced');
        
        print("SYNC: Artículo '${article.title}' sincronizado exitosamente.");

      } catch (e) {
        print("SYNC ERROR en artículo ${article.title}: $e");
        // No borramos ni cambiamos estado, se reintentará en la próxima
      }
    }
  }

  @override
  Future<void> createLocalArticle(ArticleEntity article) {
    // Reconstruimos para asegurar estados iniciales correctos de un reporte nuevo
    final model = ArticleModel(
      // Si no tiene ID (o es nulo), Floor lo autogenerará si es int, 
      // pero como usamos 'url' como PK, debemos asegurar que tenga una única.
      url: article.url, // El UUID lo generaremos en el Bloc/UI
      author: article.author,
      title: article.title,
      description: article.description,
      content: article.content,
      publishedAt: article.publishedAt,
      urlToImage: article.urlToImage ?? "", 
      
      // VALORES CRÍTICOS PARA OFFLINE
      syncStatus: 'pending', // Nace pendiente de subida
      localImagePath: article.localImagePath, // Guardamos ruta de foto local
      isSaved: false, // No es un favorito, es un reporte propio
      likesCount: 0,
    );

    return _appDatabase.articleDAO.insertArticle(model);
  }
}