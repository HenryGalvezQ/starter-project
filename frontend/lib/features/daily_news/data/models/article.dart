import 'package:floor/floor.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/entities/article.dart';
import '../../../../core/constants/constants.dart';

@Entity(tableName: 'article', primaryKeys: ['url'])
class ArticleModel extends ArticleEntity {
  const ArticleModel({
    int? id,
    String? userId,
    String? author,
    String? title,
    String? description,
    String? url,
    String? urlToImage,
    String? publishedAt,
    String? content,
    int? likesCount,
    String? syncStatus,
    String? localImagePath,
    bool? isSaved,
    String? category,
  }): super(
    id: id,
    userId: userId,
    author: author,
    title: title,
    description: description,
    url: url,
    urlToImage: urlToImage,
    publishedAt: publishedAt,
    content: content,
    likesCount: likesCount,
    syncStatus: syncStatus,
    localImagePath: localImagePath,
    isSaved: isSaved,
    category: category,
  );

  factory ArticleModel.fromJson(Map < String, dynamic > map) {
    return ArticleModel(
      userId: map['userId'] ?? "",
      author: map['author'] ?? "",
      title: map['title'] ?? "",
      description: map['description'] ?? "",
      url: map['url'] ?? "",
      urlToImage: map['urlToImage'] != null && map['urlToImage'] != "" ? map['urlToImage'] : kDefaultImage,
      publishedAt: map['publishedAt'] ?? "",
      content: map['content'] ?? "",
      likesCount: map['likesCount'] ?? 0,
      // Los campos locales usualmente vienen nulos del API, asignamos defaults
      syncStatus: map['syncStatus'] ?? 'synced', 
      localImagePath: null, 
      isSaved: false, 
      category: map['category'] ?? "General",
    );
  }

  factory ArticleModel.fromEntity(ArticleEntity entity) {
    return ArticleModel(
      id: entity.id,
      userId: entity.userId,
      author: entity.author,
      title: entity.title,
      description: entity.description,
      url: entity.url,
      urlToImage: entity.urlToImage,
      publishedAt: entity.publishedAt,
      content: entity.content,
      likesCount: entity.likesCount,
      syncStatus: entity.syncStatus,
      localImagePath: entity.localImagePath,
      isSaved: entity.isSaved,
      category: entity.category,
    );
  }
}