// lib/providers/word_lookup/word_lookup_state.dart
import 'package:flutter/foundation.dart';
import '../../models/dictionary_result.dart';

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

  // 构造函数，所有字段都是不可变的
  const WordLookupState({
    required this.isLoading,
    required this.showResults,
    required this.isAiMode,
    required this.searchedWord,
    required this.explanation,
    this.dictResult,
    this.contentUpdated = false,
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
  }) {
    return WordLookupState(
      isLoading: isLoading ?? this.isLoading,
      showResults: showResults ?? this.showResults,
      isAiMode: isAiMode ?? this.isAiMode,
      searchedWord: searchedWord ?? this.searchedWord,
      explanation: explanation ?? this.explanation,
      dictResult: clearDictResult ? null : (dictResult ?? this.dictResult),
      contentUpdated: contentUpdated ?? false,
    );
  }

  // 用于调试的toString方法
  @override
  String toString() {
    return 'WordLookupState{isLoading: $isLoading, showResults: $showResults, '
        'isAiMode: $isAiMode, searchedWord: $searchedWord, '
        'hasExplanation: ${explanation.isNotEmpty}, '
        'hasDictResult: ${dictResult != null}}';
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
        other.dictResult == dictResult;
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
      );
}
