import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:ionicons/ionicons.dart';
import '../../../../../injection_container.dart';
import '../../../domain/entities/article.dart';
import '../../bloc/article/local/local_article_bloc.dart';
import '../../bloc/article/local/local_article_event.dart';
import '../../bloc/article/local/local_article_state.dart'; // NECESARIO

class ArticleDetailsView extends HookWidget {
  final ArticleEntity? article;

  const ArticleDetailsView({Key? key, this.article}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // HOOKS: Solo para Likes
    final isLiked = useState(false);
    final likeCount = useState(article!.likesCount ?? 0);

    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBody(context, isLiked, likeCount),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      leading: Builder(
        builder: (context) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onBackButtonTapped(context),
          child: const Icon(Ionicons.chevron_back, color: Colors.black),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ValueNotifier<bool> isLiked, ValueNotifier<int> likeCount) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildArticleTitleAndDate(context, isLiked, likeCount),
          _buildArticleImage(),
          _buildArticleDescription(),
        ],
      ),
    );
  }

  Widget _buildArticleTitleAndDate(BuildContext context, ValueNotifier<bool> isLiked, ValueNotifier<int> likeCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            article!.title!,
            style: const TextStyle(fontFamily: 'Butler', fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  article!.category ?? 'General',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Por ${article!.author ?? 'Redacción'}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Ionicons.time_outline, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    article!.publishedAt!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              
              Row(
                children: [
                  Text(
                    '${likeCount.value} Likes',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      if (isLiked.value) {
                        likeCount.value--;
                      } else {
                        likeCount.value++;
                      }
                      isLiked.value = !isLiked.value;
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Like actualizado 👍"),
                          duration: Duration(milliseconds: 300),
                        ),
                      );
                    },
                    child: Icon(
                      isLiked.value ? Ionicons.thumbs_up : Ionicons.thumbs_up_outline,
                      color: isLiked.value ? Colors.blue : Colors.black,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArticleImage() {
    return Container(
      width: double.maxFinite,
      height: 250,
      margin: const EdgeInsets.only(top: 14),
      child: Image.network(
        article!.urlToImage!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
              height: 250,
              color: Colors.grey,
              child: const Center(child: Icon(Icons.error)));
        },
      ),
    );
  }

  Widget _buildArticleDescription() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Text(
        article!.content != null && article!.content!.isNotEmpty 
            ? article!.content! 
            : article!.description ?? '',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  // BOTÓN GUARDAR (FAB) - SWITCH GLOBAL
  Widget _buildFloatingActionButton(BuildContext context) {
    // Usamos BlocBuilder para escuchar la verdad absoluta de la BD
    return BlocBuilder<LocalArticleBloc, LocalArticlesState>(
      builder: (context, state) {
        // Verificar si este artículo ya está guardado
        bool isActuallySaved = false;
        if (state is LocalArticlesDone && state.articles != null) {
           isActuallySaved = state.articles!.any((element) => element.url == article!.url);
        }

        return FloatingActionButton(
          backgroundColor: isActuallySaved ? Colors.orange : Colors.blueAccent,
          onPressed: () {
            if (isActuallySaved) {
              // Si ya está guardado -> BORRAR
              context.read<LocalArticleBloc>().add(RemoveArticle(article!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Eliminado de favoritos'), duration: Duration(milliseconds: 500)),
              );
            } else {
              // Si no está guardado -> GUARDAR
              context.read<LocalArticleBloc>().add(SaveArticle(article!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Guardado en favoritos'), duration: Duration(milliseconds: 500)),
              );
            }
          },
          child: Icon(
            isActuallySaved ? Ionicons.bookmark : Ionicons.bookmark_outline,
            color: Colors.white,
          ),
        );
      },
    );
  }

  void _onBackButtonTapped(BuildContext context) {
    Navigator.pop(context);
  }
}