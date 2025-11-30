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
import 'package:news_app_clean_architecture/core/constants/constants.dart';
import '../../widgets/article_tile_shimmer.dart';
import '../../../domain/entities/article.dart';
import '../../widgets/article_tile.dart';
import '../../widgets/symmetry_logo.dart';

class DailyNews extends HookWidget {
  const DailyNews({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Detectamos el tema actual para ajustar colores
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Estado local para el índice del tab actual
    final tabIndex = useState(0);

    // [FIX SITUACIÓN 2 y 3] useEffect para Sync al abrir la App
    useEffect(() {
      final authBloc = context.read<AuthBloc>();
      
      void triggerSync() {
        if (authBloc.state is Authenticated) {
          print("🚀 SYNC TRIGGER: Internet detectado o Inicio de App.");
          context.read<MyArticlesBloc>().add(const LoadMyArticles());
          context.read<MyArticlesBloc>().add(const SyncMyArticles());
          context.read<LocalArticleBloc>().add(const SyncLocalDatabase());
        }
      }

      triggerSync();

      final subscription = Connectivity().onConnectivityChanged.listen((result) {
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

      return subscription.cancel;
    }, []);

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, authState) {
        if (authState is Authenticated) {
          print("🔄 UI: Sesión iniciada. REHIDRATANDO DATOS...");
          context.read<MyArticlesBloc>().add(const LoadMyArticles());
          context.read<MyArticlesBloc>().add(const SyncMyArticles()); 
          context.read<LocalArticleBloc>().add(const SyncLocalDatabase());
        } 
        else if (authState is Unauthenticated) {
          tabIndex.value = 0;
          print("🔒 UI: Sesión cerrada. Limpiando estado visual...");
          context.read<LocalArticleBloc>().add(const ResetLocalState());
          context.read<RemoteArticlesBloc>().add(const GetArticles());
        }
      },
      builder: (context, authState) {
        final bool isAuth = authState is Authenticated;

        return MultiBlocListener(
          listeners: [
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
              
              // [FIX DARK MODE] Fondo Negro en Dark, Blanco en Light
              backgroundColor: isDark ? Colors.black : Colors.white,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              
              showSelectedLabels: false, 
              showUnselectedLabels: true,
              
              selectedFontSize: 0, 
              unselectedFontSize: 11,
              
              unselectedItemColor: Colors.grey,
              // El color base del seleccionado (aunque activeIcon lo sobrescribe)
              selectedItemColor: isDark ? Colors.white : Colors.black, 
              
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.fitness_center),
                  label: 'News',
                  activeIcon: _buildActiveIcon(Icons.fitness_center, 'News', isDark),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.article_outlined),
                  label: 'Reports',
                  activeIcon: _buildActiveIcon(Icons.article_outlined, 'Reports', isDark),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.bookmark_border),
                  label: 'Saved',
                  activeIcon: _buildActiveIcon(Icons.bookmark, 'Saved', isDark),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline),
                  label: 'Profile',
                  activeIcon: _buildActiveIcon(Icons.person, 'Profile', isDark),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper: Icono + Texto vertical dentro de una "Cápsula"
  // [FIX DARK MODE] Agregamos parámetro isDark para invertir colores
  Widget _buildActiveIcon(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      
      decoration: BoxDecoration(
        // Fondo: Blanco en Dark, Negro en Light
        color: isDark ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(50), 
      ),
      
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          // Icono: Negro en Dark, Blanco en Light
          Icon(icon, color: isDark ? Colors.black : Colors.white, size: 20), 
          const SizedBox(height: 2), 
          Text(
            label,
            style: TextStyle(
              // Texto: Negro en Dark, Blanco en Light
              color: isDark ? Colors.black : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FitnessNewsView extends HookWidget {
  const _FitnessNewsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ESTADOS
    final isSearching = useState(false);
    final searchController = useTextEditingController();
    
    // Estados de Filtros
    final selectedSearchFilter = useState<SearchFilter>(SearchFilter.all);
    final selectedCategory = useState<String>("All");
    final selectedSort = useState<SortOrder>(SortOrder.newest);

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
        // [NUEVO] Logo a la izquierda
        leading: const SymmetryAppLogo(),
        // Ajustamos el ancho del leading para que el logo quepa bien si es ancho
        leadingWidth: 50,
        // [FIX DARK MODE] Ajuste de colores en AppBar
        title: isSearching.value
            ? TextField(
                controller: searchController,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: const InputDecoration(
                  hintText: 'Buscar...', // Simplificado
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                onChanged: (query) => triggerUpdate(),
              )
            : Text('Fitness News', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        
        actions: [
          IconButton(
            icon: Icon(isSearching.value ? Icons.close : Icons.search, color: isDark ? Colors.white : Colors.black),
            onPressed: () {
              if (isSearching.value) {
                isSearching.value = false;
                searchController.clear();
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
            context,
            isSearching.value, 
            selectedSearchFilter, 
            selectedCategory, 
            selectedSort, 
            triggerUpdate,
            isDark
          ),
          
          // LISTA DE ARTICULOS
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFiltersHeader(
    BuildContext context,
    bool isSearching,
    ValueNotifier<SearchFilter> searchFilter,
    ValueNotifier<String> categoryFilter,
    ValueNotifier<SortOrder> sortFilter,
    VoidCallback onUpdate,
    bool isDark,
  ) {
    return Container(
      // [FIX DARK MODE] Fondo del header adaptable
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. FILTROS DE BÚSQUEDA
          if (isSearching) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip(SearchFilter.all, "Todos", searchFilter, onUpdate, isDark),
                  const SizedBox(width: 8),
                  _buildChip(SearchFilter.title, "Título", searchFilter, onUpdate, isDark),
                  const SizedBox(width: 8),
                  _buildChip(SearchFilter.author, "Autor", searchFilter, onUpdate, isDark),
                  const SizedBox(width: 8),
                  _buildChip(SearchFilter.description, "Contenido", searchFilter, onUpdate, isDark),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 2. CATEGORÍAS
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: ['All', ...kArticleCategories].map((category) {
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
                // [FIX DARK MODE] Inversión de colores para chips seleccionados
                selectedColor: isDark ? Colors.white : Colors.black,
                labelStyle: TextStyle(
                  // Activo: Inverso al fondo. Inactivo: Normal.
                  color: isSelected 
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? Colors.white : Colors.black),
                  fontSize: 12
                ),
                // Fondo inactivo
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                visualDensity: VisualDensity.compact, 
              );
            }).toList(),
          ),

          const SizedBox(height: 8),

          // 3. ORDENAMIENTO
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
                  color: isDark ? Colors.grey[900] : Colors.white, // Fondo del dropdown container
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SortOrder>(
                    value: sortFilter.value,
                    isDense: true,
                    icon: Icon(Icons.sort, size: 18, color: isDark ? Colors.white : Colors.black),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                    dropdownColor: isDark ? Colors.grey[900] : Colors.white,
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
    VoidCallback onUpdate,
    bool isDark
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
      // [FIX DARK MODE]
      selectedColor: isDark ? Colors.white : Colors.blueGrey,
      labelStyle: TextStyle(
          color: isSelected 
              ? (isDark ? Colors.black : Colors.white) 
              : (isDark ? Colors.white : Colors.black), 
          fontSize: 12
      ),
      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
      shape: const StadiumBorder(side: BorderSide(color: Colors.grey)),
      visualDensity: VisualDensity.compact,
    );
  }
  
  Widget _buildBody() {
    return BlocBuilder<RemoteArticlesBloc, RemoteArticlesState>(
      builder: (context, remoteState) {
        if (remoteState is RemoteArticlesLoading) {
          return ListView.builder(
            itemCount: 5,
            itemBuilder: (_, __) => const ArticleTileShimmer(),
          );
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

        // [FIX FINAL] 
        // ELIMINAMOS EL CONTAINER BLANCO EXTERNO.
        // Devolvemos el ArticleWidget directamente.
        // Ahora los márgenes del widget dejarán ver el fondo (negro o blanco) del Scaffold.
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