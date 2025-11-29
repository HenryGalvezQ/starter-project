import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/create_article.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/get_my_articles.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/sync_pending_articles.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/delete_article.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/update_article.dart';
import 'my_articles_event.dart';
import 'my_articles_state.dart';

class MyArticlesBloc extends Bloc<MyArticlesEvent, MyArticlesState> {
  final GetMyArticlesUseCase _getMyArticlesUseCase;
  final CreateArticleUseCase _createArticleUseCase;
  final SyncPendingArticlesUseCase _syncPendingArticlesUseCase;
  // Nuevas dependencias
  final DeleteArticleUseCase _deleteArticleUseCase;
  final UpdateArticleUseCase _updateArticleUseCase;

  MyArticlesBloc(
    this._getMyArticlesUseCase,
    this._createArticleUseCase,
    this._syncPendingArticlesUseCase,
    this._deleteArticleUseCase,
    this._updateArticleUseCase,
  ) : super(const MyArticlesLoading()) {
    on<LoadMyArticles>(_onLoadMyArticles);
    on<SaveNewArticle>(_onSaveNewArticle);
    on<SyncMyArticles>(_onSyncMyArticles);
    on<DeleteExistingArticle>(_onDeleteExistingArticle);
    on<UpdateExistingArticle>(_onUpdateExistingArticle);
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
  // LOGICA EDITAR
  void _onUpdateExistingArticle(UpdateExistingArticle event, Emitter<MyArticlesState> emit) async {
    try {
      await _updateArticleUseCase(params: event.article);
      emit(const ArticleSavedSuccess()); // Reusamos el estado de éxito
      add(const LoadMyArticles());
      add(const SyncMyArticles()); // Intentar subir cambios
    } catch (e) {
      emit(MyArticlesError("Error actualizando: $e"));
    }
  }

  // LOGICA BORRAR
  void _onDeleteExistingArticle(DeleteExistingArticle event, Emitter<MyArticlesState> emit) async {
    try {
      await _deleteArticleUseCase(params: event.article);
      // Recargamos INMEDIATAMENTE. Como marcamos 'pending_delete' en DB, 
      // el DAO ya no lo devolverá en LoadMyArticles, logrando el efecto visual instantáneo.
      add(const LoadMyArticles()); 
      add(const SyncMyArticles()); // Ejecutar borrado en nube si hay red
    } catch (e) {
      emit(MyArticlesError("Error eliminando: $e"));
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