import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/local/local_article_event.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/local/local_article_state.dart';

// UseCases de Guardado
import '../../../../domain/usecases/get_saved_article.dart';
import '../../../../domain/usecases/remove_article.dart';
import '../../../../domain/usecases/save_article.dart';

// UseCases de Likes
import '../../../../domain/usecases/get_liked_articles.dart';
import '../../../../domain/usecases/toggle_like_article.dart';

// UseCases de Sincronización
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/sync_saved_articles.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/sync_liked_articles.dart';

class LocalArticleBloc extends Bloc<LocalArticlesEvent, LocalArticlesState> {
  // Guardado
  final GetSavedArticleUseCase _getSavedArticleUseCase;
  final SaveArticleUseCase _saveArticleUseCase;
  final RemoveArticleUseCase _removeArticleUseCase;
  
  // Likes
  final GetLikedArticlesUseCase _getLikedArticlesUseCase;
  final ToggleLikeArticleUseCase _toggleLikeArticleUseCase;
  
  // Sync
  final SyncSavedArticlesUseCase _syncSavedArticlesUseCase; 
  final SyncLikedArticlesUseCase _syncLikedArticlesUseCase;

  LocalArticleBloc(
    this._getSavedArticleUseCase,
    this._saveArticleUseCase,
    this._removeArticleUseCase,
    this._getLikedArticlesUseCase,   
    this._toggleLikeArticleUseCase,  
    this._syncSavedArticlesUseCase, 
    this._syncLikedArticlesUseCase,
  ) : super(const LocalArticlesLoading()) {
    
    // --- Handlers Originales (Saved) ---
    on<GetSavedArticles>(_onGetSavedArticles);
    on<SaveArticle>(_onSaveArticle);
    on<RemoveArticle>(_onRemoveArticle);
    
    // --- Handlers Nuevos (Likes) ---
    on<GetLikedArticles>(_onGetLikedArticles);
    on<ToggleLikeArticle>(_onToggleLikeArticle);
    
    // --- Handler Sync (Inicio de Sesión) ---
    on<SyncLocalDatabase>(_onSyncLocalDatabase);
    
    // --- Handler Reset (Cierre de Sesión) ---
    on<ResetLocalState>(_onResetLocalState);
  }

  // ---------------------------------------------------------------------------
  // LÓGICA DE SAVED
  // ---------------------------------------------------------------------------

  void _onGetSavedArticles(GetSavedArticles event, Emitter<LocalArticlesState> emit) async {
    final saved = await _getSavedArticleUseCase();
    // Importante: Mantenemos state.likedArticles para no borrar los likes visualmente
    emit(LocalArticlesDone(
        savedArticles: saved, 
        likedArticles: state.likedArticles 
    ));
  }

  void _onSaveArticle(SaveArticle event, Emitter<LocalArticlesState> emit) async {
    await _saveArticleUseCase(params: event.article);
    final saved = await _getSavedArticleUseCase();
    emit(LocalArticlesDone(
        savedArticles: saved, 
        likedArticles: state.likedArticles
    ));
  }

  void _onRemoveArticle(RemoveArticle event, Emitter<LocalArticlesState> emit) async {
    await _removeArticleUseCase(params: event.article);
    final saved = await _getSavedArticleUseCase();
    emit(LocalArticlesDone(
        savedArticles: saved, 
        likedArticles: state.likedArticles
    ));
  }

  // ---------------------------------------------------------------------------
  // LÓGICA DE LIKES
  // ---------------------------------------------------------------------------

  void _onGetLikedArticles(GetLikedArticles event, Emitter<LocalArticlesState> emit) async {
    final liked = await _getLikedArticlesUseCase();
    // Importante: Mantenemos state.savedArticles
    emit(LocalArticlesDone(
        savedArticles: state.savedArticles,
        likedArticles: liked
    ));
  }

  void _onToggleLikeArticle(ToggleLikeArticle event, Emitter<LocalArticlesState> emit) async {
    // 1. Ejecutar Transacción (Firestore + Local)
    await _toggleLikeArticleUseCase(params: ToggleLikeParams(event.article, event.isLiked));
    
    // 2. Refrescar lista local
    final liked = await _getLikedArticlesUseCase();
    
    // 3. Emitir
    emit(LocalArticlesDone(
        savedArticles: state.savedArticles, 
        likedArticles: liked
    ));
  }

  // ---------------------------------------------------------------------------
  // LÓGICA DE SINCRONIZACIÓN (REHIDRATACIÓN)
  // ---------------------------------------------------------------------------

  void _onSyncLocalDatabase(SyncLocalDatabase event, Emitter<LocalArticlesState> emit) async {
    // CORRECCIÓN PARA CONDICIÓN DE CARRERA:
    // Ejecutamos secuencialmente en lugar de paralela (Future.wait).
    // Esto permite que el repositorio detecte si el artículo ya fue insertado por
    // el paso anterior y haga un 'merge' de los estados (Saved + Liked).
    
    // 1. Sincronizar Guardados (Escribe isSaved=true)
    await _syncSavedArticlesUseCase();
    
    // 2. Sincronizar Likes (Lee si existe, preserva isSaved, y escribe isLiked=true)
    await _syncLikedArticlesUseCase();

    // 3. Leer el resultado final combinado de la base de datos local
    final saved = await _getSavedArticleUseCase();
    final liked = await _getLikedArticlesUseCase();

    // 4. Emitir estado completo a la UI
    emit(LocalArticlesDone(savedArticles: saved, likedArticles: liked));
  }

  // ---------------------------------------------------------------------------
  // LÓGICA DE LIMPIEZA (LOGOUT)
  // ---------------------------------------------------------------------------

  void _onResetLocalState(ResetLocalState event, Emitter<LocalArticlesState> emit) {
    // Limpiamos la memoria RAM del Bloc para evitar "datos fantasma" al salir
    emit(const LocalArticlesDone(savedArticles: [], likedArticles: []));
  }
}