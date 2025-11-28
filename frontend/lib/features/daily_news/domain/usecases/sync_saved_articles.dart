import 'package:news_app_clean_architecture/core/usecase/usecase.dart';
import '../repository/article_repository.dart';

class SyncSavedArticlesUseCase implements UseCase<void, void> {
  final ArticleRepository _articleRepository;
  SyncSavedArticlesUseCase(this._articleRepository);

  @override
  Future<void> call({void params}) {
    return _articleRepository.syncSavedArticles();
  }
}