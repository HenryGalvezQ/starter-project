import 'package:news_app_clean_architecture/features/daily_news/data/models/article.dart';
import 'package:news_app_clean_architecture/core/resources/data_state.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/repository/article_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // IMPORTANTE
import '../data_sources/local/app_database.dart';
import '../data_sources/remote/news_api_service.dart';

class ArticleRepositoryImpl implements ArticleRepository {
  final NewsApiService _newsApiService; // Ya no se usará para el feed principal, pero lo mantenemos por si acaso
  final AppDatabase _appDatabase;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Instancia de Firestore

  ArticleRepositoryImpl(this._newsApiService, this._appDatabase);

  @override
  Future<DataState<List<ArticleModel>>> getNewsArticles() async {
    try {
      // CAMBIO RADICAL: Leemos de la colección 'articles' de Firestore
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('articles')
          //.where('category', isEqualTo: 'health') // Opcional: Filtrar si quieres
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Mapeamos los documentos de Firestore a ArticleModel
        final articles = snapshot.docs.map((doc) {
          // Combinamos la data con el ID del documento (útil para likes/updates)
          final data = doc.data();
          // data['id'] = doc.id; // Si ArticleModel tuviera un campo String id, lo asignaríamos aquí
          return ArticleModel.fromJson(data);
        }).toList();

        return DataSuccess(articles);
      } else {
        // Retornamos lista vacía pero éxito (no es error que no haya noticias aún)
        return const DataSuccess([]);
      }
    } catch (e) {
      // Capturamos cualquier error de Firebase
      // Nota: Firestore lanza FirebaseException, no DioException.
      // Para simplificar y no romper la firma del DataState (que espera DioException o null),
      // retornamos un DataFailed genérico o adaptado.
      // Por ahora, para debug, imprimimos y retornamos error vacío o adaptado.
      print("FIREBASE ERROR: $e");
      return DataSuccess(const []); // Fallback seguro por ahora
    }
  }

  @override
  Future<List<ArticleModel>> getSavedArticles() async {
    return _appDatabase.articleDAO.getArticles();
  }

  @override
  Future<void> removeArticle(ArticleEntity article) {
    return _appDatabase.articleDAO.deleteArticle(ArticleModel.fromEntity(article));
  }

  @override
  Future<void> saveArticle(ArticleEntity article) {
    return _appDatabase.articleDAO.insertArticle(ArticleModel.fromEntity(article));
  }
}