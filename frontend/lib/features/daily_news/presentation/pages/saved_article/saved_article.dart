import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:ionicons/ionicons.dart';
import '../../../domain/entities/article.dart';
import '../../bloc/article/local/local_article_bloc.dart';
import '../../bloc/article/local/local_article_event.dart';
import '../../bloc/article/local/local_article_state.dart';
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
    // Usamos BlocBuilder para escuchar cambios (Global State)
    return BlocBuilder<LocalArticleBloc, LocalArticlesState>(
      builder: (context, state) {
        if (state is LocalArticlesLoading) {
          return const Center(child: CupertinoActivityIndicator());
        } else if (state is LocalArticlesDone) {
          return _buildArticlesList(context, state.articles!);
        }
        return Container();
      },
    );
  }

  Widget _buildArticlesList(BuildContext context, List<ArticleEntity> articles) {
    if (articles.isEmpty) {
      return const Center(
          child: Text(
        'NO SAVED ARTICLES',
        style: TextStyle(color: Colors.black),
      ));
    }

    return ListView.builder(
      itemCount: articles.length,
      itemBuilder: (context, index) {
        return ArticleWidget(
          article: articles[index],
          // CLAVE: Como estamos en Guardados, nace "Activado" (Naranja)
          isSavedInitially: true, 
          
          onArticlePressed: (article) => _onArticlePressed(context, article),
          
          // Lógica Unificada: Switch
          onBookmarkPressed: (article, isSaved) {
            if (!isSaved) {
              // Si el usuario lo desmarca (pasa a false) -> ELIMINAR
              context.read<LocalArticleBloc>().add(RemoveArticle(article));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Eliminado de favoritos'), duration: Duration(milliseconds: 500)),
                );
            }
            // Si lo vuelve a marcar (true) -> GUARDAR (Raro caso en esta lista, pero posible antes de que refresque)
            else {
               context.read<LocalArticleBloc>().add(SaveArticle(article));
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