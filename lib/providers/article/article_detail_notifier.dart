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

  Future<void> loadArticle() async {
    await _loadArticle();
  }

  Future<void> _loadArticle() async {
    try {
      final article = await _articleService.getArticleById(articleId);

      // 获取文章HTML内容
      String? htmlContent;
      if (article != null) {
        try {
          htmlContent = await _articleService.getArticleHtml(articleId);
          log.i('成功获取文章HTML内容，长度: ${htmlContent?.length ?? 0}');
        } catch (e) {
          log.e('获取文章HTML内容失败', e);
          htmlContent = null;
        }
      }

      state = state.copyWith(
        article: article,
        isLoadingContent: false,
        showAudioPlayer: article?.audioUrl != null,
        htmlContent: htmlContent,
      );
    } catch (e) {
      log.e('加载文章失败', e);
      state = state.copyWith(
        contentError: '加载文章失败: $e',
        isLoadingContent: false,
      );
    }
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
    state = state.copyWith(isDarkMode: !state.isDarkMode);
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
