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

  // MODIFICADO: Excluimos los que están marcados para borrar ('pending_delete')
  // para que la UI no los muestre aunque sigan en la DB esperando sync.
  @Query("SELECT * FROM article WHERE userId = :userId AND syncStatus != 'pending_delete' ORDER BY publishedAt DESC")
  Future<List<ArticleModel>> getArticlesByUser(String userId);

  // MODIFICADO: Ahora traemos 'pending' (para subir/editar) Y 'pending_delete' (para borrar)
  @Query("SELECT * FROM article WHERE (syncStatus = 'pending' OR syncStatus = 'pending_delete') AND userId = :userId")
  Future<List<ArticleModel>> getPendingArticlesByUser(String userId);

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