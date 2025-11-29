// Enum para los filtros de campo (Search)
enum SearchFilter { all, title, author, description }

// [NUEVO] Enum para Ordenamiento
enum SortOrder { newest, oldest, popular }

abstract class RemoteArticlesEvent {
  const RemoteArticlesEvent();
}

class GetArticles extends RemoteArticlesEvent {
  const GetArticles();
}

// Evento Maestro de Filtrado
class SearchArticles extends RemoteArticlesEvent {
  final String query;
  final SearchFilter filter; 
  final String category; // [NUEVO] Categoría ('All' o nombre)
  final SortOrder sortOrder; // [NUEVO] Orden

  const SearchArticles({
    required this.query, 
    this.filter = SearchFilter.all,
    this.category = "All",
    this.sortOrder = SortOrder.newest,
  });
}