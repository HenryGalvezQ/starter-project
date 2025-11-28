import 'package:floor/floor.dart';
import 'package:news_app_clean_architecture/features/daily_news/data/models/article.dart';

@dao
abstract class ArticleDao {
  
  // Inserta o Actualiza (Reemplaza si ya existe el ID/URL)
  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertArticle(ArticleModel article);
  
  // Borrar un artículo específico
  @delete
  Future<void> deleteArticle(ArticleModel articleModel);

  // Obtener TODOS los artículos (Para el Feed Offline y Guardados)
  @Query('SELECT * FROM article')
  Future<List<ArticleModel>> getArticles();

  // Buscar uno por URL (Para validar si ya existe)
  @Query('SELECT * FROM article WHERE url = :url')
  Future<ArticleModel?> findArticleByUrl(String url);

  // --- NUEVOS MÉTODOS PARA SYNC OFFLINE ---

  // 1. Obtener cola de salida (Solo lo que falta subir)
  // Usaremos esto en la Fase 5 para el SyncWorker
  @Query("SELECT * FROM article WHERE syncStatus = 'pending'")
  Future<List<ArticleModel>> getPendingArticles();

  // 2. Actualizar estado de sincronización puntualmente
  // Se llama cuando Firebase confirma "Recibido"
  @Query("UPDATE article SET syncStatus = :status WHERE url = :url")
  Future<void> updateSyncStatus(String url, String status);

  // 3. Obtener solo los GUARDADOS (Bookmarks)
  // Útil para la pestaña 'Saved' si queremos filtrar desde la DB
  @Query("SELECT * FROM article WHERE isSaved = 1")
  Future<List<ArticleModel>> getSavedArticles();
}