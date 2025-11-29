import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

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

class DailyNews extends HookWidget {
  const DailyNews({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Estado local para el índice del tab actual
    final tabIndex = useState(0);

    // [FIX SITUACIÓN 2 y 3] useEffect para Sync al abrir la App
    // Esto se ejecuta una vez al montar el widget. Si ya hay sesión (persistencia), dispara el sync.
    useEffect(() {
      final authState = context.read<AuthBloc>().state;
      if (authState is Authenticated) {
        print("🚀 APP START: Usuario detectado. Iniciando Sincronización...");
        context.read<MyArticlesBloc>().add(const LoadMyArticles());
        context.read<LocalArticleBloc>().add(const SyncLocalDatabase());
      }
      return null;
    }, []);

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, authState) {
        if (authState is Authenticated) {
          // Sync cuando iniciamos sesión manualmente
          print("🔄 UI: Sesión iniciada. REHIDRATANDO DATOS...");
          context.read<MyArticlesBloc>().add(const LoadMyArticles());
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

class _FitnessNewsView extends StatelessWidget {
  const _FitnessNewsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitness News', style: TextStyle(color: Colors.black)),
      ),
      body: _buildBody(),
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

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<RemoteArticlesBloc>().add(const GetArticles());
                  // Usamos SyncLocalDatabase para traer lo más fresco de la nube
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

        // 1. VERDAD ABSOLUTA BOOLEANA
        final bool isSaved = savedArticles.any((s) => s.url == remoteArticle.url);
        final bool isLiked = likedArticles.any((l) => l.url == remoteArticle.url);

        // 2. BUSCAR MEJOR VERSIÓN (FIX DEL ERROR DE TIPO)
        // Usamos .cast<ArticleEntity>() para que firstWhere acepte devolver una Entidad genérica
        final localArticle = likedArticles.cast<ArticleEntity>().firstWhere(
            (l) => l.url == remoteArticle.url, 
            orElse: () => savedArticles.cast<ArticleEntity>().firstWhere(
                (s) => s.url == remoteArticle.url,
                orElse: () => remoteArticle // Ahora sí es válido devolver esto
            )
        );

        // 3. FRANKENSTEIN OBJECT (Inyección de Estado)
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
          
          // INYECCIÓN DE ESTADO:
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