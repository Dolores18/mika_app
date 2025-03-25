import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/article_service.dart';
import 'article_detail_page.dart';
import '../utils/logger.dart';

class ArticleListPage extends StatefulWidget {
  final String? initialTopic;

  const ArticleListPage({super.key, this.initialTopic});

  @override
  State<ArticleListPage> createState() => _ArticleListPageState();
}

class _ArticleListPageState extends State<ArticleListPage> {
  final ArticleService _articleService = ArticleService();
  final ScrollController _scrollController = ScrollController();

  List<Article> _articles = [];

  String? _selectedCategoryId;
  String? _selectedDifficulty;
  String? _selectedTopic;

  bool _isLoading = true;
  bool _hasMore = true;
  String? _error;
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    _selectedTopic = widget.initialTopic;
    _loadArticles();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadMoreArticles();
      }
    }
  }

  Future<void> _loadArticles() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      if (_selectedTopic != null) {
        final articlesList = await _articleService.getArticlesByTopic(
          _selectedTopic!,
        );

        // 将简单的文章数据转换为Article对象
        final List<Article> articles =
            articlesList.map((articleData) {
              // 确保从API返回的标题等文本正确解码
              final String safeTitle =
                  articleData['title'] is String
                      ? articleData['title'] as String
                      : '未知标题';

              final String safeSection =
                  articleData['section'] is String
                      ? articleData['section'] as String
                      : '未知栏目';

              final String safeDate =
                  articleData['issue_date'] is String
                      ? articleData['issue_date'] as String
                      : '未知日期';

              log.d('准备解析文章标题: $safeTitle');

              return Article(
                id: articleData['id'] as int,
                title: safeTitle,
                sectionId: 0,
                sectionTitle: safeSection,
                issueId: 0,
                issueDate: safeDate,
                issueTitle: '',
                order: 0,
                path: articleData['path'] as String? ?? '',
                hasImages: false,
                audioUrl: null,
                // 创建一个基本的analysis对象，用于显示
                analysis: ArticleAnalysis(
                  id: 0,
                  articleId: articleData['id'] as int,
                  readingTime: articleData['reading_time'] as int? ?? 8,
                  difficulty: Difficulty(
                    level: 'B2-C1',
                    description: '中高级',
                    features: ['经济学人文章'],
                  ),
                  topics: Topics(
                    primary: _selectedTopic!,
                    secondary: [],
                    keywords: _selectedTopic!.isEmpty ? [] : [_selectedTopic!],
                  ),
                  summary: Summary(short: '', keyPoints: []),
                  vocabulary: [],
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );
            }).toList();

        setState(() {
          _articles = articles;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = '请选择一个主题';
          _isLoading = false;
        });
      }
    } catch (e) {
      log.e('加载文章列表时出错: $e');
      setState(() {
        _error = '加载文章列表时出错: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreArticles() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _articleService.getArticleIds(
        page: _currentPage,
        pageSize: _pageSize,
        categoryId: _selectedCategoryId,
        difficulty: _selectedDifficulty,
      );

      if (response.ids.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      final articles = await _articleService.getArticlesByIds(response.ids);

      setState(() {
        _articles.addAll(articles);
        _currentPage++;
        _hasMore = response.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      log.e('加载更多文章失败: $e');
      setState(() {
        _hasMore = false; // 停止尝试加载更多
        _isLoading = false;
        // 不设置_error，只显示已加载的文章，并停止尝试加载更多
      });
      // 显示一个短暂的提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加载更多文章失败: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _filterArticles() {
    _loadArticles(); // 重新加载文章
  }

  @override
  Widget build(BuildContext context) {
    // 根据topic获取对应的中文名称
    String pageTitle = '文章列表';
    if (_selectedTopic != null) {
      // 尝试将ID映射为中文名称
      final Map<String, String> topicIdToName = {
        '1': '政治',
        '2': '经济',
        '3': '科技',
        '4': '文化',
        '5': '其他',
      };
      pageTitle = topicIdToName[_selectedTopic] ?? _selectedTopic!;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadArticles),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : _articles.isEmpty
              ? const Center(child: Text('没有找到相关文章'))
              : ListView.builder(
                controller: _scrollController,
                itemCount: _articles.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _articles.length) {
                    return _isLoading
                        ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                        : const SizedBox.shrink();
                  }
                  return _buildArticleCard(_articles[index]);
                },
              ),
    );
  }

  Widget _buildArticleCard(Article article) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      ArticleDetailPage(articleId: article.id.toString()),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Text(
                article.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // 文章信息
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 左侧信息（栏目和日期）
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            article.sectionTitle,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.blueGrey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            article.issueDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 右侧信息（阅读时间和难度）
                  Row(
                    children: [
                      // 阅读时间
                      if (article.analysis != null &&
                          article.analysis!.readingTime > 0)
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${article.analysis!.readingTime} 分钟',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      // 难度
                      if (article.analysis != null &&
                          article.analysis!.difficulty.level.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(
                              article.analysis!.difficulty.level,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            // 使用难度级别中文描述
                            _getDifficultyLevelText(
                              article.analysis!.difficulty.level,
                            ),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getDifficultyColor(String level) {
    // 标准化级别字符串
    final normalizedLevel = level.trim().toUpperCase();

    if (normalizedLevel.contains('A1') ||
        normalizedLevel.contains('A2') ||
        normalizedLevel == 'A' ||
        normalizedLevel == 'A1-A2') {
      return Colors.green; // 初级 - 绿色
    } else if (normalizedLevel.contains('B1') ||
        normalizedLevel.contains('B2') ||
        normalizedLevel == 'B' ||
        normalizedLevel == 'B1-B2') {
      return Colors.orange; // 中级 - 橙色
    } else if (normalizedLevel.contains('C1') ||
        normalizedLevel.contains('C2') ||
        normalizedLevel == 'C' ||
        normalizedLevel == 'C1-C2') {
      return Colors.red; // 高级 - 红色
    } else {
      return Colors.grey; // 未知 - 灰色
    }
  }

  String _getDifficultyText(ArticleDifficulty difficulty) {
    switch (difficulty) {
      case ArticleDifficulty.easy:
        return '初级';
      case ArticleDifficulty.medium:
        return '中级';
      case ArticleDifficulty.hard:
        return '高级';
    }
  }

  String _getDifficultyLevelText(String level) {
    // 标准化级别字符串
    final normalizedLevel = level.trim().toUpperCase();

    if (normalizedLevel.contains('A1') ||
        normalizedLevel.contains('A2') ||
        normalizedLevel == 'A' ||
        normalizedLevel == 'A1-A2') {
      return '初级';
    } else if (normalizedLevel.contains('B1') ||
        normalizedLevel.contains('B2') ||
        normalizedLevel == 'B' ||
        normalizedLevel == 'B1-B2') {
      return '中级';
    } else if (normalizedLevel.contains('C1') ||
        normalizedLevel.contains('C2') ||
        normalizedLevel == 'C' ||
        normalizedLevel == 'C1-C2') {
      return '高级';
    } else {
      return '未知';
    }
  }
}
