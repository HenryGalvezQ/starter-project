import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/local/local_article_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/local/local_article_event.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/local/local_article_state.dart';
import '../../widgets/article_tile.dart';

class SavedArticles extends HookWidget {
  const SavedArticles({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Saved Articles', style: TextStyle(color: Colors.black)),
    );
  }

  Widget _buildBody() {
    return BlocBuilder<LocalArticleBloc, LocalArticlesState>(
      builder: (context, state) {
        if (state is LocalArticlesLoading) {
          return const Center(child: CupertinoActivityIndicator());
        } else if (state is LocalArticlesDone) {
          // CORRECCIÓN: Usamos savedArticles y manejamos nulos
          return _buildArticlesList(
            context, 
            state.savedArticles ?? [], 
            state.likedArticles ?? []
          );
        }
        return Container();
      },
    );
  }

  Widget _buildArticlesList(
    BuildContext context, 
    List<ArticleEntity> savedArticles,
    List<ArticleEntity> likedArticles
  ) {
    if (savedArticles.isEmpty) {
      return const Center(
          child: Text(
        'NO SAVED ARTICLES',
        style: TextStyle(color: Colors.black),
      ));
    }

    return ListView.builder(
      itemCount: savedArticles.length,
      itemBuilder: (context, index) {
        final article = savedArticles[index];

        // LÓGICA DE ESTADO CRUZADO:
        // En esta pantalla TODOS están guardados (por definición),
        // pero necesitamos saber cuáles tienen LIKE.
        final bool isLiked = likedArticles.any((l) => l.url == article.url);

        // Si tenemos una versión con like actualizado (contador +1), la usamos
        final localLikedArticle = isLiked 
            ? likedArticles.firstWhere((l) => l.url == article.url) 
            : null;
        
        final displayArticle = localLikedArticle ?? article;

        return ArticleWidget(
          // KEY REACTIVA: Si cambia el estado de like, repintamos
          key: ValueKey("${article.url}_saved_${isLiked}"),

          article: displayArticle,
          
          // Por definición, aquí siempre es true
          isSavedInitially: true, 
          isLikedInitially: isLiked,
          
          onArticlePressed: (article) => _onArticlePressed(context, article),
          
          // ACCIÓN 1: GUARDAR / BORRAR
          onBookmarkPressed: (article, isSavedNow) {
            // En esta pantalla, si quitas el marcador (isSavedNow == false),
            // significa que lo quieres BORRAR de la lista.
            if (!isSavedNow) {
              context.read<LocalArticleBloc>().add(RemoveArticle(article));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Eliminado de favoritos'), duration: Duration(milliseconds: 500)),
              );
            } 
            // Caso raro: Si por alguna razón vuelve a true (switch rápido), guardamos de nuevo
            else {
              context.read<LocalArticleBloc>().add(SaveArticle(article));
            }
          },

          // ACCIÓN 2: LIKE (NUEVO)
          onLikePressed: (article) {
             final bool newStatus = !isLiked;
             context.read<LocalArticleBloc>().add(
               ToggleLikeArticle(article: article, isLiked: newStatus)
             );
             
             if(newStatus) {
                ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("Like 👍"), duration: Duration(milliseconds: 300)),
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