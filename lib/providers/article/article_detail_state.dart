import 'package:flutter/material.dart';
import '../../models/article.dart';

@immutable
class ArticleDetailState {
  final bool isLoadingContent;
  final String? contentError;
  final String? htmlContent;
  final double fontSize;
  final bool isDarkMode;
  final bool showAudioPlayer;
  final bool showVocabulary;
  final Article? article;

  const ArticleDetailState({
    this.isLoadingContent = false,
    this.contentError,
    this.htmlContent,
    this.fontSize = 16.0,
    this.isDarkMode = false,
    this.showAudioPlayer = true,
    this.showVocabulary = true,
    this.article,
  });

  ArticleDetailState copyWith({
    bool? isLoadingContent,
    String? contentError,
    String? htmlContent,
    double? fontSize,
    bool? isDarkMode,
    bool? showAudioPlayer,
    bool? showVocabulary,
    Article? article,
  }) {
    return ArticleDetailState(
      isLoadingContent: isLoadingContent ?? this.isLoadingContent,
      contentError: contentError ?? this.contentError,
      htmlContent: htmlContent ?? this.htmlContent,
      fontSize: fontSize ?? this.fontSize,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      showAudioPlayer: showAudioPlayer ?? this.showAudioPlayer,
      showVocabulary: showVocabulary ?? this.showVocabulary,
      article: article ?? this.article,
    );
  }
}
