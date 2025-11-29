import 'package:equatable/equatable.dart';
import '../../../../domain/entities/article.dart';

abstract class LocalArticlesEvent extends Equatable {
  final ArticleEntity ? article;

  const LocalArticlesEvent({this.article});

  @override
  List<Object> get props => [article!];
}

class GetSavedArticles extends LocalArticlesEvent {
  const GetSavedArticles();
}

class RemoveArticle extends LocalArticlesEvent {
  const RemoveArticle(ArticleEntity article) : super(article: article);
}

class SaveArticle extends LocalArticlesEvent {
  const SaveArticle(ArticleEntity article) : super(article: article);
}

class SyncSavedArticles extends LocalArticlesEvent {
  const SyncSavedArticles();
}

// Obtener likes al iniciar
class GetLikedArticles extends LocalArticlesEvent {
  const GetLikedArticles();
}

// Dar o Quitar Like (Trigger del Switch)
class ToggleLikeArticle extends LocalArticlesEvent {
  final ArticleEntity article;
  final bool isLiked; // true = like, false = dislike
  
  const ToggleLikeArticle({required this.article, required this.isLiked});
}

// Sincronización completa (Inicio de sesión / App Start)
class SyncLocalDatabase extends LocalArticlesEvent {
  const SyncLocalDatabase();
}

// [NUEVO - FIX SITUACIÓN 4] Limpiar estado en RAM al cerrar sesión
class ResetLocalState extends LocalArticlesEvent {
  const ResetLocalState();
}