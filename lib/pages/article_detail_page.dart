import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 添加这行以导入compute函数
import '../models/article.dart';
import '../services/article_service.dart';
import '../widgets/audio_player.dart';
import '../widgets/key_points_list.dart';
import '../widgets/vocabulary_list.dart';
import 'word_lookup_page.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../utils/logger.dart';

// 添加一个用于隔离计算的类 - 移到顶级
class _ProcessHtmlParams {
  final String html;
  final List<Vocabulary> vocabulary;
  final double fontSize;
  final bool isDarkMode;

  _ProcessHtmlParams({
    required this.html,
    required this.vocabulary,
    required this.fontSize,
    required this.isDarkMode,
  });
}

// 在隔离线程中处理HTML - 移到顶级
String _isolateProcessHtml(_ProcessHtmlParams params) {
  String contentWithHighlights = params.html;

  // 创建所有词汇的正则表达式模式
  final List<MapEntry<RegExp, Vocabulary>> patterns = [];
  for (var vocab in params.vocabulary) {
    final RegExp regExp = RegExp(
      r'\b' + RegExp.escape(vocab.word) + r'\b',
      caseSensitive: false,
      multiLine: true,
    );
    patterns.add(MapEntry(regExp, vocab));
  }

  // 分批处理词汇
  const int batchSize = 10; // 每批处理的词汇数量
  for (int i = 0; i < patterns.length; i += batchSize) {
    final int end =
        (i + batchSize < patterns.length) ? i + batchSize : patterns.length;
    final currentBatch = patterns.sublist(i, end);

    for (var entry in currentBatch) {
      final regExp = entry.key;
      final vocab = entry.value;

      // 编码词汇数据以便JavaScript处理
      String vocabData =
          '${vocab.word}|${vocab.translation}|${vocab.context}|${vocab.example}';

      contentWithHighlights = contentWithHighlights.replaceAllMapped(
        regExp,
        (match) =>
            '<span class="highlight-word" '
            'onclick="VocabularyHandler.postMessage(\'$vocabData\')">'
            '${match.group(0)}</span>',
      );
    }
  }

  // 格式化HTML
  return contentWithHighlights;
}

class ArticleDetailPage extends StatefulWidget {
  final String articleId;

  const ArticleDetailPage({super.key, required this.articleId});

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  final ArticleService _articleService = ArticleService();
  late Future<Article> _articleFuture;
  String? _htmlContent;
  bool _isLoadingContent = false;
  String? _contentError;
  double _fontSize = 16.0;
  bool _isDarkMode = false;

  // 添加HTML缓存机制
  final Map<String, String> _htmlCache = {};

  // 添加滚动控制器
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _articleFuture = _articleService.getArticleById(widget.articleId);
    _loadMarkdownContent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // 清除缓存，避免内存泄漏
    _htmlCache.clear();
    super.dispose();
  }

  // 优化 _loadHtmlContent 方法，改为加载Markdown内容
  Future<void> _loadMarkdownContent() async {
    setState(() {
      _isLoadingContent = true;
      _contentError = null;
    });

    try {
      // 获取Markdown内容
      final markdown = await _articleService.getArticleMarkdownContent(
        widget.articleId,
      );

      // 设置Markdown内容
      _htmlContent = markdown;

      setState(() {
        _isLoadingContent = false;
      });
    } catch (e) {
      log.e('获取文章内容失败', e);
      setState(() {
        _contentError = '获取文章内容失败: $e';
        _isLoadingContent = false;
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

  // 显示单词悬浮卡片
  void _showWordPopup({
    required String word,
    required String translation,
    required String context,
    required String example,
  }) {
    showDialog(
      context: this.context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        word,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Divider(),
                  Text(
                    translation,
                    style: TextStyle(fontSize: 18, color: Colors.blue[800]),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "上下文: $context",
                    style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                  SizedBox(height: 8),
                  Text("例句: $example", style: TextStyle(fontSize: 14)),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: Text("添加到生词本"),
                        onPressed: () {
                          // 添加生词本功能
                          Navigator.pop(context);
                        },
                      ),
                      TextButton(
                        child: Text("关闭"),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Article>(
      future: _articleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('文章详情')),
            body: Center(child: Text('加载失败: ${snapshot.error}')),
          );
        } else if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('文章详情')),
            body: const Center(child: Text('找不到文章')),
          );
        }

        final article = snapshot.data!;

        // 添加调试信息
        log.i('加载文章详情: ID=${article.id}, 标题=${article.title}');
        _debugArticleAnalysis(article);

        return Scaffold(
          backgroundColor: _isDarkMode ? const Color(0xFF121212) : Colors.white,
          appBar: AppBar(
            backgroundColor:
                _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(
              color: _isDarkMode ? Colors.white : Colors.black87,
            ),
            title: const Text(''),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadMarkdownContent,
              ),
              IconButton(
                icon: const Icon(Icons.bookmark_border),
                onPressed: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('收藏功能即将上线')));
                },
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('分享功能即将上线')));
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // 文章内容区域
              Expanded(
                child:
                    _isLoadingContent
                        ? const Center(child: CircularProgressIndicator())
                        : _contentError != null
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _contentError!,
                                style: TextStyle(
                                  color:
                                      _isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadMarkdownContent,
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        )
                        : _htmlContent != null
                        ? _buildMarkdownView(_htmlContent!, article)
                        : const Center(child: Text('没有内容可显示')),
              ),
            ],
          ),
          // 底部工具栏
          bottomNavigationBar:
              _isLoadingContent
                  ? null
                  : Container(
                    decoration: BoxDecoration(
                      color:
                          _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
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
                                    _isDarkMode
                                        ? Colors.white70
                                        : Colors.grey[700],
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_fontSize > 12) {
                                    _fontSize -= 1;
                                    // 清除所有缓存，因为字体大小变化了
                                    _htmlCache.clear();
                                  }
                                });
                              },
                            ),
                            Text(
                              '${_fontSize.toInt()}',
                              style: TextStyle(
                                color:
                                    _isDarkMode
                                        ? Colors.white70
                                        : Colors.grey[700],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.text_increase,
                                color:
                                    _isDarkMode
                                        ? Colors.white70
                                        : Colors.grey[700],
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_fontSize < 24) {
                                    _fontSize += 1;
                                    // 清除所有缓存，因为字体大小变化了
                                    _htmlCache.clear();
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
                            color:
                                _isDarkMode ? Colors.white70 : Colors.grey[700],
                          ),
                          onPressed: () {
                            setState(() {
                              _isDarkMode = !_isDarkMode;
                              // 清除所有缓存，因为主题变化了
                              _htmlCache.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
        );
      },
    );
  }

  // 修改 _buildMarkdownView 方法，使用Markdown控件代替WebView
  Widget _buildMarkdownView(String markdownContent, Article article) {
    // 高亮词汇表
    final List<Vocabulary> vocabularyList = article.analysis?.vocabulary ?? [];

    // 处理Markdown内容，移除第一个一级标题
    String processedContent = markdownContent;
    final RegExp firstTitleRegex = RegExp(r'^\s*#\s+.*$', multiLine: true);
    final Match? firstTitleMatch = firstTitleRegex.firstMatch(processedContent);

    if (firstTitleMatch != null) {
      // 只移除第一个匹配的一级标题
      processedContent = processedContent.replaceFirst(
        firstTitleMatch.group(0)!,
        '',
      );
      log.i('已移除第一个一级标题: ${firstTitleMatch.group(0)}');
    }

    // 替换图片路径，将static_images/xxx.jpg替换为API URL
    final String issueDate = article.issueDate;
    final RegExp imgRegex = RegExp(r'!\[(.*?)\]\(static_images/(.*?)\)');

    // 使用ArticleService的公共方法获取基础URL
    final String baseUrl = ArticleService.getBaseUrl();

    processedContent = processedContent.replaceAllMapped(imgRegex, (match) {
      final String altText = match.group(1) ?? '';
      final String fileName = match.group(2)!;
      final String newImgUrl =
          '$baseUrl/articles/image/file/$fileName?issue_date=$issueDate';
      log.i('图片路径替换: static_images/$fileName -> $newImgUrl');
      return '![$altText]($newImgUrl)';
    });

    // 创建Markdown控件
    return Markdown(
      controller: _scrollController,
      data: processedContent,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        h1: TextStyle(
          fontSize: _fontSize * 1.5,
          fontWeight: FontWeight.bold,
          color: _isDarkMode ? Colors.white : Colors.black87,
        ),
        h2: TextStyle(
          fontSize: _fontSize * 1.3,
          fontWeight: FontWeight.bold,
          color: _isDarkMode ? Colors.white : Colors.black87,
        ),
        h3: TextStyle(
          fontSize: _fontSize * 1.1,
          fontWeight: FontWeight.bold,
          color: _isDarkMode ? Colors.white : Colors.black87,
        ),
        p: TextStyle(
          fontSize: _fontSize,
          color: _isDarkMode ? Colors.white70 : Colors.black87,
          height: 1.6,
        ),
        blockquote: TextStyle(
          fontSize: _fontSize,
          color: _isDarkMode ? Colors.grey[400] : Colors.grey[700],
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: _isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              width: 4.0,
            ),
          ),
        ),
        code: TextStyle(
          fontSize: _fontSize * 0.9,
          color: _isDarkMode ? Colors.grey[300] : Colors.black87,
          backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.grey[200],
        ),
        codeblockDecoration: BoxDecoration(
          color: _isDarkMode ? Colors.grey[800] : Colors.grey[200],
          borderRadius: BorderRadius.circular(4.0),
        ),
        listBullet: TextStyle(
          fontSize: _fontSize,
          color: _isDarkMode ? Colors.white70 : Colors.black87,
        ),
      ),
      onTapLink: (text, href, title) {
        // 处理链接点击
        if (href != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('链接: $href')));
        }
      },
      padding: const EdgeInsets.all(16.0),
      physics: const AlwaysScrollableScrollPhysics(),
      imageBuilder: (uri, title, alt) {
        // 自定义图片构建
        return Image.network(
          uri.toString(),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.grey[300],
              child: Text(
                '图片加载失败: ${uri.toString()}',
                style: TextStyle(fontSize: _fontSize * 0.8),
              ),
            );
          },
        );
      },
    );
  }

  // 检查文章分析中的关键词和摘要部分，确保不会出现乱码
  void _debugArticleAnalysis(Article article) {
    if (article.analysis != null) {
      log.d('调试文章分析数据:');
      log.d('  - 主题: ${article.analysis!.topics.primary}');
      log.d('  - 关键词: ${article.analysis!.topics.keywords.join(', ')}');
      log.d('  - 摘要: ${article.analysis!.summary.short}');

      // 输出词汇信息以便调试
      if (article.analysis!.vocabulary.isNotEmpty) {
        log.d('  - 词汇数量: ${article.analysis!.vocabulary.length}');
        log.d(
          '  - 第一个词汇: ${article.analysis!.vocabulary[0].word} - ${article.analysis!.vocabulary[0].translation}',
        );
      }
    } else {
      log.w('文章没有分析数据');
    }
  }

  Widget _buildDifficultySection(Article article) {
    final difficulty = article.analysis!.difficulty;
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

  Widget _buildTopicsSection(Article article) {
    final topics = article.analysis!.topics;
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
    // 标准化级别字符串（移除空格，转为大写）
    final normalizedLevel = level.trim().toUpperCase();

    // 处理各种可能的格式
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

  String _getDifficultyLevelText(String level) {
    // 标准化级别字符串（移除空格，转为大写）
    final normalizedLevel = level.trim().toUpperCase();

    // 处理各种可能的格式
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
      // 默认返回原始级别
      return level;
    }
  }
}
