import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
import 'features/daily_news/presentation/bloc/article/local/local_article_bloc.dart';

// Features - Auth
import 'package:news_app_clean_architecture/features/auth/data/repository/auth_repository_impl.dart';
import 'package:news_app_clean_architecture/features/auth/domain/repository/auth_repository.dart';
import 'package:news_app_clean_architecture/features/auth/domain/usecases/get_auth_state.dart';
import 'package:news_app_clean_architecture/features/auth/domain/usecases/login_user.dart';
import 'package:news_app_clean_architecture/features/auth/domain/usecases/logout_user.dart';
import 'package:news_app_clean_architecture/features/auth/domain/usecases/register_user.dart'; // NUEVO
import 'package:news_app_clean_architecture/features/auth/presentation/bloc/auth_bloc.dart';

final sl = GetIt.instance;

Future<void> initializeDependencies() async {
  
  // -- EXTERNAL --
  // Firebase
  sl.registerSingleton<FirebaseAuth>(FirebaseAuth.instance);
  sl.registerSingleton<FirebaseFirestore>(FirebaseFirestore.instance); // NUEVO

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
  // Article Repository
  sl.registerSingleton<ArticleRepository>(
    ArticleRepositoryImpl(sl(), sl())
  );

  // Auth Repository (Actualizado con 2 dependencias: Auth y Firestore)
  sl.registerSingleton<AuthRepository>(
    AuthRepositoryImpl(sl(), sl())
  );
  
  // -- USE CASES --
  // Articles
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

  // Auth
  sl.registerSingleton<GetAuthStateUseCase>(GetAuthStateUseCase(sl()));
  sl.registerSingleton<LoginUserUseCase>(LoginUserUseCase(sl()));
  sl.registerSingleton<LogoutUserUseCase>(LogoutUserUseCase(sl()));
  sl.registerSingleton<RegisterUserUseCase>(RegisterUserUseCase(sl())); // NUEVO

  // -- BLOCS --
  // Remote Articles
  sl.registerFactory<RemoteArticlesBloc>(
    ()=> RemoteArticlesBloc(sl())
  );
  
  // Local Articles
  sl.registerFactory<LocalArticleBloc>(
    ()=> LocalArticleBloc(sl(),sl(),sl())
  );

  // Auth Bloc
  // NOTA: Por ahora lo dejamos con 3 argumentos. 
  // En el siguiente paso actualizaremos el Bloc para recibir RegisterUserUseCase
  // y entonces volveremos aquí para agregar el 4to 'sl()'.
// Auth Bloc
  // ACTUALIZADO: Ahora pasamos 4 dependencias
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(sl(), sl(), sl(), sl())
  );
}