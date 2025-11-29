import 'package:equatable/equatable.dart';

import '../../../../domain/entities/article.dart';

abstract class LocalArticlesState extends Equatable {
  final List<ArticleEntity>? savedArticles;
  final List<ArticleEntity>? likedArticles; // [NUEVO]

  const LocalArticlesState({this.savedArticles, this.likedArticles});

  @override
  List<Object?> get props => [savedArticles, likedArticles];
}

class LocalArticlesLoading extends LocalArticlesState {
  const LocalArticlesLoading();
}

class LocalArticlesDone extends LocalArticlesState {
  const LocalArticlesDone({
    List<ArticleEntity>? savedArticles, 
    List<ArticleEntity>? likedArticles
  }) : super(savedArticles: savedArticles, likedArticles: likedArticles);
}