import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:ionicons/ionicons.dart';
import '../../../../../injection_container.dart';
import '../../../domain/entities/article.dart';
import '../../bloc/article/local/local_article_bloc.dart';
import '../../bloc/article/local/local_article_event.dart';

class ArticleDetailsView extends HookWidget {
  final ArticleEntity? article;

  const ArticleDetailsView({Key? key, this.article}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Estado local para el botón flotante (Switch visual)
    // Nota: Por ahora inicia en 'false' (azul) visualmente al entrar, 
    // hasta que tengamos la persistencia en el objeto Article (Fase 4).
    final isSaved = useState(false);

    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBody(),
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

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildArticleTitleAndDate(),
          _buildArticleImage(),
          _buildArticleDescription(),
        ],
      ),
    );
  }

  Widget _buildArticleTitleAndDate() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            article!.title!,
            style: const TextStyle(
                fontFamily: 'Butler',
                fontSize: 20,
                fontWeight: FontWeight.w900),
          ),

          const SizedBox(height: 14),
          // DateTime
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
          // CORREGIDO: 'const' movido al hijo, Container no puede ser const
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
        '${article!.description ?? ''}\n\n${article!.content ?? ''}',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context, ValueNotifier<bool> isSaved) {
    return FloatingActionButton(
      // Lógica de Color: Naranja si está guardado, Azul si no
      backgroundColor: isSaved.value ? Colors.orange : Colors.blueAccent,
      onPressed: () {
        if (isSaved.value) {
          // CASO 1: Si ya estaba marcado -> ELIMINAR
          context.read<LocalArticleBloc>().add(RemoveArticle(article!));
          isSaved.value = false; // Actualizamos switch visual
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Eliminado de favoritos'),
              duration: Duration(milliseconds: 500),
            ),
          );
        } else {
          // CASO 2: Si no estaba marcado -> GUARDAR
          context.read<LocalArticleBloc>().add(SaveArticle(article!));
          isSaved.value = true; // Actualizamos switch visual
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Guardado en favoritos'),
              duration: Duration(milliseconds: 500),
            ),
          );
        }
      },
      // Lógica de Icono: Relleno vs Borde
      child: Icon(
        isSaved.value ? Ionicons.bookmark : Ionicons.bookmark_outline,
        color: Colors.white,
      ),
    );
  }

  void _onBackButtonTapped(BuildContext context) {
    Navigator.pop(context);
  }
}