import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/article_service.dart';
import 'article_detail_notifier.dart';
import 'article_detail_state.dart';

final articleDetailProvider = StateNotifierProvider.family<ArticleDetailNotifier,
    ArticleDetailState, String>((ref, articleId) {
  final articleService = ArticleService();
  return ArticleDetailNotifier(articleService, articleId);
});
