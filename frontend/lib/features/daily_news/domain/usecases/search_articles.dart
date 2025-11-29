import 'package:news_app_clean_architecture/core/usecase/usecase.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/repository/article_repository.dart';

class SearchArticlesUseCase implements UseCase<List<ArticleEntity>, String> {
  final ArticleRepository _articleRepository;

  SearchArticlesUseCase(this._articleRepository);

  @override
  Future<List<ArticleEntity>> call({String? params}) {
    // Si la búsqueda viene vacía, no devolvemos nada o devolvemos todo según prefieras.
    // Aquí asumimos que si llama al usecase es porque hay texto.
    return _articleRepository.searchLocalArticles(params ?? "");
  }
}