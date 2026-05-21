import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
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

  /// 下载音频到本地缓存目录
  /// 如果已有缓存则直接返回路径，不重复下载
  Future<String?> downloadAudioToCache(String audioUrl) async {
    // 已有缓存，直接返回
    if (state.cachedAudioPath != null) {
      final file = File(state.cachedAudioPath!);
      if (await file.exists()) {
        log.i('[AudioPlayer] 音频缓存已存在: ${state.cachedAudioPath}');
        return state.cachedAudioPath;
      }
    }

    try {
      log.i('[AudioPlayer] 开始下载音频到本地缓存: $audioUrl');
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/audio_$articleId.mp3';

      final response = await http.get(Uri.parse(audioUrl));
      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        log.i('[AudioPlayer] 音频下载完成，缓存路径: $filePath, 大小: ${response.bodyBytes.length} bytes');

        state = state.copyWith(cachedAudioPath: filePath);
        return filePath;
      } else {
        log.e('[AudioPlayer] 音频下载失败: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log.e('[AudioPlayer] 音频下载异常: $e');
      return null;
    }
  }

}

