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
import '../providers/word_lookup/word_lookup_provider.dart';
import '../providers/word_lookup/word_lookup_state.dart';
import '../models/dictionary_result.dart';
import '../renderer/html_renderer.dart';
import '../server/local_server.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

class ArticleDetailPage extends ConsumerStatefulWidget {
  final String articleId;

  const ArticleDetailPage({super.key, required this.articleId});

  @override
  ConsumerState<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends ConsumerState<ArticleDetailPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  OverlayEntry? _audioPlayerOverlay;

  @override
  void initState() {
    super.initState();
    log.i('ArticleDetailPage初始化，文章ID: ${widget.articleId}');
  }

  @override
  void dispose() {
    log.i('ArticleDetailPage销毁，文章ID: ${widget.articleId}');
    _removeAudioPlayerOverlay();
    super.dispose();
  }

  void _showAudioPlayerOverlay(String audioUrl) {
    _removeAudioPlayerOverlay();

    _audioPlayerOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: kToolbarHeight + MediaQuery.of(context).padding.top,
        left: 0,
        right: 0,
        child: Material(
          elevation: 4.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: AudioPlayer(
              url: audioUrl,
              onClose: () {
                _removeAudioPlayerOverlay();
                ref
                    .read(articleDetailProvider(widget.articleId).notifier)
                    .toggleAudioPlayer();
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_audioPlayerOverlay!);
  }

  void _removeAudioPlayerOverlay() {
    _audioPlayerOverlay?.remove();
    _audioPlayerOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(articleDetailProvider(widget.articleId));
    final notifier = ref.read(articleDetailProvider(widget.articleId).notifier);

    final article = state.article;

    // 只有当article不为null时才处理音频播放器
    if (article != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (article.audioUrl != null &&
            state.showAudioPlayer &&
            _audioPlayerOverlay == null) {
          _showAudioPlayerOverlay(article.audioUrl!);
        } else if (!state.showAudioPlayer && _audioPlayerOverlay != null) {
          _removeAudioPlayerOverlay();
        }
      });
    }

    return FutureBuilder(
      // 使用Future.value以确保FutureBuilder会立即处理
      future: Future.value(true),
      builder: (context, snapshot) {
        return Scaffold(
          key: _scaffoldKey,
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
              if (article != null &&
                  article.audioUrl != null &&
                  !state.showAudioPlayer)
                IconButton(
                  icon: const Icon(Icons.headphones),
                  onPressed: () => notifier.toggleAudioPlayer(),
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => notifier.loadArticle(),
              ),
              IconButton(
                icon: const Icon(Icons.bookmark_border),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('收藏功能即将上线')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('分享功能即将上线')),
                  );
                },
              ),
            ],
          ),
          body: Builder(
            builder: (context) {
              return HtmlRenderer(
                key: ValueKey('article_${widget.articleId}'),
                articleId: widget.articleId,
                isDarkMode: state.isDarkMode,
                fontSize: state.fontSize,
                showVocabulary: state.showVocabulary,
                onWordSelected: (word) {
                  _showWordExplanationCard(context, word, ref);
                },
                onFontSizeChanged: (newSize) {
                  notifier.setFontSize(newSize.clamp(12.0, 24.0));
                },
              );
            },
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: state.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
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
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        final newSize = (state.fontSize - 1).clamp(12.0, 24.0);
                        if (newSize != state.fontSize) {
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (mounted) {
                              notifier.setFontSize(newSize);
                            }
                          });
                        }
                      },
                    ),
                    Text(
                      state.fontSize.toStringAsFixed(0),
                      style: TextStyle(
                        color: state.isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final newSize = (state.fontSize + 1).clamp(12.0, 24.0);
                        if (newSize != state.fontSize) {
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (mounted) {
                              notifier.setFontSize(newSize);
                            }
                          });
                        }
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        state.showVocabulary
                            ? Icons.format_color_text
                            : Icons.format_color_text_outlined,
                        color: state.isDarkMode
                            ? Colors.white70
                            : Colors.grey[700],
                      ),
                      tooltip: '显示/隐藏重点词汇',
                      onPressed: () => notifier.toggleVocabulary(),
                    ),
                    IconButton(
                      icon: Icon(
                        state.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                        color: state.isDarkMode
                            ? Colors.white70
                            : Colors.grey[700],
                      ),
                      onPressed: () {
                        notifier.toggleDarkMode();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWordExplanationCard(
    BuildContext context,
    String word,
    WidgetRef ref,
  ) async {
    log.i('_showWordExplanationCard: 开始查询单词 "$word"');

    if (!context.mounted) {
      log.w('_showWordExplanationCard: context已失效，无法显示加载对话框');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      final notifier = ref.read(wordLookupProvider.notifier);
      await notifier.searchWord(word);

      if (!context.mounted) {
        log.w('_showWordExplanationCard: context已失效，无法关闭加载对话框');
        return;
      }

      Navigator.of(context, rootNavigator: true).pop();

      final state = ref.read(wordLookupProvider);

      if (!context.mounted) {
        log.w('_showWordExplanationCard: context已失效，无法显示结果');
        return;
      }

      if (state.dictResult != null || state.explanation.isNotEmpty) {
        log.i('_showWordExplanationCard: 找到结果，显示结果卡片');
        _showWordResultCard(context, word, state, ref);
      } else {
        log.w('_showWordExplanationCard: 未找到 "$word" 的解释');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('未找到"$word"的解释')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        log.e('_showWordExplanationCard: 查询过程中发生错误', e);
        Navigator.of(context, rootNavigator: true).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('查询失败: $e')),
        );
      } else {
        log.e('_showWordExplanationCard: 查询过程中发生错误，但context已失效', e);
      }
    }
  }

  void _showWordResultCard(
    BuildContext context,
    String word,
    WordLookupState state,
    WidgetRef ref,
  ) {
    final isAiMode = state.isAiMode;
    final dictResult = state.dictResult;
    final explanation = state.explanation;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        word,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (dictResult?.phonetic != null &&
                          dictResult!.phonetic!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          "[${dictResult.phonetic}]",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.auto_awesome,
                          color:
                              isAiMode ? const Color(0xFF6b4bbd) : Colors.grey,
                          size: 20,
                        ),
                        tooltip: isAiMode ? '切换为普通模式' : '切换为AI模式',
                        onPressed: () {
                          Navigator.pop(context);
                          ref.read(wordLookupProvider.notifier).toggleAiMode();
                          _showWordResultCard(
                            context,
                            word,
                            ref.read(wordLookupProvider),
                            ref,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 20),
                        tooltip: '打开完整词典页面',
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  WordLookupPage(wordToLookup: word),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  child: isAiMode
                      ? _buildAIExplanation(explanation)
                      : _buildDictionaryResult(dictResult),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIExplanation(String explanation) {
    if (explanation.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('AI正在思考中...', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Markdown(
      data: explanation,
      selectable: true,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      styleSheet: MarkdownStyleSheet(
        h1: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        h2: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        h3: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        p: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
        code: TextStyle(
          fontSize: 12,
          backgroundColor: Colors.grey[200],
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
        ),
        blockquote: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Colors.black54,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildDictionaryResult(DictionaryResult? result) {
    if (result == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('没有找到该单词的释义', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.translation != null && result.translation!.isNotEmpty) ...[
          Text(
            "中文释义：${result.translation}",
            style: const TextStyle(fontSize: 16, color: Colors.blue),
          ),
          const SizedBox(height: 8),
        ],
        if (result.definition != null && result.definition!.isNotEmpty) ...[
          Text(
            "英文释义：${result.definition}",
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
        ],
        if (result.tag != null && result.tag!.isNotEmpty) ...[
          Text(
            "词汇分类：${result.tag}",
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
        ],
        if (result.exchange != null && result.exchange!.isNotEmpty) ...[
          Text(
            "变形：${result.exchange}",
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            if (result.collins != null &&
                result.collins!.isNotEmpty &&
                result.collins != '0') ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "柯林斯星级：${result.collins}",
                  style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (result.oxford != null &&
                result.oxford!.isNotEmpty &&
                result.oxford != '0') ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "牛津核心：${result.oxford}",
                  style: TextStyle(fontSize: 12, color: Colors.red[800]),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
