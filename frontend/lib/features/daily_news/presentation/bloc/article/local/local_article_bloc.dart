import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/local/local_article_event.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/local/local_article_state.dart';

import '../../../../domain/usecases/get_saved_article.dart';
import '../../../../domain/usecases/remove_article.dart';
import '../../../../domain/usecases/save_article.dart';
import '../../../../domain/usecases/sync_saved_articles.dart'; // Import

class LocalArticleBloc extends Bloc<LocalArticlesEvent,LocalArticlesState> {
  final GetSavedArticleUseCase _getSavedArticleUseCase;
  final SaveArticleUseCase _saveArticleUseCase;
  final RemoveArticleUseCase _removeArticleUseCase;
  final SyncSavedArticlesUseCase _syncSavedArticlesUseCase; // NUEVO
  LocalArticleBloc(
    this._getSavedArticleUseCase,
    this._saveArticleUseCase,
    this._removeArticleUseCase,
    this._syncSavedArticlesUseCase,
  ) : super(const LocalArticlesLoading()){
    on <GetSavedArticles> (onGetSavedArticles);
    on <RemoveArticle> (onRemoveArticle);
    on <SaveArticle> (onSaveArticle);
    on <SyncSavedArticles> (onSyncSavedArticles);
  }


  void onGetSavedArticles(GetSavedArticles event,Emitter<LocalArticlesState> emit) async {
    final articles = await _getSavedArticleUseCase();
    emit(LocalArticlesDone(articles));
  }
  
  void onRemoveArticle(RemoveArticle removeArticle,Emitter<LocalArticlesState> emit) async {
    await _removeArticleUseCase(params: removeArticle.article);
    final articles = await _getSavedArticleUseCase();
    emit(LocalArticlesDone(articles));
  }

  void onSaveArticle(SaveArticle saveArticle,Emitter<LocalArticlesState> emit) async {
    await _saveArticleUseCase(params: saveArticle.article);
    final articles = await _getSavedArticleUseCase();
    emit(LocalArticlesDone(articles));
  }

  void onSyncSavedArticles(SyncSavedArticles event, Emitter<LocalArticlesState> emit) async {
    // 1. Ejecutar sincronización de bajada
    await _syncSavedArticlesUseCase();
    // 2. Recargar lista local para mostrar lo nuevo
    final articles = await _getSavedArticleUseCase();
    emit(LocalArticlesDone(articles));
  }
}