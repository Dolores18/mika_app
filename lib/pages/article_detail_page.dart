import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/article_service.dart';
import '../widgets/audio_player.dart';
import '../widgets/key_points_list.dart';
import '../widgets/vocabulary_list.dart';
import 'word_lookup_page.dart';

class ArticleDetailPage extends StatefulWidget {
  final String articleId;

  const ArticleDetailPage({super.key, required this.articleId});

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  final ArticleService _articleService = ArticleService();
  Article? _article;
  bool _isLoading = true;
  double _fontSize = 16.0;
  bool _isDarkMode = false;
  String? _error;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadArticle();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadArticle() async {
    try {
      final article = await _articleService.getArticleById(widget.articleId);
      setState(() {
        _article = article;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载文章失败，请稍后重试';
        _isLoading = false;
      });
    }
  }

  void _lookupWord(String word) {
    // 在实际应用中，这里可以跳转到查词页面或显示弹窗
    // 为了简单演示，我们直接打开查词页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WordLookupPage(wordToLookup: word),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          _isDarkMode ? const Color(0xFF121212) : const Color(0xFFFCE4EC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: _isDarkMode ? Colors.white : Colors.black87,
        ),
        actions: [
          // 收藏按钮
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () {
              // TODO: 实现收藏功能
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('收藏功能即将上线')));
            },
          ),
          // 分享按钮
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: 实现分享功能
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('分享功能即将上线')));
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : _article == null
              ? const Center(child: Text('文章不存在'))
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      _article!.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 章节和期号信息
                    Text(
                      '${_article!.sectionTitle} · ${_article!.issueTitle}',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    // 音频播放器
                    if (_article!.audioUrl != null)
                      AudioPlayer(url: _article!.audioUrl!),
                    const SizedBox(height: 16),
                    // 文章内容
                    Text(
                      _article!.analysis?.summary.short ?? '',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    // 关键要点
                    if (_article!.analysis?.summary.keyPoints != null)
                      KeyPointsList(
                        points: _article!.analysis!.summary.keyPoints,
                      ),
                    const SizedBox(height: 24),
                    // 词汇列表
                    if (_article!.analysis?.vocabulary != null)
                      VocabularyList(
                        vocabulary: _article!.analysis!.vocabulary,
                      ),
                    const SizedBox(height: 24),
                    // 难度信息
                    if (_article!.analysis?.difficulty != null)
                      _buildDifficultySection(),
                    const SizedBox(height: 24),
                    // 主题信息
                    if (_article!.analysis?.topics != null)
                      _buildTopicsSection(),
                  ],
                ),
              ),
      // 底部工具栏
      bottomNavigationBar:
          _isLoading
              ? null
              : Container(
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 字体大小调整
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.text_decrease,
                            color:
                                _isDarkMode ? Colors.white70 : Colors.grey[700],
                          ),
                          onPressed: () {
                            setState(() {
                              if (_fontSize > 12) {
                                _fontSize -= 1;
                              }
                            });
                          },
                        ),
                        Text(
                          '${_fontSize.toInt()}',
                          style: TextStyle(
                            color:
                                _isDarkMode ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.text_increase,
                            color:
                                _isDarkMode ? Colors.white70 : Colors.grey[700],
                          ),
                          onPressed: () {
                            setState(() {
                              if (_fontSize < 24) {
                                _fontSize += 1;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    // 黑暗模式切换
                    IconButton(
                      icon: Icon(
                        _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                        color: _isDarkMode ? Colors.white70 : Colors.grey[700],
                      ),
                      onPressed: () {
                        setState(() {
                          _isDarkMode = !_isDarkMode;
                        });
                      },
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildDifficultySection() {
    final difficulty = _article!.analysis!.difficulty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '难度等级',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(difficulty.level),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      difficulty.level,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(difficulty.description),
              const SizedBox(height: 8),
              const Text('特点：', style: TextStyle(fontWeight: FontWeight.bold)),
              ...difficulty.features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text('• $feature'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopicsSection() {
    final topics = _article!.analysis!.topics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '主题分类',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('主要主题：${topics.primary}'),
              if (topics.secondary.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('次要主题：'),
                ...topics.secondary.map(
                  (topic) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text('• $topic'),
                  ),
                ),
              ],
              if (topics.keywords.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('关键词：'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      topics.keywords
                          .map((keyword) => Chip(label: Text(keyword)))
                          .toList(),
                ),
              ],
            ],
          ),
        ),
      ],
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
}
