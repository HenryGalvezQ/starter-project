import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_event.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_state.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/pages/create_article/create_article.dart';
import '../../widgets/article_tile.dart';
import '../../widgets/symmetry_logo.dart';

class MyReports extends StatelessWidget {
  const MyReports({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // TRIGGER AUTOMÁTICO (Opcional): Si deseas sincronizar al abrir la pestaña
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MyArticlesBloc>().add(const SyncMyArticles()); 
    });

    return Scaffold(
      appBar: AppBar(
        // [NUEVO] Logo
        leading: const SymmetryAppLogo(),
        leadingWidth: 50,

        title: Text(
          'Mis Reportes', 
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold
          )
        ),
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
                
                // STACK: Usamos un Stack para superponer los iconos sobre la tarjeta
                return Stack(
                  children: [
                    // CAPA 1: La Tarjeta Normal
                    ArticleWidget(
                      article: article,
                      // Desactivamos el botón de borrar estandar del widget,
                      // usaremos nuestros propios botones personalizados arriba.
                      isRemovable: false, 
                      // [NUEVO] Habilitar clic para ver detalles
                      onArticlePressed: (article) {
                        Navigator.pushNamed(context, '/ArticleDetails', arguments: article);
                      },
                    ),
                    
                    // CAPA 2: Indicador de Sincronización (Esquina Superior Izquierda)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: article.syncStatus == 'pending' ? Colors.orange : Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: Icon(
                          article.syncStatus == 'pending' ? Icons.access_time : Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),

                    // CAPA 3: Botones de Acción CRUD (Esquina Superior Derecha)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Row(
                        children: [
                          // BOTÓN EDITAR (Lápiz)
                          _buildCircleButton(
                            icon: Icons.edit,
                            color: Colors.blueAccent,
                            onTap: () {
                              // Navegamos a CreateArticleScreen pasando el artículo para activar modo EDICIÓN
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreateArticleScreen(articleToEdit: article)
                                ),
                              );
                            }
                          ),
                          
                          const SizedBox(width: 8),

                          // BOTÓN ELIMINAR (Basura)
                          _buildCircleButton(
                            icon: Icons.delete_outline,
                            color: Colors.redAccent,
                            onTap: () {
                              _showDeleteConfirmation(context, article);
                            }
                          ),
                        ],
                      ),
                    ),
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
          // Navegamos sin argumentos -> Modo CREACIÓN
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateArticleScreen()),
          );
        },
        backgroundColor: isDark ? Colors.white : Colors.black87,
        child: Icon(Icons.add, color: isDark ? Colors.black : Colors.white),
      ),
    );
  }

  // Helper para construir los botones circulares blancos
  Widget _buildCircleButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95), // Casi sólido para que se vea bien sobre la imagen
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: color),
        constraints: const BoxConstraints(), // Hace que el botón sea compacto
        padding: const EdgeInsets.all(8),
        onPressed: onTap,
      ),
    );
  }

  // Diálogo de confirmación para eliminar
  void _showDeleteConfirmation(BuildContext context, dynamic article) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar reporte"),
        content: const Text("¿Estás seguro? Se borrará de tu dispositivo y de la nube."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("Cancelar")
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Llamada al evento de borrado Offline-First (Soft Delete)
              // Esto marcará 'pending_delete' y desaparecerá de la lista instantáneamente
              context.read<MyArticlesBloc>().add(DeleteExistingArticle(article));
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Reporte eliminado 🗑️"))
              );
            }, 
            child: const Text("Eliminar", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );
  }
}