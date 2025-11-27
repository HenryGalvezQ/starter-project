import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:ionicons/ionicons.dart';
import '../../domain/entities/article.dart';

class ArticleWidget extends HookWidget {
  final ArticleEntity? article;
  final bool isSavedInitially; // NUEVO: Estado inicial
  final void Function(ArticleEntity article)? onArticlePressed;
  final void Function(ArticleEntity article, bool isSaved)? onBookmarkPressed;
  final void Function(ArticleEntity article)? onLikePressed;

  const ArticleWidget({
    Key? key,
    this.article,
    this.onArticlePressed,
    this.isSavedInitially = false, // Por defecto no guardado
    this.onBookmarkPressed,
    this.onLikePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isLiked = useState(false);
    // Inicializamos el estado con lo que nos diga el padre (ej: pestaña Saved)
    final isSaved = useState(isSavedInitially);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.only(
            start: 14, end: 14, bottom: 7, top: 7),
        height: MediaQuery.of(context).size.width / 2.1,
        child: Row(
          children: [
            _buildImage(context),
            _buildTitleAndDescription(isLiked, isSaved),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: article!.urlToImage ?? '',
      imageBuilder: (context, imageProvider) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: Container(
            width: MediaQuery.of(context).size.width / 3,
            height: double.maxFinite,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.08),
              image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
            ),
          ),
        ),
      ),
      progressIndicatorBuilder: (context, url, downloadProgress) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: Container(
            width: MediaQuery.of(context).size.width / 3,
            height: double.maxFinite,
            child: const CupertinoActivityIndicator(),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.08)),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: Container(
            width: MediaQuery.of(context).size.width / 3,
            height: double.maxFinite,
            child: const Icon(Icons.error), // Corrección del const
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.08)),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleAndDescription(
      ValueNotifier<bool> isLiked, ValueNotifier<bool> isSaved) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              article!.title ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Butler',
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  article!.description ?? '',
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Ionicons.time_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(article!.publishedAt),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                // Botones siempre visibles (Unificados)
                Row(
                  children: [
                    _buildActionButton(
                      icon: isLiked.value ? Ionicons.thumbs_up : Ionicons.thumbs_up_outline,
                      color: isLiked.value ? Colors.blue : Colors.black54,
                      onTap: () {
                        isLiked.value = !isLiked.value;
                        onLikePressed?.call(article!);
                      },
                    ),
                    _buildActionButton(
                      icon: isSaved.value ? Ionicons.bookmark : Ionicons.bookmark_outline,
                      color: isSaved.value ? Colors.orange : Colors.black54,
                      paddingLeft: 12,
                      onTap: () {
                        isSaved.value = !isSaved.value;
                        onBookmarkPressed?.call(article!, isSaved.value);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.black54,
    double paddingLeft = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(left: paddingLeft, top: 4, bottom: 4, right: 4),
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null) return '';
    try {
      return date.split('T').first;
    } catch (e) {
      return date;
    }
  }

  void _onTap() {
    if (onArticlePressed != null) {
      onArticlePressed!(article!);
    }
  }
}