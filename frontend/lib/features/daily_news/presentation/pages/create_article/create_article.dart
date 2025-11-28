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
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

// Categorías fijas del sistema
const List<String> kArticleCategories = [
  'General',
  'Workout',
  'Nutrition',
  'Mental Health',
  'Gear',
  'Events'
];

class CreateArticleScreen extends HookWidget {
  const CreateArticleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final titleController = useTextEditingController();
    final contentController = useTextEditingController();
    
    // NUEVO: Estado para la categoría (Valor inicial 'General')
    final selectedCategory = useState<String>(kArticleCategories[0]);
    
    final localImagePath = useState<String?>(null);
    final picker = useMemoized(() => ImagePicker());

    Future<void> _pickImage(ImageSource source) async {
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        // 1. Obtener directorio seguro de la app (No se borra al cerrar)
        final directory = await getApplicationDocumentsDirectory();
        
        // 2. Crear nombre de archivo único
        final fileName = path.basename(image.path);
        final permanentPath = '${directory.path}/$fileName';
        
        // 3. Mover archivo de caché a documentos
        final File permanentImage = await File(image.path).copy(permanentPath);

        // 4. Guardar la ruta PERMANENTE
        localImagePath.value = permanentImage.path;
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
          IconButton(
            icon: const Icon(Icons.check, color: Colors.blueAccent),
            onPressed: () {
              if (titleController.text.isEmpty || contentController.text.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Título y contenido requeridos")),
                );
                return;
              }

              // LÓGICA DE AUTO-GENERACIÓN
              // 1. Generamos descripción automática del contenido (resumen)
              String autoDescription = contentController.text;
              if (autoDescription.length > 100) {
                autoDescription = "${autoDescription.substring(0, 100)}...";
              }

              final String uniqueId = const Uuid().v4();

              final newArticle = ArticleEntity(
                url: uniqueId,
                title: titleController.text,
                content: contentController.text,
                description: autoDescription, // <--- Aquí va el automático
                category: selectedCategory.value,
                publishedAt: DateTime.now().toIso8601String(),
                urlToImage: "", 
                localImagePath: localImagePath.value,
                syncStatus: 'pending',
                
                author: "", // Se llenará en el Repositorio con el Auth User

              );
              context.read<MyArticlesBloc>().add(SaveNewArticle(newArticle));
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
              // 1. IMAGEN
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(context: context, builder: (ctx) {
                    return SafeArea(
                      child: Wrap(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.photo_camera),
                            title: const Text("Cámara"),
                            onTap: () { _pickImage(ImageSource.camera); Navigator.pop(ctx); },
                          ),
                          ListTile(
                            leading: const Icon(Icons.photo_library),
                            title: const Text("Galería"),
                            onTap: () { _pickImage(ImageSource.gallery); Navigator.pop(ctx); },
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
                            Text("Portada", style: TextStyle(color: Colors.grey))
                          ],
                        )
                      : null,
                ),
              ),

              const SizedBox(height: 20),

              // 2. CATEGORÍA (Dropdown)
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
                    icon: const Icon(Icons.arrow_drop_down),
                    items: kArticleCategories.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) selectedCategory.value = newValue;
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. TÍTULO
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

              // 4. CONTENIDO (Expandido)
              TextField(
                controller: contentController,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: "Escribe tu reporte aquí...",
                  border: InputBorder.none,
                ),
                maxLines: null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}