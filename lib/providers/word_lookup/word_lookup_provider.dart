// lib/providers/word_lookup/word_lookup_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/dictionary_service.dart';
import '../../services/ai_service.dart';
import '../../models/dictionary_result.dart';
import './word_lookup_state.dart';
import './word_lookup_notifier.dart';

// 状态通知器提供者
final wordLookupProvider =
    StateNotifierProvider<WordLookupNotifier, WordLookupState>((ref) {
  // 创建服务实例
  final dictionaryService = DictionaryService();
  final aiService = AiService();

  // 返回通知器实例
  return WordLookupNotifier(dictionaryService, aiService);
});

// 便捷的单词搜索情况选择器
final isWordSearchLoadingProvider = Provider<bool>((ref) {
  return ref.watch(wordLookupProvider).isLoading;
});

// 便捷的AI模式选择器
final isAiModeProvider = Provider<bool>((ref) {
  return ref.watch(wordLookupProvider).isAiMode;
});

// 便捷的结果显示状态选择器
final showResultsProvider = Provider<bool>((ref) {
  return ref.watch(wordLookupProvider).showResults;
});

// 便捷的解释内容选择器
final explanationProvider = Provider<String>((ref) {
  return ref.watch(wordLookupProvider).explanation;
});

// 便捷的字典结果选择器
final dictResultProvider = Provider<DictionaryResult?>((ref) {
  return ref.watch(wordLookupProvider).dictResult;
});
