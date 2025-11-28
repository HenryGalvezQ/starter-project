import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_event.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_state.dart';
import 'package:uuid/uuid.dart';

class CreateArticleScreen extends HookWidget {
  const CreateArticleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Controladores
    final titleController = useTextEditingController();
    final contentController = useTextEditingController();
    
    // Estado para la imagen seleccionada (ruta local)
    final localImagePath = useState<String?>(null);
    final picker = useMemoized(() => ImagePicker());

    // Función para tomar foto/seleccionar
    Future<void> _pickImage(ImageSource source) async {
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        localImagePath.value = image.path;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nuevo Reporte", style: TextStyle(color: Colors.black)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // BOTÓN GUARDAR
          IconButton(
            icon: const Icon(Icons.check, color: Colors.blueAccent),
            onPressed: () {
              if (titleController.text.isEmpty || contentController.text.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Título y contenido requeridos")),
                );
                return;
              }

              // Generamos ID único temporal para manejo local
              final String uniqueId = const Uuid().v4();

              final newArticle = ArticleEntity(
                url: uniqueId, // Usamos esto como Primary Key temporal
                title: titleController.text,
                content: contentController.text,
                description: contentController.text.length > 50 
                    ? contentController.text.substring(0, 50) + "..." 
                    : contentController.text,
                publishedAt: DateTime.now().toIso8601String(),
                urlToImage: "", // Se llenará en la nube, localmente usamos localImagePath
                localImagePath: localImagePath.value,
                syncStatus: 'pending', // Nace pendiente
              );

              // Enviamos al Bloc
              context.read<MyArticlesBloc>().add(SaveNewArticle(newArticle));
            },
          )
        ],
      ),
      // Escuchamos el éxito para cerrar la pantalla
      body: BlocListener<MyArticlesBloc, MyArticlesState>(
        listener: (context, state) {
          if (state is ArticleSavedSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Guardado localmente (Pendiente de Sync) 📂")),
            );
            Navigator.pop(context);
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 1. SELECTOR DE IMAGEN
              GestureDetector(
                onTap: () {
                  // Mostrar modal para elegir cámara o galería
                  showModalBottomSheet(context: context, builder: (ctx) {
                    return SafeArea(
                      child: Wrap(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.photo_camera),
                            title: const Text("Cámara"),
                            onTap: () {
                              _pickImage(ImageSource.camera);
                              Navigator.pop(ctx);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.photo_library),
                            title: const Text("Galería"),
                            onTap: () {
                              _pickImage(ImageSource.gallery);
                              Navigator.pop(ctx);
                            },
                          ),
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
                    image: localImagePath.value != null 
                      ? DecorationImage(
                          image: FileImage(File(localImagePath.value!)),
                          fit: BoxFit.cover,
                        )
                      : null
                  ),
                  child: localImagePath.value == null 
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                            Text("Agregar Foto de Portada", style: TextStyle(color: Colors.grey))
                          ],
                        )
                      : null,
                ),
              ),

              const SizedBox(height: 20),

              // 2. TÍTULO
              TextField(
                controller: titleController,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: "Título del titular",
                  border: InputBorder.none,
                ),
                maxLines: 2,
              ),
              
              const Divider(),

              // 3. CONTENIDO
              TextField(
                controller: contentController,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: "Escribe tu reporte aquí...",
                  border: InputBorder.none,
                ),
                maxLines: null, // Multilínea infinito
              ),
            ],
          ),
        ),
      ),
    );
  }
}