import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/history_service.dart';
import 'article_detail_page.dart';
import '../utils/logger.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final HistoryService _historyService = HistoryService();
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _historyService.getHistory();
  }

  void _clearHistory() {
    Get.dialog(
      AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有学习记录吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await _historyService.clearHistory();
              setState(() {
                _historyFuture = _historyService.getHistory();
              });
              Get.back();
            },
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('学习记录'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearHistory,
            tooltip: '清空记录',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }

          final history = snapshot.data;

          if (history == null || history.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              return _buildHistoryItem(context, item);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final String? sectionTitle = item['sectionTitle'];
    final String issueDate = item['issueDate'] ?? '未知日期';

    String subtitleText = issueDate;
    if (sectionTitle != null && sectionTitle.isNotEmpty) {
      subtitleText = '$sectionTitle - $issueDate';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(Icons.article_outlined, color: theme.colorScheme.secondary),
        title: Text(item['title'] ?? '未知标题'),
        subtitle: Text(subtitleText),
        onTap: () {
          final articleId = item['id'];
          if (articleId != null) {
            log.i('从历史记录点击文章: $articleId');
            Get.to(() => ArticleDetailPage(articleId: articleId.toString()));
          }
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off,
            size: 80,
            color: theme.textTheme.bodyLarge?.color?.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有学习记录',
            style: TextStyle(
              fontSize: 18,
              color: theme.textTheme.bodyLarge?.color?.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '快去阅读一篇文章吧！',
            style: TextStyle(
              fontSize: 14,
              color: theme.textTheme.bodyLarge?.color?.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
