import 'package:news_app_clean_architecture/core/usecase/usecase.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/repository/article_repository.dart';

class GetLikedArticlesUseCase implements UseCase<List<ArticleEntity>, void> {
  final ArticleRepository _articleRepository;

  GetLikedArticlesUseCase(this._articleRepository);

  @override
  Future<List<ArticleEntity>> call({void params}) {
    // Asegúrate de haber agregado 'getLikedArticles' a tu interfaz ArticleRepository
    return _articleRepository.getLikedArticles(); 
  }
}