import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

class BookmarkService {
  static const String _bookmarkKey = 'bookmarked_articles';

  // 获取收藏列表
  Future<List<String>> getBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = prefs.getStringList(_bookmarkKey) ?? [];
      // 反转列表，确保最新收藏在最前面（兼容旧数据）
      final reversed = bookmarks.reversed.toList();
      log.d('从本地存储获取收藏列表: $reversed');
      return reversed;
    } catch (e) {
      log.e('获取收藏列表失败: $e');
      return [];
    }
  }

  // 添加收藏
  Future<void> addBookmark(String articleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = prefs.getStringList(_bookmarkKey) ?? [];

      // 避免重复添加
      if (!bookmarks.contains(articleId)) {
        bookmarks.add(articleId);
        await prefs.setStringList(_bookmarkKey, bookmarks);
        log.d('添加收藏成功: $articleId');
      } else {
        log.d('文章已在收藏列表中: $articleId');
      }
    } catch (e) {
      log.e('添加收藏失败: $e');
      throw Exception('添加收藏失败');
    }
  }

  // 移除收藏
  Future<void> removeBookmark(String articleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = prefs.getStringList(_bookmarkKey) ?? [];

      if (bookmarks.contains(articleId)) {
        bookmarks.remove(articleId);
        await prefs.setStringList(_bookmarkKey, bookmarks);
        log.d('移除收藏成功: $articleId');
      } else {
        log.d('文章不在收藏列表中: $articleId');
      }
    } catch (e) {
      log.e('移除收藏失败: $e');
      throw Exception('移除收藏失败');
    }
  }

  // 检查是否已收藏
  Future<bool> isBookmarked(String articleId) async {
    try {
      final bookmarks = await getBookmarks();
      return bookmarks.contains(articleId);
    } catch (e) {
      log.e('检查收藏状态失败: $e');
      return false;
    }
  }

  // 清空所有收藏
  Future<void> clearBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_bookmarkKey);
      log.d('清空所有收藏成功');
    } catch (e) {
      log.e('清空收藏失败: $e');
      throw Exception('清空收藏失败');
    }
  }

  // 获取收藏数量
  Future<int> getBookmarkCount() async {
    try {
      final bookmarks = await getBookmarks();
      return bookmarks.length;
    } catch (e) {
      log.e('获取收藏数量失败: $e');
      return 0;
    }
  }
}
