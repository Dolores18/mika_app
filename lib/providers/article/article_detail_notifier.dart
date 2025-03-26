import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/article_service.dart';
import '../../utils/logger.dart';
import 'article_detail_state.dart';

class ArticleDetailNotifier extends StateNotifier<ArticleDetailState> {
  final ArticleService _articleService;
  final String articleId;

  ArticleDetailNotifier(this._articleService, this.articleId)
    : super(const ArticleDetailState()) {
    _loadArticle();
  }

  Future<void> _loadArticle() async {
    try {
      final article = await _articleService.getArticleById(articleId);
      state = state.copyWith(article: article);
      loadMarkdownContent();
    } catch (e) {
      log.e('加载文章失败', e);
      state = state.copyWith(
        contentError: '加载文章失败: $e',
        isLoadingContent: false,
      );
    }
  }

  void setFontSize(double fontSize) {
    state = state.copyWith(fontSize: fontSize);
  }

  void toggleDarkMode() {
    state = state.copyWith(isDarkMode: !state.isDarkMode);
  }

  void toggleAudioPlayer() {
    state = state.copyWith(showAudioPlayer: !state.showAudioPlayer);
  }

  void toggleVocabulary() {
    state = state.copyWith(showVocabulary: !state.showVocabulary);
    clearCache();
  }

  void clearCache() {
    state = state.copyWith(htmlContent: null);
    loadMarkdownContent();
  }

  Future<void> loadMarkdownContent() async {
    state = state.copyWith(
      isLoadingContent: true,
      contentError: null,
      showAudioPlayer: true,
    );

    try {
      final markdown = await _articleService.getArticleMarkdownContent(
        articleId,
      );
      state = state.copyWith(htmlContent: markdown, isLoadingContent: false);
    } catch (e) {
      log.e('获取文章内容失败', e);
      state = state.copyWith(
        contentError: '获取文章内容失败: $e',
        isLoadingContent: false,
      );
    }
  }
}
