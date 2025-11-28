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
    try {
      // 1. Guardar en Local (Floor)
      await _createArticleUseCase(params: event.article);
      
      // 2. Avisar éxito a la UI (para cerrar el formulario)
      emit(const ArticleSavedSuccess());
      
      // 3. Recargar la lista local (para que aparezca el item con reloj naranja)
      add(const LoadMyArticles());

      // 4. AUTO-SYNC: Disparar intento de subida inmediato
      // Si hay internet, pasará a verde en segundos. Si no, se queda en naranja.
      add(const SyncMyArticles()); 

    } catch (e) {
      emit(MyArticlesError("Error guardando reporte: $e"));
    }
  }

  void _onSyncMyArticles(SyncMyArticles event, Emitter<MyArticlesState> emit) async {
    emit(const MyArticlesLoading());
    
    // 1. Ejecutar Sincronización
    await _syncPendingArticlesUseCase();
    
    // 2. Obtener la lista actualizada localmente
    final articles = await _getMyArticlesUseCase();
    
    // 3. CAMBIO: Emitir Success específico en lugar de solo Loaded
    // Esto servirá de "señal" para que la UI refresque el otro Feed
    emit(MyArticlesSyncSuccess(articles: articles));
  }
}