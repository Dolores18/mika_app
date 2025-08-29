import 'package:get/get.dart';
import '../models/highlight_models.dart';
import '../services/highlight_service.dart';
import '../utils/logger.dart';

/// 高亮功能控制器
class HighlightController extends GetxController {
  final HighlightService _highlightService = HighlightService();

  // 当前文章的高亮列表
  final RxList<VocabularyHighlight> _articleHighlights =
      <VocabularyHighlight>[].obs;

  // 加载状态
  final RxBool _isLoading = false.obs;

  // 选中的高亮（用于显示详情或编辑）
  final Rx<VocabularyHighlight?> _selectedHighlight =
      Rx<VocabularyHighlight?>(null);

  // Getters
  List<VocabularyHighlight> get articleHighlights => _articleHighlights;
  bool get isLoading => _isLoading.value;
  VocabularyHighlight? get selectedHighlight => _selectedHighlight.value;

  /// 加载文章的高亮
  Future<void> loadArticleHighlights(String contentId) async {
    try {
      _isLoading.value = true;
      log.i('加载文章高亮: $contentId');

      final highlights =
          await _highlightService.getArticleHighlights(contentId);
      _articleHighlights.assignAll(highlights);

      log.i('文章高亮加载成功: ${highlights.length} 个');
    } catch (e) {
      log.e('加载文章高亮失败: $e');
      Get.snackbar(
        '加载失败',
        '无法加载高亮数据',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  /// 添加高亮
  Future<bool> addHighlight({
    required String contentType,
    required String contentId,
    required String word,
    required String selectedText,
    required TextPosition position,
    String? originalForm,
    HighlightColor color = HighlightColor.yellow,
    String? quickNote,
  }) async {
    try {
      log.i('添加高亮: $word');

      final highlight = await _highlightService.addHighlight(
        contentType: contentType,
        contentId: contentId,
        word: word,
        selectedText: selectedText,
        position: position,
        originalForm: originalForm,
        color: color,
        quickNote: quickNote,
      );

      // 添加到当前列表
      _articleHighlights.add(highlight);

      Get.snackbar(
        '高亮成功',
        '已高亮单词: $word',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      log.i('高亮添加成功: $word');
      return true;
    } catch (e) {
      log.e('添加高亮失败: $e');
      Get.snackbar(
        '高亮失败',
        e.toString().contains('已存在高亮') ? '该位置已存在高亮' : '添加高亮失败',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
  }

  /// 删除高亮
  Future<void> removeHighlight(VocabularyHighlight highlight) async {
    try {
      await _highlightService.removeHighlight(highlight.id);

      // 从当前列表移除
      _articleHighlights.remove(highlight);

      // 如果是当前选中的高亮，清除选中状态
      if (_selectedHighlight.value?.id == highlight.id) {
        _selectedHighlight.value = null;
      }

      Get.snackbar(
        '删除成功',
        '已删除高亮: ${highlight.word}',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      log.i('删除高亮成功: ${highlight.word}');
    } catch (e) {
      log.e('删除高亮失败: $e');
      Get.snackbar(
        '删除失败',
        '无法删除高亮',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// 更新高亮颜色
  Future<void> updateHighlightColor(
      VocabularyHighlight highlight, HighlightColor color) async {
    try {
      await _highlightService.updateHighlightColor(highlight.id, color);

      // 更新本地数据
      final index = _articleHighlights.indexWhere((h) => h.id == highlight.id);
      if (index != -1) {
        _articleHighlights[index].updateColor(color);
        _articleHighlights.refresh();
      }

      // 如果是当前选中的高亮，更新选中状态
      if (_selectedHighlight.value?.id == highlight.id) {
        _selectedHighlight.value!.updateColor(color);
        _selectedHighlight.refresh();
      }

      log.i('更新高亮颜色成功: ${highlight.word}');
    } catch (e) {
      log.e('更新高亮颜色失败: $e');
      Get.snackbar(
        '更新失败',
        '无法更新高亮颜色',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// 更新翻译（预留翻译API）
  Future<void> updateTranslation(
      VocabularyHighlight highlight, String translation) async {
    try {
      await _highlightService.updateTranslation(highlight.id, translation);

      // 更新本地数据
      final index = _articleHighlights.indexWhere((h) => h.id == highlight.id);
      if (index != -1) {
        _articleHighlights[index].updateTranslation(translation);
        _articleHighlights.refresh();
      }

      // 如果是当前选中的高亮，更新选中状态
      if (_selectedHighlight.value?.id == highlight.id) {
        _selectedHighlight.value!.updateTranslation(translation);
        _selectedHighlight.refresh();
      }

      Get.snackbar(
        '翻译更新成功',
        '${highlight.word}: $translation',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      log.i('更新翻译成功: ${highlight.word}');
    } catch (e) {
      log.e('更新翻译失败: $e');
      Get.snackbar(
        '更新失败',
        '无法更新翻译',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// 选中高亮（用于显示详情）
  void selectHighlight(VocabularyHighlight? highlight) {
    _selectedHighlight.value = highlight;
  }

  /// 检查位置是否已有高亮
  bool isPositionHighlighted(
      String paragraphId, int startOffset, int endOffset) {
    return _articleHighlights.any((h) =>
        h.position.paragraphId == paragraphId &&
        h.position.startOffset == startOffset &&
        h.position.endOffset == endOffset);
  }

  /// 根据位置获取高亮
  VocabularyHighlight? getHighlightByPosition(
      String paragraphId, int startOffset, int endOffset) {
    try {
      return _articleHighlights.firstWhere((h) =>
          h.position.paragraphId == paragraphId &&
          h.position.startOffset == startOffset &&
          h.position.endOffset == endOffset);
    } catch (e) {
      return null;
    }
  }

  /// 清空当前文章的高亮（切换文章时调用）
  void clearArticleHighlights() {
    _articleHighlights.clear();
    _selectedHighlight.value = null;
  }

  /// 删除文章的所有高亮（从数据库中删除）
  Future<void> deleteAllArticleHighlights(String contentId) async {
    try {
      log.i('删除文章的所有高亮: $contentId');
      await _highlightService.deleteAllArticleHighlights(contentId);
      _articleHighlights.clear();
      _selectedHighlight.value = null;
      log.i('文章的所有高亮已删除');
    } catch (e) {
      log.e('删除文章的所有高亮失败: $e');
      Get.snackbar(
        '删除失败',
        '无法删除高亮数据',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// 刷新当前文章的高亮
  Future<void> refreshHighlights(String contentId) async {
    await loadArticleHighlights(contentId);
  }
}
