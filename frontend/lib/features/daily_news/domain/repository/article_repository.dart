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
}