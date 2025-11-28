import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

// Imports de Lógica Remota (Feed de Noticias)
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_state.dart';

// Imports de Lógica Local (Guardar Artículos)
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/local/local_article_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/local/local_article_event.dart';

// Imports de Mis Reportes (Para recargar al cambiar sesión)
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_event.dart';

// Imports de Autenticación
import 'package:news_app_clean_architecture/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/bloc/auth_state.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/pages/login/login.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/pages/profile/profile.dart';

// Páginas y Widgets
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

    // CAMBIO CLAVE: Usamos BlocConsumer en lugar de BlocBuilder
    // Esto nos permite escuchar (listener) cambios de estado sin reconstruir la UI innecesariamente
    return BlocConsumer<AuthBloc, AuthState>(
      // 1. LÓGICA DE LIMPIEZA REACTIVA
      listener: (context, authState) {
        if (authState is Authenticated) {
          // Si entra un usuario (Login), forzamos la recarga de los BLoCs personales.
          // Al recargar, el Repositorio usará el nuevo UID para consultar la DB Local.
          // Esto limpia los "fantasmas" del usuario anterior en la RAM.
          context.read<MyArticlesBloc>().add(const LoadMyArticles());
          context.read<LocalArticleBloc>().add(const GetSavedArticles());
          print("🔄 UI: Sesión cambiada. Recargando datos para ${authState.user?.email}");
        } 
        else if (authState is Unauthenticated) {
          // Si sale (Logout), reseteamos el tab al inicio para evitar que quede en una pantalla protegida
          tabIndex.value = 0;
        }
      },
      
      // 2. CONSTRUCCIÓN DE LA UI (Navegación)
      builder: (context, authState) {
        
        // Determinamos si el usuario está autenticado para mostrar/ocultar pantallas
        final bool isAuth = authState is Authenticated;

        return Scaffold(
          body: IndexedStack(
            index: tabIndex.value,
            children: [
              // TAB 0: Fitness News (Público - Siempre visible)
              const _FitnessNewsView(),

              // TAB 1: My Reports (Protegido)
              isAuth ? const MyReports() : const LoginScreen(),

              // TAB 2: Saved (Protegido)
              isAuth ? const SavedArticles() : const LoginScreen(),

              // TAB 3: Profile (Dinámico)
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
              BottomNavigationBarItem(
                icon: Icon(Icons.fitness_center),
                label: 'News',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.article_outlined),
                label: 'Reports',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bookmark_border),
                label: 'Saved',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}

// Vista interna para el Feed de Noticias (Sin cambios)
class _FitnessNewsView extends StatelessWidget {
  const _FitnessNewsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppbar(context),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppbar(BuildContext context) {
    return AppBar(
      title: const Text(
        'Fitness News',
        style: TextStyle(color: Colors.black),
      ),
    );
  }

  Widget _buildBody() {
    return BlocBuilder<RemoteArticlesBloc, RemoteArticlesState>(
      builder: (context, state) {
        if (state is RemoteArticlesLoading) {
          return const Center(child: CupertinoActivityIndicator());
        }
        if (state is RemoteArticlesError) {
          return const Center(child: Icon(Icons.refresh));
        }
        if (state is RemoteArticlesDone) {
          return _buildArticlesList(context, state.articles!);
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildArticlesList(
      BuildContext context, List<ArticleEntity> articles) {
    return ListView.builder(
      itemCount: articles.length,
      itemBuilder: (context, index) {
        return ArticleWidget(
          article: articles[index],
          onArticlePressed: (article) => _onArticlePressed(context, article),

          onBookmarkPressed: (article, isSaved) {
            if (isSaved) {
              context.read<LocalArticleBloc>().add(SaveArticle(article));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Guardado en favoritos'),
                  duration: Duration(milliseconds: 500),
                ),
              );
            } else {
              context.read<LocalArticleBloc>().add(RemoveArticle(article));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Eliminado de favoritos'),
                  duration: Duration(milliseconds: 500),
                ),
              );
            }
          },

          onLikePressed: (article) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Le diste Like a esta noticia 👍'),
                duration: Duration(milliseconds: 500),
              ),
            );
          },
        );
      },
    );
  }

  void _onArticlePressed(BuildContext context, ArticleEntity article) {
    Navigator.pushNamed(context, '/ArticleDetails', arguments: article);
  }
}