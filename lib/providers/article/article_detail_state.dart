import 'package:flutter/material.dart';
import '../../models/article.dart';

@immutable
class ArticleDetailState {
  final String? contentError;
  final String? htmlContent;
  final double fontSize;
  final bool isDarkMode;
  final bool showAudioPlayer;
  final bool showVocabulary;
  final Article? article;
  final String? cachedAudioPath; // 本地缓存的音频文件路径

  const ArticleDetailState({
    this.contentError,
    this.htmlContent,
    this.fontSize = 16.0,
    this.isDarkMode = false,
    this.showAudioPlayer = false,
    this.showVocabulary = true,
    this.article,
    this.cachedAudioPath,
  });

  ArticleDetailState copyWith({
    String? contentError,
    String? htmlContent,
    double? fontSize,
    bool? isDarkMode,
    bool? showAudioPlayer,
    bool? showVocabulary,
    Article? article,
    String? cachedAudioPath,
  }) {
    return ArticleDetailState(
      contentError: contentError ?? this.contentError,
      htmlContent: htmlContent ?? this.htmlContent,
      fontSize: fontSize ?? this.fontSize,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      showAudioPlayer: showAudioPlayer ?? this.showAudioPlayer,
      showVocabulary: showVocabulary ?? this.showVocabulary,
      article: article ?? this.article,
      cachedAudioPath: cachedAudioPath ?? this.cachedAudioPath,
    );
  }
}
