import 'package:get/get.dart';
import '../services/bookmark_service.dart';
import '../services/article_service.dart';
import '../models/article.dart';
import '../utils/logger.dart';

class BookmarkController extends GetxController {
  final BookmarkService _bookmarkService = BookmarkService();
  final ArticleService _articleService = ArticleService();

  // 收藏的文章ID列表
  final RxList<String> _bookmarkedIds = <String>[].obs;

  // 收藏的文章详情列表
  final RxList<Article> _bookmarkedArticles = <Article>[].obs;

  // 加载状态
  final RxBool _isLoadingArticles = false.obs;

  // Getter - 获取收藏ID列表
  List<String> get bookmarkedIds => _bookmarkedIds;

  // Getter - 获取收藏文章详情列表
  List<Article> get bookmarkedArticles => _bookmarkedArticles;

  // Getter - 获取加载状态
  bool get isLoadingArticles => _isLoadingArticles.value;

  // 检查文章是否已收藏
  bool isBookmarked(String articleId) {
    return _bookmarkedIds.contains(articleId);
  }

  @override
  void onInit() {
    super.onInit();
    _loadBookmarks();
  }

  // 加载收藏列表
  Future<void> _loadBookmarks() async {
    try {
      final bookmarks = await _bookmarkService.getBookmarks();
      _bookmarkedIds.assignAll(bookmarks);
      log.i('收藏列表加载成功，共 ${bookmarks.length} 篇文章');

      // 如果有收藏的文章，立即加载详情
      if (bookmarks.isNotEmpty) {
        await loadBookmarkedArticlesDetails();
      }
    } catch (e) {
      log.e('加载收藏列表失败: $e');
    }
  }

  // 加载收藏文章的详情
  Future<void> loadBookmarkedArticlesDetails() async {
    if (_bookmarkedIds.isEmpty) {
      _bookmarkedArticles.clear();
      return;
    }

    try {
      _isLoadingArticles.value = true;
      log.i('开始加载收藏文章详情，ID列表: $_bookmarkedIds');

      // 利用 ArticleService 的缓存机制批量获取文章详情
      final articles = await _articleService.getArticlesByIds(_bookmarkedIds);
      _bookmarkedArticles.assignAll(articles);

      log.i('收藏文章详情加载成功，共 ${articles.length} 篇文章');
      log.d('文章标题: ${articles.map((a) => a.title).join(', ')}');
    } catch (e) {
      log.e('加载收藏文章详情失败: $e');
      Get.snackbar(
        '加载失败',
        '获取文章详情失败，请检查网络连接',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    } finally {
      _isLoadingArticles.value = false;
    }
  }

  // 切换收藏状态
  Future<void> toggleBookmark(String articleId) async {
    try {
      if (isBookmarked(articleId)) {
        // 取消收藏
        await _bookmarkService.removeBookmark(articleId);
        _bookmarkedIds.remove(articleId);
        // 同时从文章详情列表中移除
        _bookmarkedArticles.removeWhere(
          (article) => article.id.toString() == articleId,
        );
        Get.snackbar(
          '取消收藏',
          '已从收藏中移除',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
        log.i('取消收藏文章: $articleId');
      } else {
        // 添加收藏
        await _bookmarkService.addBookmark(articleId);
        _bookmarkedIds.add(articleId);

        // 尝试将文章添加到详情列表（如果缓存中有的话）
        try {
          final article = await _articleService.getArticleById(articleId);
          _bookmarkedArticles.add(article);
        } catch (e) {
          log.w('添加收藏时获取文章详情失败: $e，将在下次访问收藏页面时重新加载');
        }

        Get.snackbar(
          '收藏成功',
          '已添加到收藏',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
        log.i('收藏文章: $articleId');
      }
    } catch (e) {
      log.e('切换收藏状态失败: $e');
      Get.snackbar(
        '操作失败',
        '请稍后重试',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }

  // 获取收藏数量
  int get bookmarkCount => _bookmarkedIds.length;

  // 清空所有收藏
  Future<void> clearAllBookmarks() async {
    try {
      await _bookmarkService.clearBookmarks();
      _bookmarkedIds.clear();
      _bookmarkedArticles.clear(); // 同时清空文章详情列表
      Get.snackbar(
        '清空完成',
        '已清空所有收藏',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      log.i('清空所有收藏');
    } catch (e) {
      log.e('清空收藏失败: $e');
      Get.snackbar(
        '操作失败',
        '请稍后重试',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }

  // 手动刷新收藏文章详情
  Future<void> refreshBookmarkedArticles() async {
    await loadBookmarkedArticlesDetails();
  }
}
