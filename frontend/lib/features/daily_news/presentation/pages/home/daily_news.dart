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

    // Escuchamos el estado de autenticación para proteger rutas
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        
        // Determinamos si el usuario está autenticado
        final bool isAuth = authState is Authenticated;

        return Scaffold(
          body: IndexedStack(
            index: tabIndex.value,
            children: [
              // TAB 0: Fitness News (Público - Siempre visible)
              const _FitnessNewsView(),

              // TAB 1: My Reports (Protegido)
              // Si está auth muestra Reports, si no, muestra Login
              isAuth ? const MyReports() : const LoginScreen(),

              // TAB 2: Saved (Protegido)
              // Si está auth muestra Saved, si no, muestra Login
              isAuth ? const SavedArticles() : const LoginScreen(),

              // TAB 3: Profile (Dinámico)
              // Si está auth muestra Perfil, si no, muestra Login
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
            type: BottomNavigationBarType.fixed, // Necesario para que se vean bien 4 items
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

// Vista interna para el Feed de Noticias
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
    // Escuchamos al Bloc Remoto para pintar la lista
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

          // Lógica de Guardado (Marcador)
          onBookmarkPressed: (article, isSaved) {
            // Nota: Aquí en el futuro agregaremos la validación de Auth
            // Para "Maximally Overdeliver", el botón debería pedir login si es Guest.
            // Por ahora mantenemos la lógica local funcional.
            
            if (isSaved) {
              // CASO 1: El usuario lo marcó -> GUARDAR
              context.read<LocalArticleBloc>().add(SaveArticle(article));

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Guardado en favoritos'),
                  duration: Duration(milliseconds: 500),
                ),
              );
            } else {
              // CASO 2: El usuario lo desmarcó -> BORRAR
              context.read<LocalArticleBloc>().add(RemoveArticle(article));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Eliminado de favoritos'),
                  duration: Duration(milliseconds: 500),
                ),
              );
            }
          },

          // Acción de Like (Pulgar Arriba)
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