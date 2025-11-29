import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_event.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_state.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/pages/create_article/create_article.dart';
import '../../widgets/article_tile.dart';

class MyReports extends StatelessWidget {
  const MyReports({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TRIGGER AUTOMÁTICO DE SYNC AL ENTRAR (Opcional, buena práctica UX)
    // Usamos addPostFrameCallback para no bloquear el build
    WidgetsBinding.instance.addPostFrameCallback((_) {
       // context.read<MyArticlesBloc>().add(const SyncMyArticles()); 
       // Descomentar arriba si quieres auto-sync agresivo al abrir la tab
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports', style: TextStyle(color: Colors.black)),
        actions: [
          // BOTÓN DE SINCRONIZACIÓN MANUAL
          IconButton(
            icon: const Icon(Icons.cloud_upload, color: Colors.blue),
            onPressed: () {
               context.read<MyArticlesBloc>().add(const SyncMyArticles());
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("Sincronizando... ☁️")),
               );
            },
          )
        ],
      ),
      
      // LISTA DE ARTÍCULOS PROPIOS
      body: BlocBuilder<MyArticlesBloc, MyArticlesState>(
        builder: (context, state) {
          if (state is MyArticlesLoading) {
            return const Center(child: CupertinoActivityIndicator());
          }
          
          if (state is MyArticlesLoaded || state is MyArticlesSyncSuccess) {
            
            if (state.articles == null || state.articles!.isEmpty) {
              return const Center(child: Text("No has escrito reportes aún."));
            }
            
            return ListView.builder(
              itemCount: state.articles!.length,
              itemBuilder: (context, index) {
                final article = state.articles![index];
                
                // STACK: Artículo + Indicador de Estado
                return Stack(
                  children: [
                    ArticleWidget(
                      article: article,
                      // En "Mis Reportes", generalmente no nos damos like/save a nosotros mismos
                      // (o se maneja distinto), así que deshabilitamos esas opciones visualmente
                      // o las dejamos por defecto.
                      isRemovable: false, 
                      
                      // Opcional: Si quieres permitir editar al tocar, define esto:
                      // onArticlePressed: (article) => _navigateToEdit(context, article),
                    ),
                    
                    // INDICADOR DE ESTADO (Esquina superior derecha)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: article.syncStatus == 'pending' ? Colors.orange : Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          article.syncStatus == 'pending' ? Icons.access_time : Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    )
                  ],
                );
              },
            );
          }
          return const SizedBox();
        },
      ),

      // BOTÓN FLOTANTE PARA CREAR
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateArticleScreen()),
          );
        },
        backgroundColor: Colors.black87,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}