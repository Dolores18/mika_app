import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/article_service.dart';
import '../../utils/logger.dart';
import 'article_detail_state.dart';
import '../../renderer/html_renderer.dart';

class ArticleDetailNotifier extends StateNotifier<ArticleDetailState> {
  final ArticleService _articleService;
  final String articleId;

  ArticleDetailNotifier(this._articleService, this.articleId)
      : super(const ArticleDetailState()) {
    _loadArticle();
  }

  Future<void> loadArticle() async {
    await _loadArticle();
  }

  Future<void> _loadArticle() async {
    try {
      final article = await _articleService.getArticleById(articleId);

      // 不再预先获取HTML内容，而是让WebView直接加载
      state = state.copyWith(
        article: article,
        showAudioPlayer: false,
        // 不再设置htmlContent字段，让WebView直接加载
        htmlContent: null,
      );
    } catch (e) {
      log.e('加载文章失败', e);
      state = state.copyWith(
        contentError: '加载文章失败: $e',
      );
    }
  }

  // 添加刷新方法，使用HtmlRenderer静态方法
  void refreshContent() {
    log.i('通过Riverpod刷新文章内容：$articleId');

    // 使用HtmlRenderer静态方法刷新WebView
    HtmlRenderer.refresh(articleId);

    // 重置HTML内容缓存，确保下次加载时获取最新内容
    state = state.copyWith(
      htmlContent: null,
    );

    log.i('文章刷新请求已发送');
  }

  void setFontSize(double fontSize) {
    if (fontSize == state.fontSize) {
      log.d('字体大小未变化，忽略更新: $fontSize');
      return;
    }

    log.i('设置新字体大小: $fontSize');
    state = state.copyWith(fontSize: fontSize);
  }

  void toggleDarkMode() {
    state = state.copyWith(
      isDarkMode: !state.isDarkMode,
    );
  }

  void toggleAudioPlayer() {
    state = state.copyWith(showAudioPlayer: !state.showAudioPlayer);
  }

  void toggleVocabulary() {
    state = state.copyWith(showVocabulary: !state.showVocabulary);
  }

  void clearCache() {
    state = state.copyWith(htmlContent: null);
  }
}
