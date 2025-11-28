import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/create_article.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/get_my_articles.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/sync_pending_articles.dart';
import 'my_articles_event.dart';
import 'my_articles_state.dart';

class MyArticlesBloc extends Bloc<MyArticlesEvent, MyArticlesState> {
  final GetMyArticlesUseCase _getMyArticlesUseCase;
  final CreateArticleUseCase _createArticleUseCase;
  final SyncPendingArticlesUseCase _syncPendingArticlesUseCase;

  MyArticlesBloc(
    this._getMyArticlesUseCase,
    this._createArticleUseCase,
    this._syncPendingArticlesUseCase,
  ) : super(const MyArticlesLoading()) {
    on<LoadMyArticles>(_onLoadMyArticles);
    on<SaveNewArticle>(_onSaveNewArticle);
    on<SyncMyArticles>(_onSyncMyArticles);
  }

  void _onLoadMyArticles(LoadMyArticles event, Emitter<MyArticlesState> emit) async {
    emit(const MyArticlesLoading());
    try {
      final articles = await _getMyArticlesUseCase();
      emit(MyArticlesLoaded(articles));
    } catch (e) {
      emit(MyArticlesError(e.toString()));
    }
  }

  void _onSaveNewArticle(SaveNewArticle event, Emitter<MyArticlesState> emit) async {
    // No emitimos Loading aquí para no borrar la lista de fondo, 
    // o podríamos usar un estado híbrido. Por simplicidad:
    try {
      await _createArticleUseCase(params: event.article);
      // Emitimos éxito para que la UI cierre el formulario o muestre SnackBar
      emit(const ArticleSavedSuccess());
      // Recargamos la lista inmediatamente
      add(const LoadMyArticles());
    } catch (e) {
      emit(MyArticlesError("Error guardando reporte: $e"));
    }
  }

  void _onSyncMyArticles(SyncMyArticles event, Emitter<MyArticlesState> emit) async {
    // Disparamos sincronización (fire & forget o loading)
    // Para UX, recargamos la lista después de un pequeño delay o mostramos loading
    emit(const MyArticlesLoading());
    await _syncPendingArticlesUseCase();
    add(const LoadMyArticles());
  }
}