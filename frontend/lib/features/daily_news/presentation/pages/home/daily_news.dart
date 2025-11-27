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

// Páginas y Widgets
import 'package:news_app_clean_architecture/features/daily_news/presentation/pages/home/my_reports.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/pages/saved_article/saved_article.dart';
import '../../../domain/entities/article.dart';
import '../../widgets/article_tile.dart';
import '../../../../../injection_container.dart'; // Necesario para inyectar dependencias (sl)

class DailyNews extends HookWidget {
  const DailyNews({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tabIndex = useState(0);

    // CORRECCIÓN: Quitamos el BlocProvider de aquí.
    // Usamos directamente Scaffold porque el Provider ya viene del padre (main.dart).
    return Scaffold(
      body: IndexedStack(
        index: tabIndex.value,
        children: const [
          _FitnessNewsView(),
          MyReports(),
          SavedArticles(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabIndex.value,
        onTap: (index) => tabIndex.value = index,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Fitness News'),
          BottomNavigationBarItem(icon: Icon(Icons.article_outlined), label: 'My Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_border), label: 'Saved'),
        ],
      ),
    );
  }
}

class _FitnessNewsView extends StatelessWidget {
  const _FitnessNewsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppbar(context),
      body: _buildBody(), // Sin envolver en BlocProvider
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
            
            // CAMBIO: Recibimos el estado 'isSaved'
            onBookmarkPressed: (article, isSaved) {
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

          // 3. Acción de Like (Pulgar Arriba)
          onLikePressed: (article) {
            // Aquí iría la lógica de Firebase (Fase 3/4)
            // Por ahora solo visual
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