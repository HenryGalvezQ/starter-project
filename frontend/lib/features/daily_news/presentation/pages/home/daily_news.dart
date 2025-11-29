import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
// Remoto
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_state.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_event.dart';

// Local
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/local/local_article_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/local/local_article_event.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/local/local_article_state.dart';

// My Reports
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_event.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_state.dart';

// Auth
import 'package:news_app_clean_architecture/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/bloc/auth_state.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/pages/login/login.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/pages/profile/profile.dart';

// Pages & Widgets
import 'package:news_app_clean_architecture/features/daily_news/presentation/pages/home/my_reports.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/pages/saved_article/saved_article.dart';
import '../../../domain/entities/article.dart';
import '../../widgets/article_tile.dart';

// Constantes de Categoría
const List<String> kFilterCategories = [
  'All', 'General', 'Workout', 'Nutrition', 'Mental Health', 'Gear', 'Events'
];

class DailyNews extends HookWidget {
  const DailyNews({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Estado local para el índice del tab actual
    final tabIndex = useState(0);

    // [FIX SITUACIÓN 2 y 3] useEffect para Sync al abrir la App
    // Esto se ejecuta una vez al montar el widget. Si ya hay sesión (persistencia), dispara el sync.
    useEffect(() {
      // 1. Referencia al AuthBloc para verificar sesión
      final authBloc = context.read<AuthBloc>();
      
      // Función auxiliar para sincronizar todo
      void triggerSync() {
        if (authBloc.state is Authenticated) {
          print("🚀 SYNC TRIGGER: Internet detectado o Inicio de App.");
          // Carga la data local actual
          context.read<MyArticlesBloc>().add(const LoadMyArticles());
          // Intenta subir lo pendiente (Create/Update/Delete) y bajar novedades
          context.read<MyArticlesBloc>().add(const SyncMyArticles());
          // Sincroniza favoritos y likes
          context.read<LocalArticleBloc>().add(const SyncLocalDatabase());
        }
      }

      // 2. Ejecutar Sync al abrir la app (Intento inicial)
      triggerSync();

      // 3. SUSCRIPCIÓN A CAMBIOS DE CONEXIÓN (La magia automática)
      final subscription = Connectivity().onConnectivityChanged.listen((result) {
        // Nota: connectivity_plus puede devolver una lista o un solo valor dependiendo la versión
        bool hasInternet = false;
        if (result is List) {
          hasInternet = !result.contains(ConnectivityResult.none);
        } else {
          hasInternet = result != ConnectivityResult.none;
        }

        if (hasInternet) {
          print("📶 CONEXIÓN RESTAURADA: Ejecutando Auto-Sync...");
          triggerSync();
        }
      });

      // Limpieza al cerrar el widget
      return subscription.cancel;
    }, []);

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, authState) {
        if (authState is Authenticated) {
          // [FIX CRÍTICO AQUÍ]
          print("🔄 UI: Sesión iniciada. REHIDRATANDO DATOS...");
          
          // 1. Cargar lo que haya localmente (probablemente vacío al inicio)
          context.read<MyArticlesBloc>().add(const LoadMyArticles());
          
          // 2. [AGREGAR ESTA LÍNEA] Forzar descarga de la nube inmediatamente
          context.read<MyArticlesBloc>().add(const SyncMyArticles()); 
          
          // 3. Sincronizar Favoritos y Likes
          context.read<LocalArticleBloc>().add(const SyncLocalDatabase());
        } 
        else if (authState is Unauthenticated) {
          // [FIX SITUACIÓN 4] Limpieza al cerrar sesión
          tabIndex.value = 0;
          print("🔒 UI: Sesión cerrada. Limpiando estado visual...");
          // Limpiamos la RAM del Bloc Local para que no queden iconos activos
          context.read<LocalArticleBloc>().add(const ResetLocalState());
          // Refrescamos el feed remoto
          context.read<RemoteArticlesBloc>().add(const GetArticles());
        }
      },
      builder: (context, authState) {
        final bool isAuth = authState is Authenticated;

        return MultiBlocListener(
          listeners: [
            // Escuchar si la sincronización termina con éxito para refrescar feed
            BlocListener<MyArticlesBloc, MyArticlesState>(
              listener: (context, state) {
                 if (state is MyArticlesSyncSuccess) {
                  print("🔄 FEED EVENT: Sincronización completada. Recargando feed...");
                  context.read<RemoteArticlesBloc>().add(const GetArticles());
                }
              },
            ),
          ],
          child: Scaffold(
            body: IndexedStack(
              index: tabIndex.value,
              children: [
                const _FitnessNewsView(),
                isAuth ? const MyReports() : const LoginScreen(),
                isAuth ? const SavedArticles() : const LoginScreen(),
                isAuth 
                    ? ProfileScreen(user: authState.user!) 
                    : const LoginScreen(),
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: tabIndex.value,
              onTap: (index) {
                tabIndex.value = index;
              },
              selectedItemColor: Colors.black,
              unselectedItemColor: Colors.grey,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed, 
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'News'),
                BottomNavigationBarItem(icon: Icon(Icons.article_outlined), label: 'Reports'),
                BottomNavigationBarItem(icon: Icon(Icons.bookmark_border), label: 'Saved'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FitnessNewsView extends HookWidget {
  const _FitnessNewsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ESTADOS
    final isSearching = useState(false);
    final searchController = useTextEditingController();
    
    // Estados de Filtros
    final selectedSearchFilter = useState<SearchFilter>(SearchFilter.all);
    final selectedCategory = useState<String>("All");
    final selectedSort = useState<SortOrder>(SortOrder.newest);

    // Trigger Maestro
    void triggerUpdate() {
      context.read<RemoteArticlesBloc>().add(
        SearchArticles(
          query: searchController.text,
          filter: selectedSearchFilter.value,
          category: selectedCategory.value,
          sortOrder: selectedSort.value
        )
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: isSearching.value
            ? TextField(
                controller: searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'Buscar por ${selectedSearchFilter.value.name}...',
                  border: InputBorder.none,
                  hintStyle: const TextStyle(color: Colors.grey),
                ),
                onChanged: (query) => triggerUpdate(),
              )
            : const Text('Fitness News', style: TextStyle(color: Colors.black)),
        
        actions: [
          IconButton(
            icon: Icon(isSearching.value ? Icons.close : Icons.search, color: Colors.black),
            onPressed: () {
              if (isSearching.value) {
                // RESET AL CERRAR BUSQUEDA (Opcional: puedes dejar los filtros activos si prefieres)
                isSearching.value = false;
                searchController.clear();
                // selectedCategory.value = "All"; // Descomenta si quieres resetear categoria al cerrar buscar
                triggerUpdate();
              } else {
                isSearching.value = true;
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          // CABECERA DE FILTROS Y ORDENAMIENTO
          _buildFiltersHeader(
            isSearching.value, 
            selectedSearchFilter, 
            selectedCategory, 
            selectedSort, 
            triggerUpdate
          ),
          
          // LISTA DE ARTICULOS
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFiltersHeader(
    bool isSearching,
    ValueNotifier<SearchFilter> searchFilter,
    ValueNotifier<String> categoryFilter,
    ValueNotifier<SortOrder> sortFilter,
    VoidCallback onUpdate,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. FILTROS DE BÚSQUEDA (Solo visibles si se busca)
          if (isSearching) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip(SearchFilter.all, "Todos", searchFilter, onUpdate),
                  const SizedBox(width: 8),
                  _buildChip(SearchFilter.title, "Título", searchFilter, onUpdate),
                  const SizedBox(width: 8),
                  _buildChip(SearchFilter.author, "Autor", searchFilter, onUpdate),
                  const SizedBox(width: 8),
                  _buildChip(SearchFilter.description, "Contenido", searchFilter, onUpdate),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 2. CATEGORÍAS (Wrap para permitir salto de línea)
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: kFilterCategories.map((category) {
              final isSelected = categoryFilter.value == category;
              return ChoiceChip(
                label: Text(category),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    categoryFilter.value = category;
                    onUpdate();
                  }
                },
                selectedColor: Colors.black,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontSize: 12
                ),
                backgroundColor: Colors.grey[200],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                // Visualmente compactos
                visualDensity: VisualDensity.compact, 
              );
            }).toList(),
          ),

          const SizedBox(height: 8),

          // 3. ORDENAMIENTO (Dropdown)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text("Ordenar por: ", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SortOrder>(
                    value: sortFilter.value,
                    isDense: true,
                    icon: const Icon(Icons.sort, size: 18),
                    style: const TextStyle(color: Colors.black, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: SortOrder.newest, child: Text("Más Recientes")),
                      DropdownMenuItem(value: SortOrder.oldest, child: Text("Más Antiguos")),
                      DropdownMenuItem(value: SortOrder.popular, child: Text("Más Populares 🔥")),
                    ],
                    onChanged: (newValue) {
                      if (newValue != null) {
                        sortFilter.value = newValue;
                        onUpdate();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }

  // Helper genérico para los chips de búsqueda
  Widget _buildChip(
    SearchFilter filter, 
    String label, 
    ValueNotifier<SearchFilter> currentFilter,
    VoidCallback onUpdate
  ) {
    final bool isSelected = currentFilter.value == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          currentFilter.value = filter;
          onUpdate();
        }
      },
      selectedColor: Colors.blueGrey,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 12),
      backgroundColor: Colors.white,
      shape: const StadiumBorder(side: BorderSide(color: Colors.grey)),
      visualDensity: VisualDensity.compact,
    );
  }
  
  Widget _buildBody() {
    return BlocBuilder<RemoteArticlesBloc, RemoteArticlesState>(
      builder: (context, remoteState) {
        if (remoteState is RemoteArticlesLoading) {
          return const Center(child: CupertinoActivityIndicator());
        }
        if (remoteState is RemoteArticlesError) {
          return const Center(child: Icon(Icons.refresh));
        }
        if (remoteState is RemoteArticlesDone) {
          
          return BlocBuilder<LocalArticleBloc, LocalArticlesState>(
            builder: (context, localState) {
              
              List<ArticleEntity> savedArticles = [];
              List<ArticleEntity> likedArticles = [];

              if (localState is LocalArticlesDone) {
                savedArticles = localState.savedArticles ?? [];
                likedArticles = localState.likedArticles ?? [];
              }

              // MENSAJE SI NO HAY RESULTADOS
              if (remoteState.articles!.isEmpty) {
                return const Center(child: Text("No se encontraron resultados"));
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<RemoteArticlesBloc>().add(const GetArticles());
                  context.read<LocalArticleBloc>().add(const SyncLocalDatabase());
                  await Future.delayed(const Duration(seconds: 1));
                },
                color: Colors.black,
                child: _buildArticlesList(context, remoteState.articles!, savedArticles, likedArticles),
              );
            },
          );
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildArticlesList(
      BuildContext context, 
      List<ArticleEntity> remoteArticles, 
      List<ArticleEntity> savedArticles,
      List<ArticleEntity> likedArticles
  ) {
    return ListView.builder(
      itemCount: remoteArticles.length,
      itemBuilder: (context, index) {
        final remoteArticle = remoteArticles[index];

        final bool isSaved = savedArticles.any((s) => s.url == remoteArticle.url);
        final bool isLiked = likedArticles.any((l) => l.url == remoteArticle.url);

        final localArticle = likedArticles.cast<ArticleEntity>().firstWhere(
            (l) => l.url == remoteArticle.url, 
            orElse: () => savedArticles.cast<ArticleEntity>().firstWhere(
                (s) => s.url == remoteArticle.url,
                orElse: () => remoteArticle 
            )
        );

        final displayArticle = ArticleEntity(
          id: localArticle.id,
          userId: localArticle.userId,
          author: localArticle.author,
          title: localArticle.title,
          description: localArticle.description,
          url: localArticle.url,
          urlToImage: localArticle.urlToImage,
          publishedAt: localArticle.publishedAt,
          content: localArticle.content,
          category: localArticle.category,
          syncStatus: localArticle.syncStatus,
          localImagePath: localArticle.localImagePath,
          
          likesCount: localArticle.likesCount, 
          isSaved: isSaved,  
          isLiked: isLiked,  
        );

        return ArticleWidget(
          key: ValueKey("${remoteArticle.url}_${isSaved}_${isLiked}"),
          article: displayArticle,
          isSavedInitially: isSaved,
          isLikedInitially: isLiked, 
          onArticlePressed: (article) {
             _onArticlePressed(context, displayArticle);
          },
          onBookmarkPressed: (article, isSavedNow) {
            if (isSavedNow) {
              context.read<LocalArticleBloc>().add(SaveArticle(article));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Guardado en favoritos'), duration: Duration(milliseconds: 300))
              );
            } else {
              context.read<LocalArticleBloc>().add(RemoveArticle(article));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Eliminado de favoritos'), duration: Duration(milliseconds: 300))
              );
            }
          },
          onLikePressed: (article) {
            final bool newStatus = !isLiked;
            context.read<LocalArticleBloc>().add(
               ToggleLikeArticle(article: article, isLiked: newStatus)
            );
            if (newStatus) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("Like 👍"), duration: Duration(milliseconds: 300))
               );
            }
          },
        );
      },
    );
  }

  void _onArticlePressed(BuildContext context, ArticleEntity article) {
    Navigator.pushNamed(context, '/ArticleDetails', arguments: article);
  }
}