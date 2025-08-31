// lib/providers/word_lookup/word_lookup_notifier.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/dictionary_service.dart';
import '../../services/ai_service.dart';
import '../../models/dictionary_result.dart';
import '../../utils/logger.dart';
import './word_lookup_state.dart';

class WordLookupNotifier extends StateNotifier<WordLookupState> {
  final DictionaryService _dictionaryService;
  final AiService _aiService;
  StreamSubscription<String>? _aiSubscription;
  Timer? _searchTimer; // 用于防抖的计时器

  WordLookupNotifier(this._dictionaryService, this._aiService)
      : super(WordLookupState.initial());

  // 切换AI模式
  void toggleAiMode() {
    state = state.copyWith(isAiMode: !state.isAiMode, contentUpdated: false);
    log.i('切换AI模式: ${state.isAiMode}');

    // 如果已有搜索结果，重新搜索
    if (state.searchedWord.isNotEmpty) {
      searchWord(state.searchedWord);
    }
  }

  // 设置AI模式
  void setAiMode(bool isAiMode) {
    if (state.isAiMode != isAiMode) {
      state = state.copyWith(isAiMode: isAiMode, contentUpdated: false);
      log.i('设置AI模式: ${state.isAiMode}');
    }
  }

  // 切换语言
  void changeLanguage(SearchLanguage language) {
    if (state.selectedLanguage != language) {
      state = state.copyWith(
        selectedLanguage: language, 
        contentUpdated: false,
        searchSuggestions: [], // 清空搜索建议
      );
      log.i('切换语言: ${language.displayName}');
      
      // 如果已有搜索结果，重新搜索
      if (state.searchedWord.isNotEmpty) {
        searchWord(state.searchedWord);
      }
    }
  }

  // 实时搜索建议（带防抖）
  void searchSuggestions(String query) {
    // 取消之前的计时器
    _searchTimer?.cancel();
    
    // 如果查询为空或不是日语，清空建议
    if (query.isEmpty || state.selectedLanguage != SearchLanguage.japanese) {
      state = state.copyWith(searchSuggestions: [], isLoadingSuggestions: false);
      return;
    }

    // 设置加载状态
    state = state.copyWith(isLoadingSuggestions: true);

    // 设置防抖计时器（300ms延迟）
    _searchTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final suggestions = await _dictionaryService.searchJapanesePrefix(query);
        
        // 更新搜索建议
        state = state.copyWith(
          searchSuggestions: suggestions.take(8).toList(), // 限制显示8个建议
          isLoadingSuggestions: false,
        );
        log.i('✅ 搜索建议更新: $query -> ${suggestions.length}个结果');
      } catch (e) {
        log.e('搜索建议异常', e);
        state = state.copyWith(
          searchSuggestions: [],
          isLoadingSuggestions: false,
        );
      }
    });
  }

  // 清空搜索建议
  void clearSuggestions() {
    _searchTimer?.cancel();
    state = state.copyWith(searchSuggestions: [], isLoadingSuggestions: false);
  }

  // 清空结果
  void clearResults() {
    _cancelAiStream();
    _searchTimer?.cancel();
    state = state.copyWith(
      showResults: false,
      searchedWord: '',
      explanation: '',
      clearDictResult: true,
      clearHtmlContent: true,
      contentUpdated: false,
      searchSuggestions: [],
      isLoadingSuggestions: false,
    );
    log.i('清空搜索结果');
  }

  // 搜索单词
  Future<void> searchWord(String word, {void Function()? onCompleted}) async {
    if (word.isEmpty) return;

    _cancelAiStream();

    log.i('开始搜索单词: "$word"，模式: ${state.isAiMode ? "AI" : "普通"}');

    state = state.copyWith(
      isLoading: true,
      showResults: true,
      searchedWord: word,
      explanation: '',
      clearDictResult: true,
      clearHtmlContent: true,
      contentUpdated: false,
    );

    if (state.isAiMode) {
      _fetchAiExplanation(word);
    } else {
      await _fetchDictionaryExplanation(word);
      onCompleted?.call();
    }
  }

  // 获取字典解释
  Future<void> _fetchDictionaryExplanation(String word) async {
    try {
      final response = await _dictionaryService.lookupWord(word, state.selectedLanguage);
      final result = response['result'] as DictionaryResult?;
      final htmlContent = response['htmlContent'] as String?;
      
      state = state.copyWith(
        isLoading: false,
        dictResult: result,
        htmlContent: htmlContent,
        contentUpdated: false,
      );
      log.i('字典查询完成: $word (${state.selectedLanguage.displayName})');
    } catch (e) {
      log.e('字典查询异常', e);
      state = state.copyWith(
        isLoading: false,
        explanation: '查询出错: $e',
        contentUpdated: false,
      );
    }
  }

  // 获取AI解释
  void _fetchAiExplanation(String word) {
    String processedContent = '';
    bool hasReceivedContent = false;

    try {
      final stream = _aiService.explainWord(word);

      _aiSubscription = stream.listen(
        (newChunk) {
          processedContent += newChunk;

          // 第一次收到内容时关闭加载指示器
          final bool shouldHideLoading =
              !hasReceivedContent && newChunk.trim().isNotEmpty;
          hasReceivedContent = hasReceivedContent || newChunk.trim().isNotEmpty;

          if (shouldHideLoading) {
            log.i('关闭加载指示器，显示内容');
          }

          if (newChunk.trim().isNotEmpty) {
            state = state.copyWith(
              explanation: processedContent,
              isLoading: shouldHideLoading ? false : state.isLoading,
              contentUpdated: true,
            );

            log.i('更新AI内容: 当前总长度 ${processedContent.length}字符');
          }
        },
        onDone: () {
          log.i('AI流式响应完成: ${state.searchedWord}');
          state = state.copyWith(isLoading: false, contentUpdated: false);
        },
        onError: (error) {
          log.e('AI流式响应错误', error);
          state = state.copyWith(
            isLoading: false,
            explanation: '错误: $error',
            contentUpdated: false,
          );
        },
      );
    } catch (e) {
      log.e('AI API请求异常', e);
      state = state.copyWith(
        isLoading: false,
        explanation: '错误: $e',
        contentUpdated: false,
      );
    }
  }

  // 取消AI流
  void _cancelAiStream() {
    _aiSubscription?.cancel();
    _aiSubscription = null;
  }

  // 销毁时清理资源
  @override
  void dispose() {
    _cancelAiStream();
    _searchTimer?.cancel();
    super.dispose();
  }
}
