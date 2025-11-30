import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:news_app_clean_architecture/core/constants/constants.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_event.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_state.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class CreateArticleScreen extends HookWidget {
  final ArticleEntity? articleToEdit; // Si es null, es CREAR. Si tiene data, es EDITAR.

  const CreateArticleScreen({Key? key, this.articleToEdit}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = articleToEdit != null;
    
    // HOOKS: Pre-llenamos si estamos editando
    final titleController = useTextEditingController(text: articleToEdit?.title);
    final contentController = useTextEditingController(text: articleToEdit?.content);
    final selectedCategory = useState<String>(articleToEdit?.category ?? kArticleCategories[0]);
    
    // IMAGEN: Prioridad -> 1. Nueva (picker) 2. Local existente (pending) 3. Remota existente
    final localImagePath = useState<String?>(articleToEdit?.localImagePath);
    
    // [CAMBIO 1] Hook para saber si el usuario eliminó explícitamente la imagen original remota
    final isRemoteImageRemoved = useState(false);
    
    final picker = useMemoized(() => ImagePicker());

    Future<void> _pickImage(ImageSource source) async {
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = path.basename(image.path);
        // Creamos una copia permanente
        final permanentPath = '${directory.path}/$fileName';
        await File(image.path).copy(permanentPath);
        
        localImagePath.value = permanentPath;
        // Si seleccionamos una nueva, reseteamos el flag de eliminado para que se muestre la nueva
        isRemoteImageRemoved.value = false; 
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? "Editar Reporte" : "Nuevo Reporte", 
          style: TextStyle(color: isDark ? Colors.white : Colors.black)
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.blueAccent),
            onPressed: () {
              // 1. Validaciones básicas
              if (titleController.text.isEmpty || contentController.text.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Título y contenido requeridos")),
                );
                return;
              }

              // 2. Generar descripción automática
              String autoDescription = contentController.text;
              if (autoDescription.length > 90) {
                autoDescription = "${autoDescription.substring(0, 90)}...";
              }

              // 3. Definir IDs y Fechas
              final uniqueId = isEditing ? articleToEdit!.url : const Uuid().v4();
              final publishedDate = isEditing ? articleToEdit!.publishedAt : DateTime.now().toIso8601String();

              // [CAMBIO 2] Lógica estricta para determinar la URL remota final
              String finalUrlToImage = "";
              if (localImagePath.value != null) {
                // Hay nueva imagen local -> Borramos url remota para forzar resubida
                finalUrlToImage = ""; 
              } else if (isRemoteImageRemoved.value) {
                // El usuario borró la imagen -> Enviamos vacío
                finalUrlToImage = "";
              } else {
                // Mantenemos la original si existe
                finalUrlToImage = articleToEdit?.urlToImage ?? "";
              }

              // 4. Construir Entidad
              final article = ArticleEntity(
                url: uniqueId,
                title: titleController.text,
                content: contentController.text,
                description: autoDescription,
                category: selectedCategory.value,
                publishedAt: publishedDate,
                
                urlToImage: finalUrlToImage,
                localImagePath: localImagePath.value,
                
                // CRÍTICO: Siempre 'pending' al guardar
                syncStatus: 'pending', 
                
                author: articleToEdit?.author ?? "", 
                userId: articleToEdit?.userId,
                likesCount: articleToEdit?.likesCount ?? 0,
              );

              // 5. Disparar Evento Correcto
              if (isEditing) {
                context.read<MyArticlesBloc>().add(UpdateExistingArticle(article));
              } else {
                context.read<MyArticlesBloc>().add(SaveNewArticle(article));
              }
            },
          )
        ],
      ),
      body: BlocListener<MyArticlesBloc, MyArticlesState>(
        listener: (context, state) {
          if (state is ArticleSavedSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Guardado localmente 📂")),
            );
            Navigator.pop(context);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // [CAMBIO 3] AREA DE IMAGEN CON STACK Y BOTÓN DE BORRAR
              Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(context: context, builder: (ctx) {
                        return SafeArea(
                          child: Wrap(
                            children: [
                              ListTile(leading: const Icon(Icons.photo_camera), title: const Text("Cámara"), onTap: () { _pickImage(ImageSource.camera); Navigator.pop(ctx); }),
                              ListTile(leading: const Icon(Icons.photo_library), title: const Text("Galería"), onTap: () { _pickImage(ImageSource.gallery); Navigator.pop(ctx); }),
                            ],
                          ),
                        );
                      });
                    },
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      // Pasamos logicamente si debemos mostrar la remota o no
                      child: _buildImageContent(
                        localImagePath.value, 
                        isRemoteImageRemoved.value ? null : articleToEdit?.urlToImage
                      ),
                    ),
                  ),

                  // BOTÓN X (Solo aparece si hay alguna imagen visible)
                  if (localImagePath.value != null || (!isRemoteImageRemoved.value && articleToEdit?.urlToImage != null && articleToEdit!.urlToImage!.isNotEmpty))
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          // Acción de borrar: Limpiamos local y marcamos remoto como eliminado
                          localImagePath.value = null;
                          isRemoteImageRemoved.value = true;
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // DROPDOWN CATEGORIA
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCategory.value,
                    isExpanded: true,
                    items: kArticleCategories.map((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value));
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) selectedCategory.value = newValue;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // INPUT TITULO
              TextField(
                controller: titleController,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(hintText: "Título del titular", border: InputBorder.none),
                maxLines: 2,
              ),
              
              const Divider(),

              // INPUT CONTENIDO
              TextField(
                controller: contentController,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(hintText: "Escribe tu reporte aquí...", border: InputBorder.none),
                maxLines: null,
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent(String? localPath, String? remoteUrl) {
    if (localPath != null && localPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(File(localPath), fit: BoxFit.cover),
      );
    } 
    else if (remoteUrl != null && remoteUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
           imageUrl: remoteUrl, 
           fit: BoxFit.cover,
           placeholder: (c, u) => const Center(child: Icon(Icons.image, color: Colors.grey)),
           errorWidget: (c, u, e) => const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [Icon(Icons.add_a_photo, size: 40, color: Colors.grey), Text("Portada", style: TextStyle(color: Colors.grey))],
    );
  }
}