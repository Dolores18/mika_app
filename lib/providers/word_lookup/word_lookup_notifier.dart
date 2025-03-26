// lib/providers/word_lookup/word_lookup_notifier.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/dictionary_service.dart';
import '../../services/ai_service.dart';
import '../../utils/logger.dart';
import './word_lookup_state.dart';

class WordLookupNotifier extends StateNotifier<WordLookupState> {
  final DictionaryService _dictionaryService;
  final AiService _aiService;
  StreamSubscription<String>? _aiSubscription;

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

  // 清空结果
  void clearResults() {
    _cancelAiStream();
    state = state.copyWith(
      showResults: false,
      searchedWord: '',
      explanation: '',
      clearDictResult: true,
      contentUpdated: false,
    );
    log.i('清空搜索结果');
  }

  // 搜索单词
  Future<void> searchWord(String word) async {
    if (word.isEmpty) return;

    _cancelAiStream();

    log.i('开始搜索单词: "$word"，模式: ${state.isAiMode ? "AI" : "普通"}');

    state = state.copyWith(
      isLoading: true,
      showResults: true,
      searchedWord: word,
      explanation: '',
      clearDictResult: true,
      contentUpdated: false,
    );

    if (state.isAiMode) {
      _fetchAiExplanation(word);
    } else {
      await _fetchDictionaryExplanation(word);
    }
  }

  // 获取字典解释
  Future<void> _fetchDictionaryExplanation(String word) async {
    try {
      final result = await _dictionaryService.lookupWord(word);
      state = state.copyWith(
        isLoading: false,
        dictResult: result,
        contentUpdated: false,
      );
      log.i('字典查询完成: $word');
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
    super.dispose();
  }
}
