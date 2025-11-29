import 'package:equatable/equatable.dart';

class ArticleEntity extends Equatable {
  final int? id;
  final String? userId;
  final String? author;
  final String? title;
  final String? description;
  final String? url;
  final String? urlToImage;
  final String? publishedAt;
  final String? content;
  final int? likesCount;
  final String? category;
  
  // NUEVOS CAMPOS OFFLINE-FIRST
  final String? syncStatus; // 'pending', 'synced'
  final String? localImagePath; // Ruta local en el dispositivo
  final bool? isSaved; // Identifica si es un marcador explícito
  final bool? isLiked;
  const ArticleEntity({
    this.id,
    this.userId,
    this.author,
    this.title,
    this.description,
    this.url,
    this.urlToImage,
    this.publishedAt,
    this.content,
    this.likesCount,
    this.syncStatus,
    this.localImagePath,
    this.isSaved,
    this.isLiked,
    this.category,
  });

  @override
  List<Object?> get props {
    return [
      id,
      userId,
      author,
      title,
      description,
      url,
      urlToImage,
      publishedAt,
      content,
      likesCount,
      syncStatus,
      localImagePath,
      isSaved,
      isLiked,
      category,
    ];
  }
}