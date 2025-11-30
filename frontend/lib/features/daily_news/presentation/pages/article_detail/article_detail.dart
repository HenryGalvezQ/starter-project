import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import '../../../domain/entities/article.dart';
import '../../bloc/article/local/local_article_bloc.dart';
import '../../bloc/article/local/local_article_event.dart'; // Importante para eventos

class ArticleDetailsView extends HookWidget {
  final ArticleEntity? article;

  const ArticleDetailsView({Key? key, this.article}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // HOOKS: Inicializamos con el estado que viene del Feed (Sincronización visual)
    final isSaved = useState(article!.isSaved ?? false);
    final isLiked = useState(article!.isLiked ?? false); 
    final likeCount = useState(article!.likesCount ?? 0);

    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBody(context, isLiked, likeCount),
      floatingActionButton: _buildFloatingActionButton(context, isSaved),
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
          // TÍTULO
          Text(
            article!.title ?? '',
            style: const TextStyle(fontFamily: 'Butler', fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),

          // AUTOR Y CATEGORÍA
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
          
          // FECHA + LIKES
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // FECHA
              Row(
                children: [
                  const Icon(Ionicons.time_outline, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(article!.publishedAt),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              
              // LIKES (Interactivo + Cloud Sync)
              Row(
                children: [
                  Text(
                    '${likeCount.value} Likes',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      // 1. Calcular nueva acción
                      final bool newStatus = !isLiked.value;
                      
                      // 2. Actualizar UI Local (Optimista)
                      isLiked.value = newStatus;
                      likeCount.value += newStatus ? 1 : -1;

                      // 3. Disparar Evento al BLoC (Sync Cloud + Local DB)
                      context.read<LocalArticleBloc>().add(
                        ToggleLikeArticle(article: article!, isLiked: newStatus)
                      );

                      // 4. Feedback
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(newStatus ? "Like 👍" : "Like removido"),
                          duration: const Duration(milliseconds: 300),
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
    if (article?.urlToImage == null || article!.urlToImage!.isEmpty) {
       return const SizedBox(height: 20);
    }
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

  // BOTÓN GUARDAR (FAB) - Lógica Switch Global
  Widget _buildFloatingActionButton(BuildContext context, ValueNotifier<bool> isSaved) {
    return FloatingActionButton(
      backgroundColor: isSaved.value ? Colors.orange : Colors.blueAccent,
      onPressed: () {
        if (isSaved.value) {
          // Si ya estaba guardado -> REMOVER
          context.read<LocalArticleBloc>().add(RemoveArticle(article!));
          isSaved.value = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Eliminado de favoritos'), duration: Duration(milliseconds: 500)),
          );
        } else {
          // Si no estaba guardado -> GUARDAR
          context.read<LocalArticleBloc>().add(SaveArticle(article!));
          isSaved.value = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Guardado en favoritos'), duration: Duration(milliseconds: 500)),
          );
        }
      },
      child: Icon(
        isSaved.value ? Ionicons.bookmark : Ionicons.bookmark_outline,
        color: Colors.white,
      ),
    );
  }

  void _onBackButtonTapped(BuildContext context) {
    Navigator.pop(context);
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';

    try {
      // 1. Convertir string a objeto DateTime local
      final date = DateTime.parse(dateString).toLocal();
      final now = DateTime.now();

      // 2. Formateador de hora (ej: 07:23 PM)
      final timeFormat = DateFormat('hh:mm a'); 
      final time = timeFormat.format(date);

      // 3. Lógica para "Hoy"
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return 'Hoy, $time';
      }

      // 4. Lógica para "Ayer"
      final yesterday = now.subtract(const Duration(days: 1));
      if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
        return 'Ayer, $time';
      }

      // 5. Cualquier otro día (ej: 22/11 a las 07:23 PM)
      final dateFormat = DateFormat('dd/MM');
      return '${dateFormat.format(date)} a las $time';

    } catch (e) {
      return dateString; // Si falla, devolvemos el original
    }
  }
}