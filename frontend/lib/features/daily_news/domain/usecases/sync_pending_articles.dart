import 'package:news_app_clean_architecture/core/usecase/usecase.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/repository/article_repository.dart';

class SyncPendingArticlesUseCase implements UseCase<void, void> {
  final ArticleRepository _articleRepository;

  SyncPendingArticlesUseCase(this._articleRepository);

  @override
  Future<void> call({void params}) {
    return _articleRepository.syncPendingArticles();
  }
}