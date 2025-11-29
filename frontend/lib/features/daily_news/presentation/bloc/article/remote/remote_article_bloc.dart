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

// Lógica Maestra de Filtrado y Ordenamiento
  void onSearchArticles(SearchArticles event, Emitter<RemoteArticlesState> emit) async {
    // 1. Empezamos con la lista completa maestra
    List<ArticleEntity> result = List.from(_allArticles);

    // 2. FILTRO DE TEXTO (Si hay query)
    if (event.query.isNotEmpty) {
      final query = event.query.toLowerCase();
      result = result.where((article) {
        final title = article.title?.toLowerCase() ?? '';
        final author = article.author?.toLowerCase() ?? '';
        final content = "${article.content ?? ''} ${article.description ?? ''}".toLowerCase();

        switch (event.filter) {
          case SearchFilter.title: return title.contains(query);
          case SearchFilter.author: return author.contains(query);
          case SearchFilter.description: return content.contains(query);
          case SearchFilter.all:
          default: return title.contains(query) || author.contains(query) || content.contains(query);
        }
      }).toList();
    }

    // 3. FILTRO DE CATEGORÍA (Nuevo)
    if (event.category != "All") {
      result = result.where((article) {
        // Comparamos ignorando mayúsculas/minúsculas por seguridad
        return article.category?.toLowerCase() == event.category.toLowerCase();
      }).toList();
    }

    // 4. ORDENAMIENTO (Nuevo)
    switch (event.sortOrder) {
      case SortOrder.newest:
        result.sort((a, b) {
          return (b.publishedAt ?? '').compareTo(a.publishedAt ?? '');
        });
        break;
      case SortOrder.oldest:
        result.sort((a, b) {
          return (a.publishedAt ?? '').compareTo(b.publishedAt ?? '');
        });
        break;
      case SortOrder.popular:
        result.sort((a, b) {
          return (b.likesCount ?? 0).compareTo(a.likesCount ?? 0);
        });
        break;
    }

    // 5. Emitir resultado
    emit(RemoteArticlesDone(result));
  }
}