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

// NUEVO: Evento para actualizar
class UpdateExistingArticle extends MyArticlesEvent {
  final ArticleEntity article;
  const UpdateExistingArticle(this.article);
}

// NUEVO: Evento para borrar
class DeleteExistingArticle extends MyArticlesEvent {
  final ArticleEntity article;
  const DeleteExistingArticle(this.article);
}

class SyncMyArticles extends MyArticlesEvent {
  const SyncMyArticles();
}