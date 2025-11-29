import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // NUEVO IMPORT

// Features - Daily News
import 'package:news_app_clean_architecture/features/daily_news/data/data_sources/remote/news_api_service.dart';
import 'package:news_app_clean_architecture/features/daily_news/data/repository/article_repository_impl.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/repository/article_repository.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/get_article.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_bloc.dart';
import 'features/daily_news/data/data_sources/local/app_database.dart';
import 'features/daily_news/domain/usecases/get_saved_article.dart';
import 'features/daily_news/domain/usecases/remove_article.dart';
import 'features/daily_news/domain/usecases/save_article.dart';
// Nuevos UseCases Fase 5
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/get_my_articles.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/sync_pending_articles.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_bloc.dart'; // Import
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/clear_local_data.dart';
import 'features/daily_news/presentation/bloc/article/local/local_article_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/create_article.dart'; // Importar
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/sync_saved_articles.dart'; // Import
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/get_liked_articles.dart'; // Importar
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/toggle_like_article.dart'; // Importar
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/sync_liked_articles.dart'; // IMPORTAR
// Features - Auth
import 'package:news_app_clean_architecture/features/auth/data/repository/auth_repository_impl.dart';
import 'package:news_app_clean_architecture/features/auth/domain/repository/auth_repository.dart';
import 'package:news_app_clean_architecture/features/auth/domain/usecases/get_auth_state.dart';
import 'package:news_app_clean_architecture/features/auth/domain/usecases/login_user.dart';
import 'package:news_app_clean_architecture/features/auth/domain/usecases/logout_user.dart';
import 'package:news_app_clean_architecture/features/auth/domain/usecases/register_user.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/bloc/auth_bloc.dart';

final sl = GetIt.instance;


Future<void> initializeDependencies() async {
  
  // -- EXTERNAL --
  // Firebase
  sl.registerSingleton<FirebaseAuth>(FirebaseAuth.instance);
  sl.registerSingleton<FirebaseFirestore>(FirebaseFirestore.instance);
  sl.registerSingleton<FirebaseStorage>(FirebaseStorage.instance); // NUEVO

  // Database (Floor)
  final database = await $FloorAppDatabase.databaseBuilder('app_database.db').build();
  sl.registerSingleton<AppDatabase>(database);
  
  // Dio
  final dio = Dio();
  dio.interceptors.add(LogInterceptor(responseBody: true, requestBody: true));
  sl.registerSingleton<Dio>(dio);

  // -- DATA SOURCES --
  sl.registerSingleton<NewsApiService>(NewsApiService(sl()));

  // -- REPOSITORIES --
  
  // Article Repository - ACTUALIZADO FASE 5 (5 Argumentos)
  sl.registerSingleton<ArticleRepository>(
    ArticleRepositoryImpl(sl(), sl(), sl(), sl(), sl())
  );

  // Auth Repository (2 Argumentos: Auth, Firestore)
  sl.registerSingleton<AuthRepository>(
    AuthRepositoryImpl(sl(), sl())
  );
  
  // -- USE CASES --
  
  // Articles - Feed & Saved
  sl.registerSingleton<GetArticleUseCase>(
    GetArticleUseCase(sl())
  );
  sl.registerSingleton<GetSavedArticleUseCase>(
    GetSavedArticleUseCase(sl())
  );
  sl.registerSingleton<SaveArticleUseCase>(
    SaveArticleUseCase(sl())
  );
  sl.registerSingleton<RemoveArticleUseCase>(
    RemoveArticleUseCase(sl())
  );
  // [NUEVO] Likes
  sl.registerSingleton<GetLikedArticlesUseCase>(
    GetLikedArticlesUseCase(sl())
  );
  sl.registerSingleton<ToggleLikeArticleUseCase>(
    ToggleLikeArticleUseCase(sl())
  );
  sl.registerSingleton<SyncLikedArticlesUseCase>(
    SyncLikedArticlesUseCase(sl())
  );
  // Articles - Offline & My Reports (FASE 5)
  sl.registerSingleton<GetMyArticlesUseCase>(
    GetMyArticlesUseCase(sl())
  );
  sl.registerSingleton<SyncPendingArticlesUseCase>(
    SyncPendingArticlesUseCase(sl())
  );
  // ... En la sección -- USE CASES -- (Articles - Offline & My Reports)
  sl.registerSingleton<CreateArticleUseCase>(
    CreateArticleUseCase(sl())
  );
  sl.registerSingleton<ClearLocalDataUseCase>(
  ClearLocalDataUseCase(sl())
  );
  sl.registerSingleton<SyncSavedArticlesUseCase>(
  SyncSavedArticlesUseCase(sl())
  );

  // Auth
  sl.registerSingleton<GetAuthStateUseCase>(GetAuthStateUseCase(sl()));
  sl.registerSingleton<LoginUserUseCase>(LoginUserUseCase(sl()));
  sl.registerSingleton<LogoutUserUseCase>(LogoutUserUseCase(sl()));
  sl.registerSingleton<RegisterUserUseCase>(RegisterUserUseCase(sl())); 

  // -- BLOCS --
  // Remote Articles
  sl.registerFactory<RemoteArticlesBloc>(
    ()=> RemoteArticlesBloc(sl())
  );
  
  // ACTUALIZAR EL BLOC LOCAL (Ahora recibe 7 argumentos: 3 saved, 2 likes, 2 syncs)
  // O podemos simplificar agregando un evento de sincronización.
  // Vamos a inyectar los casos de uso de Sync en el LocalArticleBloc
  
  sl.registerFactory<LocalArticleBloc>(
    ()=> LocalArticleBloc(
      sl(), sl(), sl(), // Saved (Get, Save, Remove)
      sl(), sl(),       // Likes (Get, Toggle)
      sl(), sl()        // Syncs (SyncSaved, SyncLiked) -> AGREGAR ESTOS
    ) 
  );
  // Auth Bloc - ACTUALIZADO FASE 7 (5 Argumentos)
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(sl(), sl(), sl(), sl(), sl())
  );

  sl.registerFactory<MyArticlesBloc>(
  () => MyArticlesBloc(sl(), sl(), sl())
  );

}