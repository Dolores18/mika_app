import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/article_service.dart';
import '../../utils/logger.dart';
import './article_detail_notifier.dart';
import './article_detail_state.dart';

// 使用外部定义的ArticleDetailNotifier和ArticleDetailState
final articleDetailProvider = StateNotifierProvider.family<
    ArticleDetailNotifier, ArticleDetailState, String>((ref, articleId) {
  log.i('创建ArticleDetailNotifier，articleId: $articleId');
  // 创建ArticleService并传递给ArticleDetailNotifier
  return ArticleDetailNotifier(ArticleService(), articleId);
});
