import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import '../models/article.dart';
import '../services/history_service.dart';
import '../widgets/audio_player.dart';
import '../widgets/key_points_list.dart';
import '../widgets/vocabulary_list.dart';
import 'word_lookup_page.dart';
import '../utils/logger.dart';
import '../providers/article/article_detail_provider.dart';
import '../providers/article/article_detail_state.dart';
import '../services/article_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../providers/word_lookup/word_lookup_provider.dart';
import '../providers/word_lookup/word_lookup_state.dart';
import '../models/dictionary_result.dart';
import '../renderer/html_renderer.dart';
import '../server/local_server.dart';
import 'package:path/path.dart' as path;
import '../controllers/bookmark_controller.dart';

class ArticleDetailPage extends ConsumerStatefulWidget {
  final String articleId;

  const ArticleDetailPage({super.key, required this.articleId});

  @override
  ConsumerState<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends ConsumerState<ArticleDetailPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  OverlayEntry? _audioPlayerOverlay;
  bool _historyHasBeenSaved = false;

  // GetX 收藏控制器
  final BookmarkController _bookmarkController = Get.put(BookmarkController());
  final HistoryService _historyService = HistoryService();

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
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: AudioPlayer(
              url: audioUrl,
              articleId: widget.articleId,
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

    // 当文章数据成功加载时，添加到历史记录
    if (article != null && !_historyHasBeenSaved) {
      _historyService.addArticleToHistory(article);
      _historyHasBeenSaved = true;
    }

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
              icon: Icon(
                Icons.headphones,
                color: state.isDarkMode ? Colors.white : Colors.black87,
              ),
              onPressed: () => notifier.toggleAudioPlayer(),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref
                  .read(articleDetailProvider(widget.articleId).notifier)
                  .refreshContent();
            },
          ),
          Obx(() => IconButton(
                icon: Icon(
                  _bookmarkController.isBookmarked(widget.articleId)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color: _bookmarkController.isBookmarked(widget.articleId)
                      ? const Color(0xFF6b4bbd)
                      : (state.isDarkMode ? Colors.white : Colors.black87),
                ),
                onPressed: () {
                  _bookmarkController.toggleBookmark(widget.articleId);
                },
                tooltip: _bookmarkController.isBookmarked(widget.articleId)
                    ? '取消收藏'
                    : '收藏文章',
              )),
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
            articleId: widget.articleId,
            isDarkMode: state.isDarkMode,
            fontSize: state.fontSize,
            showVocabulary: state.showVocabulary,
            onWordSelected: (word) {},
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
            IconButton(
              icon: Icon(
                state.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: state.isDarkMode ? Colors.white : Colors.black87,
              ),
              onPressed: () {
                notifier.toggleDarkMode();
              },
            ),
          ],
        ),
      ),
    );
  }
}