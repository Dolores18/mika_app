import 'package:isar/isar.dart';
import '../models/highlight_models.dart';
import '../services/database_service.dart';
import '../utils/logger.dart';

/// 高亮功能服务
class HighlightService {
  final DatabaseService _databaseService = DatabaseService.instance;

  /// 添加词汇高亮
  Future<VocabularyHighlight> addHighlight({
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
      final isar = await _databaseService.database;

      // 检查是否已存在相同位置的高亮（使用文本偏移位置）
      final existing = await isar.vocabularyHighlights
          .filter()
          .contentIdEqualTo(contentId)
          .and()
          .position((q) => q
              .startOffsetEqualTo(position.startOffset)
              .and()
              .endOffsetEqualTo(position.endOffset))
          .findFirst();

      if (existing != null) {
        log.w('该位置已存在高亮: ${existing.word}');
        throw Exception('该位置已存在高亮');
      }

      final highlight = VocabularyHighlight.create(
        contentType: contentType,
        contentId: contentId,
        word: word,
        selectedText: selectedText,
        position: position,
        originalForm: originalForm,
        highlightColor: color,
        quickNote: quickNote,
      );

      await isar.writeTxn(() async {
        await isar.vocabularyHighlights.put(highlight);
      });

      log.i('添加高亮成功: $word');
      return highlight;
    } catch (e) {
      log.e('添加高亮失败: $e');
      rethrow;
    }
  }

  /// 删除高亮
  Future<void> removeHighlight(Id highlightId) async {
    try {
      final isar = await _databaseService.database;

      await isar.writeTxn(() async {
        final success = await isar.vocabularyHighlights.delete(highlightId);
        if (!success) {
          throw Exception('高亮不存在或删除失败');
        }
      });

      log.i('删除高亮成功: ID $highlightId');
    } catch (e) {
      log.e('删除高亮失败: $e');
      rethrow;
    }
  }

  /// 删除文章的所有高亮
  Future<void> deleteAllArticleHighlights(String contentId) async {
    try {
      final isar = await _databaseService.database;

      await isar.writeTxn(() async {
        final count = await isar.vocabularyHighlights
            .filter()
            .contentIdEqualTo(contentId)
            .deleteAll();
        log.i('删除了 $count 个高亮');
      });

      log.i('删除文章所有高亮成功: $contentId');
    } catch (e) {
      log.e('删除文章所有高亮失败: $e');
      rethrow;
    }
  }

  /// 更新高亮颜色
  Future<void> updateHighlightColor(
      Id highlightId, HighlightColor color) async {
    try {
      final isar = await _databaseService.database;

      await isar.writeTxn(() async {
        final highlight = await isar.vocabularyHighlights.get(highlightId);
        if (highlight == null) {
          throw Exception('高亮不存在');
        }

        highlight.updateColor(color);
        await isar.vocabularyHighlights.put(highlight);
      });

      log.i('更新高亮颜色成功: ID $highlightId');
    } catch (e) {
      log.e('更新高亮颜色失败: $e');
      rethrow;
    }
  }

  /// 更新翻译
  Future<void> updateTranslation(Id highlightId, String translation) async {
    try {
      final isar = await _databaseService.database;

      await isar.writeTxn(() async {
        final highlight = await isar.vocabularyHighlights.get(highlightId);
        if (highlight == null) {
          throw Exception('高亮不存在');
        }

        highlight.updateTranslation(translation);
        await isar.vocabularyHighlights.put(highlight);
      });

      log.i('更新翻译成功: ID $highlightId');
    } catch (e) {
      log.e('更新翻译失败: $e');
      rethrow;
    }
  }

  /// 获取文章的所有高亮
  Future<List<VocabularyHighlight>> getArticleHighlights(
      String contentId) async {
    try {
      final isar = await _databaseService.database;

      final highlights = await isar.vocabularyHighlights
          .filter()
          .contentIdEqualTo(contentId)
          .sortByCreatedAt()
          .findAll();

      log.d('获取文章高亮成功: $contentId, 共 ${highlights.length} 个');
      return highlights;
    } catch (e) {
      log.e('获取文章高亮失败: $e');
      return [];
    }
  }

  /// 获取所有词汇（用于复习）
  Future<List<VocabularyHighlight>> getAllVocabulary() async {
    try {
      final isar = await _databaseService.database;

      final vocabulary = await isar.vocabularyHighlights
          .where()
          .sortByCreatedAtDesc()
          .findAll();

      log.d('获取所有词汇成功: 共 ${vocabulary.length} 个');
      return vocabulary;
    } catch (e) {
      log.e('获取所有词汇失败: $e');
      return [];
    }
  }

  /// 搜索词汇
  Future<List<VocabularyHighlight>> searchVocabulary(String query) async {
    try {
      final isar = await _databaseService.database;

      final results = await isar.vocabularyHighlights
          .filter()
          .wordContains(query, caseSensitive: false)
          .or()
          .selectedTextContains(query, caseSensitive: false)
          .or()
          .translationIsNotNull()
          .and()
          .translationContains(query, caseSensitive: false)
          .sortByCreatedAtDesc()
          .findAll();

      log.d('搜索词汇成功: "$query", 共 ${results.length} 个结果');
      return results;
    } catch (e) {
      log.e('搜索词汇失败: $e');
      return [];
    }
  }

  /// 获取需要复习的词汇
  Future<List<VocabularyHighlight>> getVocabularyForReview(
      {int daysSinceLastReview = 7}) async {
    try {
      final isar = await _databaseService.database;
      final cutoffDate =
          DateTime.now().subtract(Duration(days: daysSinceLastReview));

      final vocabulary = await isar.vocabularyHighlights
          .filter()
          .lastReviewedAtIsNull()
          .or()
          .lastReviewedAtLessThan(cutoffDate)
          .sortByCreatedAt()
          .findAll();

      log.d('获取复习词汇成功: 共 ${vocabulary.length} 个');
      return vocabulary;
    } catch (e) {
      log.e('获取复习词汇失败: $e');
      return [];
    }
  }

  /// 标记词汇为已复习
  Future<void> markAsReviewed(Id highlightId) async {
    try {
      final isar = await _databaseService.database;

      await isar.writeTxn(() async {
        final highlight = await isar.vocabularyHighlights.get(highlightId);
        if (highlight == null) {
          throw Exception('高亮不存在');
        }

        highlight.markAsReviewed();
        await isar.vocabularyHighlights.put(highlight);
      });

      log.i('标记复习成功: ID $highlightId');
    } catch (e) {
      log.e('标记复习失败: $e');
      rethrow;
    }
  }

  /// 获取统计信息
  Future<Map<String, int>> getStatistics() async {
    try {
      final isar = await _databaseService.database;

      final totalCount = await isar.vocabularyHighlights.count();
      final needReviewCount = await isar.vocabularyHighlights
          .filter()
          .lastReviewedAtIsNull()
          .or()
          .lastReviewedAtLessThan(DateTime.now().subtract(Duration(days: 7)))
          .count();

      return {
        'total': totalCount,
        'needReview': needReviewCount,
        'reviewed': totalCount - needReviewCount,
      };
    } catch (e) {
      log.e('获取统计信息失败: $e');
      return {'total': 0, 'needReview': 0, 'reviewed': 0};
    }
  }
}
