import 'package:news_app_clean_architecture/core/usecase/usecase.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/repository/article_repository.dart';

class ToggleLikeArticleUseCase implements UseCase<void, ToggleLikeParams> {
  final ArticleRepository _articleRepository;

  ToggleLikeArticleUseCase(this._articleRepository);

  @override
  Future<void> call({ToggleLikeParams? params}) {
    return _articleRepository.likeArticle(params!.article, params.isLiked);
  }
}

class ToggleLikeParams {
  final ArticleEntity article;
  final bool isLiked;
  ToggleLikeParams(this.article, this.isLiked);
}