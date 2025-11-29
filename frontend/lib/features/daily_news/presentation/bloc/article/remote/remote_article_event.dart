// Enum para los filtros
enum SearchFilter { all, title, author, description }

abstract class RemoteArticlesEvent {
  const RemoteArticlesEvent();
}

class GetArticles extends RemoteArticlesEvent {
  const GetArticles();
}

// Evento de Búsqueda
class SearchArticles extends RemoteArticlesEvent {
  final String query;
  final SearchFilter filter; // Nuevo parámetro

  const SearchArticles({
    required this.query, 
    this.filter = SearchFilter.all
  });
}