import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/article.dart';
import '../widgets/audio_player.dart';
import '../widgets/key_points_list.dart';
import '../widgets/vocabulary_list.dart';
import 'word_lookup_page.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../utils/logger.dart';
import '../providers/article/article_detail_provider.dart';
import '../services/article_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

// 自定义文本选择控制器类
class CustomTextSelectionControls extends TextSelectionControls {
  final BuildContext context;
  final TextSelectionControls platformControls;
  final Function(BuildContext, String) onWordLookup;

  CustomTextSelectionControls({
    required this.context,
    required this.onWordLookup,
  }) : platformControls = MaterialTextSelectionControls();

  @override
  Widget buildToolbar(
    BuildContext context,
    Rect globalEditableRegion,
    double textLineHeight,
    Offset selectionMidpoint,
    List<TextSelectionPoint> endpoints,
    TextSelectionDelegate delegate,
    ValueListenable<ClipboardStatus>? clipboardStatus,
    Offset? lastSecondaryTapDownPosition,
  ) {
    // 获取原始的工具栏
    final Widget originalToolbar = platformControls.buildToolbar(
      context,
      globalEditableRegion,
      textLineHeight,
      selectionMidpoint,
      endpoints,
      delegate,
      clipboardStatus,
      lastSecondaryTapDownPosition,
    );

    // 获取选中的文本
    final selectedText = delegate.textEditingValue.selection.textInside(
      delegate.textEditingValue.text,
    );

    if (selectedText.isEmpty) {
      return originalToolbar;
    }

    // 添加自定义菜单项
    return Material(
      elevation: 6.0,
      child: Container(
        margin: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 原始工具栏中的复制按钮等
            Flexible(child: originalToolbar),
            // 分隔线
            const SizedBox(width: 8),
            const VerticalDivider(width: 1, thickness: 1),
            const SizedBox(width: 8),
            // 查找单词按钮
            TextButton.icon(
              icon: const Icon(Icons.search, size: 18),
              label: const Text('查找单词'),
              onPressed: () {
                if (selectedText.isNotEmpty) {
                  onWordLookup(context, selectedText);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textHeight, [
    VoidCallback? onTap,
  ]) {
    return platformControls.buildHandle(context, type, textHeight, onTap);
  }

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    return platformControls.getHandleAnchor(type, textLineHeight);
  }

  @override
  Size getHandleSize(double textLineHeight) {
    return platformControls.getHandleSize(textLineHeight);
  }
}

class ArticleDetailPage extends ConsumerWidget {
  final String articleId;
  final ScrollController _scrollController = ScrollController();

  ArticleDetailPage({super.key, required this.articleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(articleDetailProvider(articleId));
    final notifier = ref.read(articleDetailProvider(articleId).notifier);

    if (state.article == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final article = state.article!;

    return Scaffold(
      backgroundColor:
          state.isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor:
            state.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
          color: state.isDarkMode ? Colors.white : Colors.black87,
        ),
        title: const Text(''),
        centerTitle: true,
        actions: [
          // 如果音频被隐藏但存在音频链接时，显示恢复音频播放器按钮
          if (!state.showAudioPlayer && article.audioUrl != null)
            IconButton(
              icon: const Icon(Icons.headphones),
              onPressed: () => notifier.toggleAudioPlayer(),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.loadMarkdownContent(),
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
                state.isLoadingContent
                    ? const Center(child: CircularProgressIndicator())
                    : state.contentError != null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            state.contentError!,
                            style: TextStyle(
                              color:
                                  state.isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => notifier.loadMarkdownContent(),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                    : state.htmlContent != null
                    ? _buildMarkdownView(
                      context,
                      state.htmlContent!,
                      article,
                      state,
                      ref,
                    )
                    : const Center(child: Text('没有内容可显示')),
          ),
        ],
      ),
      // 悬浮按钮 - 用于获取选中的文本并搜索
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 异步获取当前选中的文本
          final String? selectedText = await _getSelectedText();
          if (selectedText != null && selectedText.isNotEmpty) {
            _navigateToWordLookup(context, selectedText);
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('请先选择要查找的文本')));
          }
        },
        child: const Icon(Icons.search),
        tooltip: '查找选中的文本',
      ),
      // 底部工具栏
      bottomNavigationBar:
          state.isLoadingContent
              ? null
              : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      state.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 左侧字体大小控制
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            notifier.setFontSize(
                              (state.fontSize - 1).clamp(12.0, 24.0),
                            );
                            notifier.clearCache();
                          },
                        ),
                        Text(
                          state.fontSize.toStringAsFixed(0),
                          style: TextStyle(
                            color:
                                state.isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            notifier.setFontSize(
                              (state.fontSize + 1).clamp(12.0, 24.0),
                            );
                            notifier.clearCache();
                          },
                        ),
                      ],
                    ),
                    // 右侧工具按钮
                    Row(
                      children: [
                        // 词汇显示控制
                        IconButton(
                          icon: Icon(
                            state.showVocabulary
                                ? Icons.format_color_text
                                : Icons.format_color_text_outlined,
                            color:
                                state.isDarkMode
                                    ? Colors.white70
                                    : Colors.grey[700],
                          ),
                          tooltip: '显示/隐藏重点词汇',
                          onPressed: () => notifier.toggleVocabulary(),
                        ),
                        // 黑暗模式切换
                        IconButton(
                          icon: Icon(
                            state.isDarkMode
                                ? Icons.light_mode
                                : Icons.dark_mode,
                            color:
                                state.isDarkMode
                                    ? Colors.white70
                                    : Colors.grey[700],
                          ),
                          onPressed: () {
                            notifier.toggleDarkMode();
                            notifier.clearCache();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }

  // 跳转到单词查找页面
  void _navigateToWordLookup(BuildContext context, String word) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WordLookupPage(wordToLookup: word),
      ),
    );
  }

  // 获取当前选中的文本，返回Future
  Future<String?> _getSelectedText() async {
    // 使用系统剪贴板获取选中的文本
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    return clipboardData?.text;
  }

  // 显示单词悬浮卡片
  void _showWordPopup(
    BuildContext context, {
    required String word,
    required String translation,
    required String wordContext,
    required String example,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        word,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Text(
                    translation,
                    style: TextStyle(fontSize: 18, color: Colors.blue[800]),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "上下文: $wordContext",
                    style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("例句: $example", style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: const Text("添加到生词本"),
                        onPressed: () {
                          // 添加生词本功能
                          Navigator.pop(context);
                        },
                      ),
                      TextButton(
                        child: const Text("关闭"),
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

  // Markdown渲染方法
  Widget _buildMarkdownView(
    BuildContext context,
    String markdownContent,
    Article article,
    dynamic state,
    WidgetRef ref,
  ) {
    // 获取notifier，用于处理音频播放器的切换
    final notifier = ref.read(articleDetailProvider(articleId).notifier);

    // 处理Markdown内容，移除第一个一级标题
    String processedContent = markdownContent;
    final RegExp firstTitleRegex = RegExp(r'^\s*#\s+.*', multiLine: true);
    final Match? firstTitleMatch = firstTitleRegex.firstMatch(processedContent);

    if (firstTitleMatch != null) {
      // 只移除第一个匹配的一级标题
      processedContent = processedContent.replaceFirst(
        firstTitleMatch.group(0)!,
        '',
      );
      log.i('已移除第一个一级标题: ${firstTitleMatch.group(0)}');
    }

    // 提取音频链接
    String? audioUrl;
    final RegExp audioRegex = RegExp(r'\[收听音频\]\((https?://[^\s\)]+\.mp3)\)');
    final Match? audioMatch = audioRegex.firstMatch(processedContent);

    if (audioMatch != null) {
      audioUrl = audioMatch.group(1);
      // 从Markdown内容中移除音频链接文本，因为我们将单独在顶部显示音频播放器
      processedContent = processedContent.replaceFirst(
        audioMatch.group(0)!,
        '',
      );
      log.i('提取到音频链接: $audioUrl');
    } else if (article.audioUrl != null && article.audioUrl!.isNotEmpty) {
      // 如果Markdown中没有找到音频链接，但是文章对象包含audioUrl，也使用它
      audioUrl = article.audioUrl;
      log.i('使用文章对象中的音频链接: $audioUrl');
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

    // 处理重点词汇高亮
    final vocabularyList = article.analysis?.vocabulary ?? [];
    if (state.showVocabulary && vocabularyList.isNotEmpty) {
      log.i('处理重点词汇高亮，词汇数量: ${vocabularyList.length}');

      // 按照单词长度从长到短排序，以避免短词替换影响长词
      vocabularyList.sort((a, b) => b.word.length.compareTo(a.word.length));

      for (var vocab in vocabularyList) {
        // 使用正则表达式查找单词（确保只匹配完整单词）
        final wordRegex = RegExp(
          r'\b' + RegExp.escape(vocab.word) + r'\b',
          caseSensitive: false,
        );

        if (wordRegex.hasMatch(processedContent)) {
          // 替换为带有链接的形式，以便捕获点击事件
          processedContent = processedContent.replaceAllMapped(wordRegex, (
            match,
          ) {
            log.d('添加词汇高亮: ${match.group(0)}');
            return '[${match.group(0)}](vocab:${vocab.word})';
          });
        }
      }
    }

    // 创建包含音频播放器（如果有）和Markdown内容的组合视图
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 如果有音频URL，显示音频播放器
        if (audioUrl != null && state.showAudioPlayer)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: AudioPlayer(
              url: audioUrl,
              onClose: () => notifier.toggleAudioPlayer(),
            ),
          ),

        // Markdown内容
        Expanded(
          child: GestureDetector(
            onLongPress: () {
              // 长按时的自定义操作（可选）
            },
            child: SelectionArea(
              child: Markdown(
                data: processedContent,
                styleSheet: MarkdownStyleSheet(
                  h1: TextStyle(
                    fontSize: state.fontSize * 1.5,
                    fontWeight: FontWeight.bold,
                    color: state.isDarkMode ? Colors.white : Colors.black87,
                  ),
                  h2: TextStyle(
                    fontSize: state.fontSize * 1.3,
                    fontWeight: FontWeight.bold,
                    color: state.isDarkMode ? Colors.white : Colors.black87,
                  ),
                  h3: TextStyle(
                    fontSize: state.fontSize * 1.1,
                    fontWeight: FontWeight.bold,
                    color: state.isDarkMode ? Colors.white : Colors.black87,
                  ),
                  p: TextStyle(
                    fontSize: state.fontSize,
                    color: state.isDarkMode ? Colors.white70 : Colors.black87,
                    height: 1.6,
                  ),
                  blockquote: TextStyle(
                    fontSize: state.fontSize,
                    color:
                        state.isDarkMode ? Colors.grey[400] : Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color:
                            state.isDarkMode
                                ? Colors.grey[700]!
                                : Colors.grey[300]!,
                        width: 4.0,
                      ),
                    ),
                  ),
                  code: TextStyle(
                    fontSize: state.fontSize * 0.9,
                    color: state.isDarkMode ? Colors.grey[300] : Colors.black87,
                    backgroundColor:
                        state.isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  ),
                  codeblockDecoration: BoxDecoration(
                    color:
                        state.isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  listBullet: TextStyle(
                    fontSize: state.fontSize,
                    color: state.isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                  a: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
                onTapLink: (text, href, title) {
                  // 处理重点词汇点击
                  if (href != null && href.startsWith('vocab:')) {
                    final word = href.substring(6); // 去掉'vocab:'前缀
                    final vocabulary = article.analysis?.vocabulary.firstWhere(
                      (v) => v.word.toLowerCase() == word.toLowerCase(),
                      orElse:
                          () => Vocabulary(
                            word: word,
                            translation: '未知翻译',
                            context: '未找到上下文',
                            example: '未找到例句',
                          ),
                    );

                    if (vocabulary != null) {
                      _showWordPopup(
                        context,
                        word: vocabulary.word,
                        translation: vocabulary.translation,
                        wordContext: vocabulary.context,
                        example: vocabulary.example,
                      );
                    }
                  }
                  // 处理其他链接点击
                  else if (href != null) {
                    // 如果是mp3链接，显示音频播放器
                    if (href.endsWith('.mp3')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('音频播放功能即将上线')),
                      );
                    } else {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('链接: $href')));
                    }
                  }
                },
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
                          style: TextStyle(fontSize: state.fontSize * 0.8),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 检查当前Markdown内容是否包含音频链接
  bool _hasAudioLink(String? content) {
    if (content == null) return false;
    final RegExp audioRegex = RegExp(r'\[收听音频\]\((https?://[^\s\)]+\.mp3)\)');
    return audioRegex.hasMatch(content);
  }
}
