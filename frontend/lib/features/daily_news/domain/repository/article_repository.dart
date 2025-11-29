import 'package:news_app_clean_architecture/core/resources/data_state.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';

abstract class ArticleRepository {
  // API methods (Feed Global)
  Future<DataState<List<ArticleEntity>>> getNewsArticles();

  // Database methods (Favoritos)
  Future<List<ArticleEntity>> getSavedArticles();

  // CRUD & Sync
  Future<void> saveArticle(ArticleEntity article);
  Future<void> removeArticle(ArticleEntity article);

  // --- NUEVOS MÉTODOS (Fase 5) ---
  
  // Obtener artículos creados por el usuario actual (Local + Remote logic)
  Future<List<ArticleEntity>> getMyArticles();

  // Forzar la sincronización de artículos 'pending' a la nube
  Future<void> syncPendingArticles();

  // NUEVO: Crear un artículo localmente (My Report)
  Future<void> createLocalArticle(ArticleEntity article);

  // NUEVOS MÉTODOS FASE 9
  Future<void> deleteLocalArticle(ArticleEntity article); // Soft delete
  Future<void> updateLocalArticle(ArticleEntity article); // Update offline

  Future<void> clearLocalData();

  Future<void> syncSavedArticles(); // Traer favoritos de la nube

  // [FALTABA ESTE] Obtener los artículos a los que di like
  Future<List<ArticleEntity>> getLikedArticles();

  Future<void> likeArticle(ArticleEntity article, bool isLiked);
  //Sincronizar likes de la nube al local al iniciar sesión
  Future<void> syncLikedArticles();

  // [NUEVO] Buscar artículos localmente
  Future<List<ArticleEntity>> searchLocalArticles(String query);
}