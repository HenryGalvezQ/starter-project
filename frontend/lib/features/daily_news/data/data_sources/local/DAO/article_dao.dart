import 'package:floor/floor.dart';
import 'package:news_app_clean_architecture/features/daily_news/data/models/article.dart';

@dao
abstract class ArticleDao {
  
  // --- ESCRITURA (Insert/Delete) ---
  
  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertArticle(ArticleModel article);
  
  @delete
  Future<void> deleteArticle(ArticleModel articleModel);

  // --- LECTURA GENERAL ---

  // Obtener TODOS los artículos (Solo para debug o limpieza)
  @Query('SELECT * FROM article')
  Future<List<ArticleModel>> getAllArticles();

  // Buscar por URL (Validación de existencia)
  @Query('SELECT * FROM article WHERE url = :url')
  Future<ArticleModel?> findArticleByUrl(String url);

  // --- LECTURA FILTRADA POR USUARIO (Data Isolation) ---

  // 1. Mis Artículos (Pending + Synced) del usuario actual
  // Ordenados por fecha para el feed "My Reports"
  @Query("SELECT * FROM article WHERE userId = :userId ORDER BY publishedAt DESC")
  Future<List<ArticleModel>> getArticlesByUser(String userId);

  // 2. Cola de Salida: Solo los pendientes de ESTE usuario
  @Query("SELECT * FROM article WHERE syncStatus = 'pending' AND userId = :userId")
  Future<List<ArticleModel>> getPendingArticlesByUser(String userId);

  // 3. Favoritos: Solo los guardados por ESTE usuario
  @Query("SELECT * FROM article WHERE isSaved = 1 AND userId = :userId")
  Future<List<ArticleModel>> getSavedArticlesByUser(String userId);

  // --- MANTENIMIENTO ---

  // Actualizar estado de sincronización
  @Query("UPDATE article SET syncStatus = :status WHERE url = :url")
  Future<void> updateSyncStatus(String url, String status);

  // Limpieza total (Seguridad extra al cerrar sesión)
  @Query('DELETE FROM article')
  Future<void> deleteAllArticles();

  // [NUEVO] Obtener solo los likes de ESTE usuario
  @Query("SELECT * FROM article WHERE isLiked = 1 AND userId = :userId")
  Future<List<ArticleModel>> getLikedArticlesByUser(String userId);
}