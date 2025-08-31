// lib/providers/word_lookup/word_lookup_state.dart
import 'package:flutter/foundation.dart';
import '../../models/dictionary_result.dart';

// 语言枚举
enum SearchLanguage {
  english('英语', 'en'),
  japanese('日语', 'ja');

  const SearchLanguage(this.displayName, this.code);
  final String displayName;
  final String code;
}

// 使用不可变类表示状态
@immutable
class WordLookupState {
  final bool isLoading;
  final bool showResults;
  final bool isAiMode;
  final String searchedWord;
  final String explanation;
  final DictionaryResult? dictResult;
  final bool contentUpdated;
  final SearchLanguage selectedLanguage;
  final String? htmlContent; // 用于日语词典的HTML内容
  final List<Map<String, dynamic>> searchSuggestions; // 搜索建议列表
  final bool isLoadingSuggestions; // 是否正在加载建议

  // 构造函数，所有字段都是不可变的
  const WordLookupState({
    required this.isLoading,
    required this.showResults,
    required this.isAiMode,
    required this.searchedWord,
    required this.explanation,
    this.dictResult,
    this.contentUpdated = false,
    this.selectedLanguage = SearchLanguage.english,
    this.htmlContent,
    this.searchSuggestions = const [],
    this.isLoadingSuggestions = false,
  });

  // 创建初始状态的工厂方法
  factory WordLookupState.initial() => const WordLookupState(
        isLoading: false,
        showResults: false,
        isAiMode: false,
        searchedWord: '',
        explanation: '',
        dictResult: null,
        contentUpdated: false,
        selectedLanguage: SearchLanguage.english,
        htmlContent: null,
        searchSuggestions: [],
        isLoadingSuggestions: false,
      );

  // copyWith方法用于创建状态的不可变拷贝
  WordLookupState copyWith({
    bool? isLoading,
    bool? showResults,
    bool? isAiMode,
    String? searchedWord,
    String? explanation,
    DictionaryResult? dictResult,
    bool clearDictResult = false,
    bool? contentUpdated,
    SearchLanguage? selectedLanguage,
    String? htmlContent,
    bool clearHtmlContent = false,
    List<Map<String, dynamic>>? searchSuggestions,
    bool? isLoadingSuggestions,
  }) {
    return WordLookupState(
      isLoading: isLoading ?? this.isLoading,
      showResults: showResults ?? this.showResults,
      isAiMode: isAiMode ?? this.isAiMode,
      searchedWord: searchedWord ?? this.searchedWord,
      explanation: explanation ?? this.explanation,
      dictResult: clearDictResult ? null : (dictResult ?? this.dictResult),
      contentUpdated: contentUpdated ?? false,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      htmlContent: clearHtmlContent ? null : (htmlContent ?? this.htmlContent),
      searchSuggestions: searchSuggestions ?? this.searchSuggestions,
      isLoadingSuggestions: isLoadingSuggestions ?? this.isLoadingSuggestions,
    );
  }

  // 用于调试的toString方法
  @override
  String toString() {
    return 'WordLookupState{isLoading: $isLoading, showResults: $showResults, '
        'isAiMode: $isAiMode, searchedWord: $searchedWord, '
        'hasExplanation: ${explanation.isNotEmpty}, '
        'hasDictResult: ${dictResult != null}, '
        'selectedLanguage: ${selectedLanguage.displayName}, '
        'hasHtmlContent: ${htmlContent != null}, '
        'suggestionsCount: ${searchSuggestions.length}}';
  }

  // 用于比较的equals方法和hashCode
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WordLookupState &&
        other.isLoading == isLoading &&
        other.showResults == showResults &&
        other.isAiMode == isAiMode &&
        other.searchedWord == searchedWord &&
        other.explanation == explanation &&
        other.contentUpdated == contentUpdated &&
        other.dictResult == dictResult &&
        other.selectedLanguage == selectedLanguage &&
        other.htmlContent == htmlContent &&
        other.searchSuggestions.length == searchSuggestions.length &&
        other.isLoadingSuggestions == isLoadingSuggestions;
  }

  @override
  int get hashCode => Object.hash(
        isLoading,
        showResults,
        isAiMode,
        searchedWord,
        explanation,
        dictResult,
        contentUpdated,
        selectedLanguage,
        htmlContent,
        searchSuggestions.length,
        isLoadingSuggestions,
      );
}
