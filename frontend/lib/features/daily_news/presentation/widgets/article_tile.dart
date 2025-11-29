import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:ionicons/ionicons.dart';
import '../../domain/entities/article.dart';
import 'dart:io';

class ArticleWidget extends HookWidget {
  final ArticleEntity? article;
  final bool isSavedInitially;
  final bool isLikedInitially; // [NUEVO]
  final void Function(ArticleEntity article)? onArticlePressed;
  final void Function(ArticleEntity article, bool isSaved)? onBookmarkPressed;
  final void Function(ArticleEntity article)? onLikePressed;
  final void Function(ArticleEntity article)? onRemove;
  final bool? isRemovable;

  const ArticleWidget({
    Key? key,
    this.article,
    this.onArticlePressed,
    this.isSavedInitially = false,
    this.isLikedInitially = false, // [NUEVO] Default false
    this.onBookmarkPressed,
    this.onLikePressed,
    this.onRemove,
    this.isRemovable = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // HOOKS: Estados locales para reactividad inmediata
    // Inicializamos con los valores que vienen del Bloc (Base de Datos)
    final isLiked = useState(isLikedInitially); 
    final isSaved = useState(isSavedInitially);
    
    // Inicializamos el contador con el valor del modelo
    final likeCount = useState(article!.likesCount ?? 0);

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
            _buildTitleAndDescription(isLiked, isSaved, likeCount),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    Widget imageWidget;
    
    // Lógica para decidir si mostrar imagen Local o Remota
    if (article?.localImagePath != null && article!.localImagePath!.isNotEmpty) {
       final file = File(article!.localImagePath!);
       if (file.existsSync()) {
         imageWidget = Image.file(file, fit: BoxFit.cover);
       } else {
         imageWidget = CachedNetworkImage(
            imageUrl: article!.urlToImage ?? '', 
            fit: BoxFit.cover,
            placeholder: (context, url) => const CupertinoActivityIndicator(),
            errorWidget: (context, url, error) => const Icon(Icons.error),
         );
       }
    } else {
       imageWidget = CachedNetworkImage(
         imageUrl: article!.urlToImage ?? '',
         fit: BoxFit.cover,
         placeholder: (context, url) => const CupertinoActivityIndicator(),
         errorWidget: (context, url, error) => const Icon(Icons.error),
       );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.0),
        child: Container(
          width: MediaQuery.of(context).size.width / 3,
          height: double.maxFinite,
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.08)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageWidget,
              // Chip de Categoría
              if (article?.category != null && article!.category!.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.black54,
                    child: Text(
                      article!.category!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 10, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleAndDescription(
      ValueNotifier<bool> isLiked, 
      ValueNotifier<bool> isSaved,
      ValueNotifier<int> likeCount) {
    
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TÍTULO
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

            // DESCRIPCIÓN
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
            // 3. AUTOR (Corregido: Ubicado justo encima de la barra de fecha/acción)
            if (article?.author != null && article!.author!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, top: 4),
                child: Row(
                  children: [
                    const Icon(Ionicons.person, size: 12, color: Colors.blueAccent),
                    const SizedBox(width: 4),
                    // Usamos Flexible para evitar desbordamiento
                    Flexible(
                      child: Text(
                        article!.author!.toUpperCase(), 
                        style: const TextStyle(
                          fontSize: 10, 
                          color: Colors.blueAccent, 
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            // BARRA DE ACCIÓN
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // FECHA
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

                // BOTONES INTERACTIVOS
                if (!isRemovable!)
                  Row(
                    children: [
                      // Contador Visual
                      Text(
                        '${likeCount.value}', 
                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),

                      // Botón LIKE (Cloud Sync)
                      _buildActionButton(
                        icon: isLiked.value ? Ionicons.thumbs_up : Ionicons.thumbs_up_outline,
                        color: isLiked.value ? Colors.blue : Colors.black54,
                        onTap: () {
                          // 1. Lógica Visual (Optimista)
                          if (isLiked.value) {
                             likeCount.value--; // Si quito like, resto 1
                          } else {
                             likeCount.value++; // Si doy like, sumo 1
                          }
                          isLiked.value = !isLiked.value;

                          // 2. Notificar al padre (BLoC)
                          onLikePressed?.call(article!);
                        },
                      ),

                      // Botón GUARDAR (Local DB)
                      _buildActionButton(
                        icon: isSaved.value ? Ionicons.bookmark : Ionicons.bookmark_outline,
                        color: isSaved.value ? Colors.orange : Colors.black54,
                        paddingLeft: 12,
                        onTap: () {
                          // Toggle Switch
                          isSaved.value = !isSaved.value; 
                          onBookmarkPressed?.call(article!, isSaved.value);
                        },
                      ),
                    ],
                  ),
                
                // Botón BORRAR (Solo visible en Saved si se habilita)
                if (isRemovable!)
                  _buildActionButton(
                    icon: Ionicons.trash_outline,
                    color: Colors.red,
                    onTap: () => onRemove?.call(article!),
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