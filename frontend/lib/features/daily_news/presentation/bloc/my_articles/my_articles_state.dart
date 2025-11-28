import 'package:equatable/equatable.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';

abstract class MyArticlesState extends Equatable {
  final List<ArticleEntity>? articles;
  final String? error;
  
  const MyArticlesState({this.articles, this.error});
  
  @override
  List<Object?> get props => [articles, error];
}

class MyArticlesLoading extends MyArticlesState {
  const MyArticlesLoading();
}

class MyArticlesLoaded extends MyArticlesState {
  const MyArticlesLoaded(List<ArticleEntity> articles) : super(articles: articles);
}

class MyArticlesError extends MyArticlesState {
  const MyArticlesError(String error) : super(error: error);
}

// Estado especial para confirmar que se guardó exitosamente y limpiar formulario
class ArticleSavedSuccess extends MyArticlesState {
  const ArticleSavedSuccess();
}

// NUEVO: Indica que la sincronización con la nube terminó
class MyArticlesSyncSuccess extends MyArticlesState {
  const MyArticlesSyncSuccess({List<ArticleEntity>? articles}) : super(articles: articles);
}