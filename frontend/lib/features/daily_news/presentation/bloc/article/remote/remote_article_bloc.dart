import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_app_clean_architecture/core/resources/data_state.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/get_article.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/search_articles.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_event.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_state.dart';

class RemoteArticlesBloc extends Bloc<RemoteArticlesEvent, RemoteArticlesState> {
  
  final GetArticleUseCase _getArticleUseCase;
  // Mantenemos el SearchUseCase por si queremos buscar en DB explícitamente en el futuro,
  // pero para el Feed usaremos filtrado en memoria.
  final SearchArticlesUseCase _searchArticlesUseCase; 

  // Caché en memoria de todos los artículos descargados
  List<ArticleEntity> _allArticles = [];

  RemoteArticlesBloc(
    this._getArticleUseCase,
    this._searchArticlesUseCase, 
  ) : super(const RemoteArticlesLoading()) {
    on<GetArticles>(onGetArticles);
    on<SearchArticles>(onSearchArticles);
  }

  void onGetArticles(GetArticles event, Emitter<RemoteArticlesState> emit) async {
    // Solo emitimos loading si no tenemos datos previos para evitar parpadeos al refrescar
    if (_allArticles.isEmpty) {
      emit(const RemoteArticlesLoading());
    }

    final dataState = await _getArticleUseCase();

    if (dataState is DataSuccess && dataState.data != null) {
      // 1. Guardamos la copia maestra
      _allArticles = dataState.data!;
      
      // 2. Emitimos la lista completa
      emit(RemoteArticlesDone(_allArticles));
    }
    
    if (dataState is DataFailed) {
      print(dataState.error);
      // Si falla pero tenemos caché, mostramos caché
      if (_allArticles.isNotEmpty) {
        emit(RemoteArticlesDone(_allArticles));
      } else {
        emit(RemoteArticlesError(dataState.error!));
      }
    }
  }

  void onSearchArticles(SearchArticles event, Emitter<RemoteArticlesState> emit) async {
    // Búsqueda en Memoria (Funciona para Guest y Auth)
    // No emitimos Loading para que sea instantáneo (Search-as-you-type)
    
    if (event.query.isEmpty) {
      // Si borran, restauramos la lista completa
      emit(RemoteArticlesDone(_allArticles));
      return;
    }

    final query = event.query.toLowerCase();
    
    final filtered = _allArticles.where((article) {
      final title = article.title?.toLowerCase() ?? '';
      final author = article.author?.toLowerCase() ?? '';
      // Usamos content o description
      final content = (article.content ?? article.description ?? '').toLowerCase();

      switch (event.filter) {
        case SearchFilter.title:
          return title.contains(query);
        case SearchFilter.author:
          return author.contains(query);
        case SearchFilter.description:
          return content.contains(query);
        case SearchFilter.all:
        default:
          return title.contains(query) || 
                 author.contains(query) || 
                 content.contains(query);
      }
    }).toList();

    emit(RemoteArticlesDone(filtered));
  }
}