import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../../../domain/entities/article.dart';

abstract class RemoteArticlesState extends Equatable {
  final List<ArticleEntity>? articles;
  final DioException? error;
  
  const RemoteArticlesState({this.articles, this.error});

  // CORRECCIÓN CRÍTICA:
  // 1. Cambiamos el tipo de retorno a List<Object?> (con interrogación)
  // 2. Quitamos los '!' de las variables. Equatable sabe manejar nulos.
  @override
  List<Object?> get props => [articles, error]; 
}

class RemoteArticlesLoading extends RemoteArticlesState {
  const RemoteArticlesLoading();
}

class RemoteArticlesDone extends RemoteArticlesState {
  const RemoteArticlesDone(List<ArticleEntity> article) : super(articles: article);
}

class RemoteArticlesError extends RemoteArticlesState {
  const RemoteArticlesError(DioException error) : super(error: error);
}