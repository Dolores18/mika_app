import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/bookmark_controller.dart';
import '../models/article.dart';
import 'article_detail_page.dart';
import '../utils/logger.dart';

class BookmarkPage extends StatelessWidget {
  BookmarkPage({super.key});

  final BookmarkController bookmarkController = Get.find<BookmarkController>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '我的收藏',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: theme.appBarTheme.iconTheme,
        actions: [
          Obx(() {
            // 只有当有收藏时才显示按钮
            if (bookmarkController.bookmarkCount > 0) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 刷新按钮
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () =>
                        bookmarkController.refreshBookmarkedArticles(),
                    tooltip: '刷新',
                  ),
                  // 清空按钮
                  IconButton(
                    icon: const Icon(Icons.clear_all),
                    onPressed: () => _showClearDialog(),
                    tooltip: '清空收藏',
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
      body: Obx(() {
        final bookmarkedIds = bookmarkController.bookmarkedIds;
        final bookmarkedArticles = bookmarkController.bookmarkedArticles;
        final isLoading = bookmarkController.isLoadingArticles;

        if (bookmarkedIds.isEmpty) {
          return _buildEmptyState();
        }

        if (isLoading) {
          return _buildLoadingState();
        }

        return _buildBookmarkList(bookmarkedArticles);
      }),
    );
  }

  // 空状态界面
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '还没有收藏任何文章',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '去发现一些有趣的文章吧！',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // 跳转到学习页面（底部导航的第二个tab）
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6b4bbd),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('去学习'),
          ),
        ],
      ),
    );
  }

  // 加载状态界面
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF6b4bbd),
          ),
          SizedBox(height: 16),
          Text(
            '正在加载收藏文章...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // 收藏列表
  Widget _buildBookmarkList(List<Article> bookmarkedArticles) {
    return Column(
      children: [
        // 收藏统计信息
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.bookmark,
                color: const Color(0xFF6b4bbd),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                '共收藏 ${bookmarkedArticles.length} 篇文章',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),

        // 收藏文章列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: bookmarkedArticles.length,
            itemBuilder: (context, index) {
              final article = bookmarkedArticles[index];
              return _buildBookmarkItem(article, index);
            },
          ),
        ),
      ],
    );
  }

  // 收藏项目
  Widget _buildBookmarkItem(Article article, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          log.i('点击收藏文章: ${article.id}');
          // 跳转到文章详情页
          Get.to(() => ArticleDetailPage(articleId: article.id.toString()));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧图标
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF6b4bbd).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.article,
                  color: Color(0xFF6b4bbd),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // 中间内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 文章标题
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // 文章摘要
                    if (article.analysis?.summary.short != null)
                      Text(
                        article.analysis!.summary.short,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),

                    // 文章信息标签
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        // 来源
                        if (article.sectionTitle != null)
                          _buildInfoChip(
                            article.sectionTitle!,
                            const Color(0xFF6b4bbd),
                            Icons.book,
                          ),

                        // 难度
                        if (article.analysis?.difficulty.level != null)
                          _buildInfoChip(
                            article.analysis!.difficulty.level,
                            _getDifficultyColor(
                                article.analysis!.difficulty.level),
                            Icons.trending_up,
                          ),

                        // 阅读时间
                        if (article.analysis?.readingTime != null)
                          _buildInfoChip(
                            '${article.analysis!.readingTime}分钟',
                            Colors.orange,
                            Icons.access_time,
                          ),

                        // 发布日期
                        if (article.issueDate != null)
                          _buildInfoChip(
                            article.issueDate!,
                            Colors.grey[600]!,
                            Icons.calendar_today,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // 右侧菜单
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'remove') {
                    _confirmRemoveBookmark(article.id.toString());
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.bookmark_remove, color: Colors.red),
                        SizedBox(width: 8),
                        Text('取消收藏'),
                      ],
                    ),
                  ),
                ],
                child: Icon(
                  Icons.more_vert,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建信息标签
  Widget _buildInfoChip(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 获取难度颜色
  Color _getDifficultyColor(String level) {
    switch (level) {
      case 'A1-A2':
        return Colors.green;
      case 'B1-B2':
        return Colors.orange;
      case 'C1-C2':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // 确认移除收藏对话框
  void _confirmRemoveBookmark(String articleId) {
    Get.dialog(
      AlertDialog(
        title: const Text('取消收藏'),
        content: const Text('确定要从收藏中移除这篇文章吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              bookmarkController.toggleBookmark(articleId);
              Get.back();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 显示清空收藏对话框
  void _showClearDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('清空收藏'),
        content:
            Text('确定要清空所有收藏吗？这将移除 ${bookmarkController.bookmarkCount} 篇收藏文章。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              bookmarkController.clearAllBookmarks();
              Get.back();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}
  
