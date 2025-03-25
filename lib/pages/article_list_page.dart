import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/article_service.dart';
import 'article_detail_page.dart';

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
  List<Category> _categories = [];
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
    _loadCategories();
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

  Future<void> _loadCategories() async {
    try {
      final categories = await _articleService.getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      print('加载分类失败: $e');
    }
  }

  Future<void> _loadArticles() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      if (_selectedTopic != null) {
        final articles = await _articleService.getArticlesByTopic(
          _selectedTopic!,
        );
        final articleDetails = await Future.wait(
          articles.map(
            (article) =>
                _articleService.getArticleById(article['id'].toString()),
          ),
        );
        setState(() {
          _articles = articleDetails;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '加载文章失败，请稍后重试';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreArticles() async {
    if (_isLoading) return;

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
      setState(() {
        _error = '加载文章失败，请稍后重试';
        _isLoading = false;
      });
    }
  }

  void _filterArticles() {
    _loadArticles(); // 重新加载文章
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('经济学人文章'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadArticles),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                // 分类选择
                DropdownButton<String?>(
                  value: _selectedCategoryId,
                  isExpanded: true,
                  hint: const Text('选择分类'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('全部分类'),
                    ),
                    ..._categories.map((Category category) {
                      return DropdownMenuItem<String?>(
                        value: category.id,
                        child: Text('${category.name} (${category.count})'),
                      );
                    }).toList(),
                  ],
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCategoryId = newValue;
                      _filterArticles();
                    });
                  },
                ),
                const SizedBox(height: 8),
                // 难度选择
                DropdownButton<String?>(
                  value: _selectedDifficulty,
                  isExpanded: true,
                  hint: const Text('选择难度'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('全部难度'),
                    ),
                    ...ArticleDifficulty.values.map((
                      ArticleDifficulty difficulty,
                    ) {
                      return DropdownMenuItem<String?>(
                        value: difficulty.toString(),
                        child: Text(_getDifficultyText(difficulty)),
                      );
                    }).toList(),
                  ],
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedDifficulty = newValue;
                      _filterArticles();
                    });
                  },
                ),
              ],
            ),
          ),
          // 文章列表
          Expanded(
            child:
                _error != null
                    ? Center(child: Text(_error!))
                    : ListView.builder(
                      controller: _scrollController,
                      itemCount: _articles.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _articles.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        return _buildArticleCard(_articles[index]);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleCard(Article article) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              const SizedBox(height: 8),
              // 摘要
              if (article.analysis != null)
                Text(
                  article.analysis!.summary.short,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              // 文章信息
              Row(
                children: [
                  // 日期
                  Text(
                    article.issueDate,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 8),
                  // 阅读时间
                  if (article.analysis != null)
                    Text(
                      '${article.analysis!.readingTime} 分钟',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  const SizedBox(width: 8),
                  // 难度
                  if (article.analysis != null)
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
                        article.analysis!.difficulty.level,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
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
}
