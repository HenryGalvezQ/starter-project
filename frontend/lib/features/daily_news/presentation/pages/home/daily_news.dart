import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_state.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/pages/home/my_reports.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/pages/saved_article/saved_article.dart';

import '../../../domain/entities/article.dart';
import '../../widgets/article_tile.dart';

class DailyNews extends HookWidget {
  const DailyNews({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Hook to manage the state of the bottom navigation bar
    final tabIndex = useState(0);

    return Scaffold(
      body: IndexedStack(
        index: tabIndex.value,
        children: const [
          _FitnessNewsView(), // Tab 0: API News
          MyReports(),        // Tab 1: Local User Reports
          SavedArticles(),    // Tab 2: Saved Bookmarks
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: tabIndex.value,
        onTap: (index) => tabIndex.value = index,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Fitness News',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            label: 'My Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border),
            label: 'Saved',
          ),
        ],
      ),
    );
  }
}

class _FitnessNewsView extends StatelessWidget {
  const _FitnessNewsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppbar(context),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppbar(BuildContext context) {
    return AppBar(
      title: const Text(
        'Fitness News',
        style: TextStyle(color: Colors.black),
      ),
    );
  }

  Widget _buildBody() {
    return BlocBuilder<RemoteArticlesBloc, RemoteArticlesState>(
      builder: (context, state) {
        if (state is RemoteArticlesLoading) {
          return const Center(child: CupertinoActivityIndicator());
        }
        if (state is RemoteArticlesError) {
          return const Center(child: Icon(Icons.refresh));
        }
        if (state is RemoteArticlesDone) {
          return _buildArticlesList(context, state.articles!);
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildArticlesList(
      BuildContext context, List<ArticleEntity> articles) {
    return ListView.builder(
      itemCount: articles.length,
      itemBuilder: (context, index) {
        return ArticleWidget(
          article: articles[index],
          onArticlePressed: (article) =>
              _onArticlePressed(context, article),
        );
      },
    );
  }

  void _onArticlePressed(BuildContext context, ArticleEntity article) {
    Navigator.pushNamed(context, '/ArticleDetails', arguments: article);
  }
}