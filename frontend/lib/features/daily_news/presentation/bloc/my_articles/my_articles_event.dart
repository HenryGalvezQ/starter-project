import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';

abstract class MyArticlesEvent {
  const MyArticlesEvent();
}

class LoadMyArticles extends MyArticlesEvent {
  const LoadMyArticles();
}

class SaveNewArticle extends MyArticlesEvent {
  final ArticleEntity article;
  const SaveNewArticle(this.article);
}

class SyncMyArticles extends MyArticlesEvent {
  const SyncMyArticles();
}