import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/article_service.dart';
import '../widgets/audio_player.dart';
import '../widgets/key_points_list.dart';
import '../widgets/vocabulary_list.dart';
import 'word_lookup_page.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/logger.dart';

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

  // 用于控制摘要和标签显示的状态
  bool _showHeader = true;
  double _scrollOffset = 0;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _articleFuture = _articleService.getArticleById(widget.articleId);
    _loadHtmlContent();

    // 添加滚动监听
    _scrollController.addListener(_onScroll);
  }

  // 滚动监听回调
  void _onScroll() {
    // 获取当前滚动位置
    final double offset = _scrollController.offset;

    // 向下滚动超过50像素时隐藏头部
    if (offset > 50 && _showHeader && offset > _scrollOffset) {
      setState(() {
        _showHeader = false;
      });
    }
    // 向上滚动时显示头部
    else if ((offset < 50 || offset < _scrollOffset) && !_showHeader) {
      setState(() {
        _showHeader = true;
      });
    }

    // 更新上次滚动位置
    _scrollOffset = offset;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // 清除缓存，避免内存泄漏
    _htmlCache.clear();
    super.dispose();
  }

  // 优化 _loadHtmlContent 方法，提高加载效率
  Future<void> _loadHtmlContent() async {
    setState(() {
      _isLoadingContent = true;
      _contentError = null;
    });

    try {
      // 优化1: 使用超时保护
      final html = await _articleService
          .getArticleHtmlContent(widget.articleId)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('加载文章内容超时'),
          );

      setState(() {
        _htmlContent = html;
        _isLoadingContent = false;
      });
    } catch (e) {
      log.e('加载文章内容失败', e);
      setState(() {
        _contentError = '加载文章内容失败: $e';
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
            title: Text(
              article.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadHtmlContent,
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
              // 文章头部信息
              if (_showHeader)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color:
                      _isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[50],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题
                      Text(
                        article.title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 来源和日期
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6b4bbd).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              article.sectionTitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6b4bbd),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            article.issueDate,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  _isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),

                      // 文章信息
                      if (article.analysis != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              // 阅读时间
                              Row(
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 14,
                                    color:
                                        _isDarkMode
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${article.analysis!.readingTime} 分钟',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          _isDarkMode
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),

                              // 难度
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
                                  // 转换难度级别为中文描述
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
                        ),

                      // 摘要
                      if (article.analysis != null &&
                          article.analysis!.summary.short.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  _isDarkMode
                                      ? Colors.grey[850]
                                      : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    _isDarkMode
                                        ? Colors.grey[700]!
                                        : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '摘要',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        _isDarkMode
                                            ? Colors.grey[300]
                                            : Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  article.analysis!.summary.short,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color:
                                        _isDarkMode
                                            ? Colors.grey[300]
                                            : Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              // 主题关键词
              if (_showHeader &&
                  article.analysis != null &&
                  article.analysis!.topics.keywords.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        article.analysis!.topics.keywords.map((keyword) {
                          return Chip(
                            label: Text(
                              keyword,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    _isDarkMode
                                        ? Colors.white70
                                        : Colors.grey[800],
                              ),
                            ),
                            backgroundColor:
                                _isDarkMode
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                  ),
                ),

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
                                onPressed: _loadHtmlContent,
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        )
                        : _htmlContent != null
                        ? _buildWebView(_htmlContent!, article)
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

  // 修改 _buildWebView 方法，优化WebView加载过程
  Widget _buildWebView(String html, Article article) {
    // 创建WebView控制器
    final controller = WebViewController();

    // 优化1: 在加载前设置基本配置，减少首次渲染时间
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(
        _isDarkMode ? const Color(0xFF121212) : Colors.white,
      );

    // 优化2: 使用FutureBuilder延迟处理HTML内容，避免主线程阻塞
    return FutureBuilder<String>(
      // 使用Future.microtask让UI先渲染，然后再异步处理HTML
      future: Future.microtask(() => _processHtmlForVocabulary(html, article)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在处理文章内容...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('处理文章内容出错: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('没有内容可显示'));
        }

        // 优化3: 仅在数据准备好时设置导航和JS通道
        controller
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (String url) {
                log.d('WebView页面加载完成');
                // 注入监听滚动的JavaScript代码
                controller.runJavaScript('''
                  document.addEventListener('scroll', function() {
                    var scrollY = window.scrollY;
                    if (scrollY > 50) {
                      Scrolling.postMessage('hide');
                    } else if (scrollY < 10) {
                      Scrolling.postMessage('show');
                    }
                  });
                ''');
              },
              // 优化4: 添加进度监控
              onProgress: (int progress) {
                log.d('WebView加载进度: $progress%');
              },
            ),
          )
          ..addJavaScriptChannel(
            'Scrolling',
            onMessageReceived: (JavaScriptMessage message) {
              if (message.message == 'hide' && _showHeader) {
                setState(() {
                  _showHeader = false;
                });
              } else if (message.message == 'show' && !_showHeader) {
                setState(() {
                  _showHeader = true;
                });
              }
            },
          )
          // 添加词汇点击处理
          ..addJavaScriptChannel(
            'VocabularyHandler',
            onMessageReceived: (JavaScriptMessage message) {
              // 解析词汇数据
              try {
                log.d('接收到词汇点击: ${message.message}');
                List<String> parts = message.message.split('|');
                if (parts.length >= 4) {
                  _showWordPopup(
                    word: parts[0],
                    translation: parts[1],
                    context: parts[2],
                    example: parts[3],
                  );
                }
              } catch (e) {
                log.e('处理词汇点击出错', e);
              }
            },
          )
          // 优化5: 最后才加载HTML内容
          ..loadHtmlString(snapshot.data!);

        // 返回WebView组件
        return WebViewWidget(controller: controller);
      },
    );
  }

  // 修改 _processHtmlForVocabulary 方法，使用更高效的处理方式
  String _processHtmlForVocabulary(String html, Article article) {
    if (article.analysis == null || article.analysis!.vocabulary.isEmpty) {
      return _getFormattedHtml(html);
    }

    // 优化1: 检查缓存，避免重复处理
    final String cacheKey = '${article.id}_${_fontSize}_${_isDarkMode}';
    if (_htmlCache.containsKey(cacheKey)) {
      log.d('使用缓存的HTML内容');
      return _htmlCache[cacheKey]!;
    }

    log.d('开始处理词汇高亮，词汇数量: ${article.analysis!.vocabulary.length}');
    final Stopwatch stopwatch = Stopwatch()..start();

    // 优化2: 使用更高效的单次处理方法
    // 创建所有词汇的正则表达式模式
    final List<MapEntry<RegExp, Vocabulary>> patterns = [];
    for (var vocab in article.analysis!.vocabulary) {
      // 使用单词边界确保匹配完整单词
      final RegExp regExp = RegExp(
        r'\b' + RegExp.escape(vocab.word) + r'\b',
        caseSensitive: false,
        multiLine: true,
      );
      patterns.add(MapEntry(regExp, vocab));
    }

    // 优化3: 使用一个简单的处理方式
    // 这里使用分块处理的方法来避免处理巨大的HTML字符串
    String contentWithHighlights = html;

    // 分批处理词汇，每批处理部分词汇，避免一次性处理太多
    const int batchSize = 5; // 每批处理的词汇数量
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

    // 优化4: 使用格式化的HTML包装内容并缓存结果
    final result = _getFormattedHtml(contentWithHighlights);
    _htmlCache[cacheKey] = result;

    stopwatch.stop();
    log.d('词汇高亮处理完成，用时: ${stopwatch.elapsedMilliseconds}ms');

    return result;
  }

  // 优化 _getFormattedHtml 方法，减少不必要的处理
  String _getFormattedHtml(String html) {
    return '''
      <!DOCTYPE html>
      <html lang="zh">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <title>文章详情</title>
        <style>
          body {
            font-family: 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 16px;
            color: ${_isDarkMode ? '#e0e0e0' : '#333'};
            background-color: ${_isDarkMode ? '#121212' : '#fff'};
            font-size: ${_fontSize}px;
          }
          
          .article-content {
            max-width: 100%;
          }
          
          h1, h2, h3, h4, h5, h6 {
            margin-top: 24px;
            margin-bottom: 16px;
            font-weight: 600;
            line-height: 1.25;
            color: ${_isDarkMode ? '#fff' : '#000'};
          }
          
          h1 { font-size: 2em; }
          h2 { font-size: 1.5em; }
          
          p {
            margin-top: 0;
            margin-bottom: 16px;
          }
          
          img {
            max-width: 100%;
            height: auto;
            display: block;
            margin: 16px 0;
          }
          
          a {
            color: ${_isDarkMode ? '#4da3ff' : '#0366d6'};
            text-decoration: none;
          }
          
          blockquote {
            margin: 16px 0;
            padding: 0 16px;
            color: ${_isDarkMode ? '#a0a0a0' : '#6a737d'};
            border-left: 4px solid ${_isDarkMode ? '#444' : '#dfe2e5'};
          }
          
          code {
            font-family: 'Courier New', Courier, monospace;
            padding: 2px 4px;
            background-color: ${_isDarkMode ? '#2a2a2a' : '#f6f8fa'};
            border-radius: 3px;
          }
          
          pre {
            font-family: 'Courier New', Courier, monospace;
            padding: 16px;
            overflow: auto;
            line-height: 1.45;
            background-color: ${_isDarkMode ? '#2a2a2a' : '#f6f8fa'};
            border-radius: 3px;
          }
          
          table {
            border-collapse: collapse;
            width: 100%;
            margin: 16px 0;
          }
          
          td, th {
            border: 1px solid ${_isDarkMode ? '#444' : '#dfe2e5'};
            padding: 8px;
          }
          
          th {
            background-color: ${_isDarkMode ? '#2a2a2a' : '#f0f0f0'};
          }
          
          /* 词汇高亮样式 */
          .highlight-word {
            background-color: rgba(209, 233, 252, 0.3);
            border-bottom: 1px dashed #4a86e8;
            cursor: pointer;
            position: relative;
            padding: 0 1px;
          }
          
          .highlight-word:hover {
            background-color: rgba(209, 233, 252, 0.7);
          }
        </style>
      </head>
      <body>
        <div class="article-content">
          $html
        </div>
      </body>
      </html>
    ''';
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
