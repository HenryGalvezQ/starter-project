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
  @Query('SELECT * FROM article')
  Future<List<ArticleModel>> getAllArticles();

  @Query('SELECT * FROM article WHERE url = :url')
  Future<ArticleModel?> findArticleByUrl(String url);

  // --- LECTURA FILTRADA POR USUARIO (My Reports) ---
  // ESTE SÍ NECESITA USERID (Solo quiero ver lo que YO escribí)
  @Query("SELECT * FROM article WHERE userId = :userId AND syncStatus != 'pending_delete' ORDER BY publishedAt DESC")
  Future<List<ArticleModel>> getArticlesByUser(String userId);

  @Query("SELECT * FROM article WHERE (syncStatus = 'pending' OR syncStatus = 'pending_delete') AND userId = :userId")
  Future<List<ArticleModel>> getPendingArticlesByUser(String userId);

  // --- CORRECCIÓN AQUÍ (SAVED) ---
  // Quitamos el parámetro userId y la condición WHERE userId.
  // "Dame todo lo que marqué como guardado, sin importar quién lo escribió".
  @Query("SELECT * FROM article WHERE isSaved = 1")
  Future<List<ArticleModel>> getSavedArticles(); 

  // --- MANTENIMIENTO ---
  @Query("UPDATE article SET syncStatus = :status WHERE url = :url")
  Future<void> updateSyncStatus(String url, String status);

  @Query('DELETE FROM article')
  Future<void> deleteAllArticles();

  // --- CORRECCIÓN AQUÍ (LIKED) ---
  // Igual aquí: "Dame todo lo que marqué con like".
  @Query("SELECT * FROM article WHERE isLiked = 1")
  Future<List<ArticleModel>> getLikedArticles();

  // [Buscador]
  @Query("SELECT * FROM article WHERE (title LIKE '%' || :query || '%' OR author LIKE '%' || :query || '%' OR description LIKE '%' || :query || '%' OR content LIKE '%' || :query || '%') AND syncStatus != 'pending_delete' ORDER BY publishedAt DESC")
  Future<List<ArticleModel>> searchArticles(String query);
}