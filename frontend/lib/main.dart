import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:news_app_clean_architecture/config/routes/routes.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/pages/home/daily_news.dart';
import 'config/theme/app_themes.dart';
import 'features/daily_news/presentation/bloc/article/remote/remote_article_bloc.dart';
import 'features/daily_news/presentation/bloc/article/remote/remote_article_event.dart';
import 'features/daily_news/presentation/bloc/article/local/local_article_bloc.dart'; // Importante
import 'features/daily_news/presentation/bloc/article/local/local_article_event.dart'; // Importante
import 'injection_container.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:news_app_clean_architecture/features/auth/presentation/bloc/auth_event.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/my_articles/my_articles_event.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDependencies();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // CORRECCIÓN CRÍTICA: Usamos MultiBlocProvider aquí.
    // Esto asegura que LocalArticleBloc exista en TODAS las pantallas (Home, Detail, Saved).
    return MultiBlocProvider(
      providers: [
        // NUEVO: Auth Bloc Global
        BlocProvider<AuthBloc>(
          create: (context) => sl()..add(AuthCheckRequested()),
        ),
        // Existentes
        BlocProvider<RemoteArticlesBloc>(
          create: (context) => sl()..add(const GetArticles()),
        ),
        BlocProvider<LocalArticleBloc>(
          create: (context) => sl()..add(const GetSavedArticles()),
        ),
        BlocProvider<MyArticlesBloc>(
          create: (context) => sl()..add(const LoadMyArticles()),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme(),
        onGenerateRoute: AppRoutes.onGenerateRoutes,
        home: const DailyNews(),
      ),
    );
  }
}