// lib/pages/word_lookup_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:markdown/markdown.dart' as md;
import '../models/dictionary_result.dart';
import '../providers/word_lookup/word_lookup_provider.dart';
import '../providers/word_lookup/word_lookup_notifier.dart';
import '../providers/word_lookup/word_lookup_state.dart';
import '../utils/logger.dart';
import 'dart:math';
import 'word_search_page.dart';

class WordLookupPage extends ConsumerStatefulWidget {
  final Function(bool)? onSearchStateChanged;
  final String? wordToLookup;

  const WordLookupPage({
    super.key,
    this.onSearchStateChanged,
    this.wordToLookup,
  });

  @override
  ConsumerState<WordLookupPage> createState() => _WordLookupPageState();
}

class _WordLookupPageState extends ConsumerState<WordLookupPage> {
  final TextEditingController _wordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // 添加状态记录，用于跟踪上一次的显示状态
  bool _lastShowResultsState = false;

  @override
  void initState() {
    super.initState();
    log.i('初始化WordLookupPage');

    // 设置全屏模式，让内容延伸到挖孔区域
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );

    // 设置系统UI透明
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    // 如果传入了待查询的单词，自动进行查询
    if (widget.wordToLookup != null && widget.wordToLookup!.isNotEmpty) {
      log.i('传入单词自动查询: ${widget.wordToLookup}');
      _wordController.text = widget.wordToLookup!;

      // 使用microtask确保在构建完成后执行查询
      Future.microtask(
        () => ref
            .read(wordLookupProvider.notifier)
            .searchWord(widget.wordToLookup!),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 延迟执行，确保不在构建过程中调用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifySearchStateChange();
      _checkJapaneseNavigation();
    });
  }

  // 抽取方法单独处理状态变化通知
  void _notifySearchStateChange() {
    if (!mounted) return;

    final state = ref.read(wordLookupProvider);
    if (widget.onSearchStateChanged != null &&
        _lastShowResultsState != state.showResults) {
      _lastShowResultsState = state.showResults;
      widget.onSearchStateChanged!(state.showResults);
    }
  }

  // 检查是否需要导航到日语词典页面
  void _checkJapaneseNavigation() {
    if (!mounted) return;

    final state = ref.read(wordLookupProvider);

    // 如果显示结果且是日语模式，直接导航
    if (state.showResults &&
        state.selectedLanguage == SearchLanguage.japanese &&
        state.searchedWord.isNotEmpty) {
      log.i('检测到日语模式，立即导航到词典页面: ${state.searchedWord}');

      // 立即导航，使用 push 而不是 pushReplacement
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WordSearchPage(
              word: state.searchedWord,
              title: '日语词典',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    log.i('销毁WordLookupPage');
    _wordController.dispose();
    _scrollController.dispose();

    // 退出页面时恢复正常模式
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  // 处理日语查询 - 标准做法：在查询成功后直接导航
  void _handleJapaneseSearch(String word) {
    log.i('处理日语查询: $word');

    // 直接导航，不改变状态
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WordSearchPage(
          word: word,
          title: '日语词典',
        ),
      ),
    );
  }

  // 在数据更新时滚动到底部
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        log.i('滚动到底部');
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 通过ref.watch监听状态变化
    final state = ref.watch(wordLookupProvider);
    final notifier = ref.read(wordLookupProvider.notifier);

    // 不要在build过程中直接调用回调
    // 而是在帧回调中处理状态变化通知
    if (_lastShowResultsState != state.showResults) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifySearchStateChange();
      });
    }

    // 检测到内容更新时，滚动到底部
    if (state.contentUpdated && state.isAiMode) {
      _scrollToBottom();
    }

    // 获取屏幕安全区域信息
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;

    return PopScope(
      canPop: !state.showResults,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          notifier.clearResults();
        }
      },
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0 && state.showResults) {
            notifier.clearResults();
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFFCE4EC), // 使用淡粉红色作为背景色
          // 移除SafeArea，使用自定义padding来适配挖孔屏
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 添加与状态栏等高的SizedBox
              SizedBox(height: topPadding),
              if (!state.showResults) ...[
                _buildSearchBar(notifier),
              ] else ...[
                _buildResultHeader(state, notifier),
                const SizedBox(height: 16),
                if (state.isAiMode) ...[
                  _buildAIContent(state),
                ] else if (state.selectedLanguage ==
                    SearchLanguage.japanese) ...[
                  // 日语模式下不显示任何内容，直接触发导航
                  const SizedBox.shrink(),
                ] else ...[
                  _buildDictionaryContent(state),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 搜索栏UI
  Widget _buildSearchBar(WordLookupNotifier notifier) {
    final isAiMode = ref.watch(isAiModeProvider);
    final selectedLanguage = ref.watch(selectedLanguageProvider);

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 30),
      child: Column(
        children: [
 
          // 搜索框
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 230),
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 30),
                        spreadRadius: 0,
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0, right: 4.0),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<SearchLanguage>(
                            value: selectedLanguage,
                            isDense: true,
                            items: SearchLanguage.values.map((language) {
                              return DropdownMenuItem<SearchLanguage>(
                                value: language,
                                child: Text(language == SearchLanguage.japanese
                                    ? "日🔍"
                                    : "英🔍"),
                              );
                            }).toList(),
                            onChanged: (SearchLanguage? newLanguage) {
                              if (newLanguage != null) {
                                notifier.changeLanguage(newLanguage);
                              }
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _wordController,
                          decoration: InputDecoration(
                            hintText:
                                selectedLanguage == SearchLanguage.japanese
                                    ? '输入日语单词'
                                    : '输入英语单词',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 4),
                            isCollapsed: false,
                          ),
                          style: const TextStyle(fontSize: 13),
                          textAlignVertical: TextAlignVertical.center,
                          onChanged: (value) {
                            // 实时搜索建议（仅日语）
                            if (selectedLanguage == SearchLanguage.japanese) {
                              notifier.searchSuggestions(value.trim());
                            }
                            // 触发UI更新以显示/隐藏清理按钮
                            setState(() {});
                          },
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              // 日语模式下直接导航，不改变状态
                              if (selectedLanguage == SearchLanguage.japanese) {
                                _handleJapaneseSearch(value.trim());
                                notifier.clearSuggestions();
                                _wordController.clear(); // 清空输入框
                              } else {
                                // 其他语言正常查询
                                notifier.clearSuggestions();
                                notifier.searchWord(value.trim());
                                _wordController.clear(); // 清空输入框
                              }
                            }
                          },
                          onTap: () {
                            // 点击输入框时，如果是日语且有内容，显示建议
                            if (selectedLanguage == SearchLanguage.japanese &&
                                _wordController.text.trim().isNotEmpty) {
                              notifier.searchSuggestions(
                                  _wordController.text.trim());
                            }
                          },
                        ),
                      ),

                      // 清理按钮
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _wordController,
                        builder: (context, value, child) {
                          if (value.text.isNotEmpty) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    _wordController.clear();
                                    notifier.clearSuggestions();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.clear,
                                      color: Colors.grey,
                                      size: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),

                      // AI模式切换按钮
                      IconButton(
                        onPressed: () => notifier.toggleAiMode(),
                        icon: Icon(
                          Icons.auto_awesome,
                          color:
                              isAiMode ? const Color(0xFF6b4bbd) : Colors.grey,
                          size: 18,
                        ),
                        tooltip: isAiMode ? 'AI模式已开启' : 'AI模式已关闭',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 16,
                      ),

                      // 查询按钮
                      MaterialButton(
                        onPressed: () {
                          final word = _wordController.text.trim();
                          if (word.isNotEmpty) {
                            // 日语模式下直接导航，不改变状态
                            if (selectedLanguage == SearchLanguage.japanese) {
                              _handleJapaneseSearch(word);
                              _wordController.clear(); // 清空输入框
                            } else {
                              // 其他语言正常查询
                              notifier.searchWord(word);
                            }
                          }
                        },
                        color: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(36),
                        ),
                        padding: EdgeInsets.zero,
                        minWidth: 60,
                        height: 28,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        child: const Text(
                          '查询',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6b4bbd),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 搜索建议列表
          _buildSearchSuggestions(ref.watch(wordLookupProvider), notifier),
        ],
      ),
    );
  }

  // 结果页头部UI
  Widget _buildResultHeader(
    WordLookupState state,
    WordLookupNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => notifier.clearResults(),
            tooltip: '返回',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: 20,
            splashRadius: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Text(
                  state.searchedWord,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 8),
                // 语言标签
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: state.selectedLanguage == SearchLanguage.japanese
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    state.selectedLanguage.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: state.selectedLanguage == SearchLanguage.japanese
                          ? Colors.orange[700]
                          : Colors.blue[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                if (state.isAiMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6b4bbd).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: const Color(0xFF6b4bbd),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'AI',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF6b4bbd),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.auto_awesome,
              color: state.isAiMode ? const Color(0xFF6b4bbd) : Colors.grey,
            ),
            onPressed: () => notifier.toggleAiMode(),
            tooltip: state.isAiMode ? '切换为普通模式' : '切换为AI模式',
          ),
        ],
      ),
    );
  }

  // AI内容UI
  Widget _buildAIContent(WordLookupState state) {
    return Expanded(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: state.explanation.isEmpty && state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.explanation.isEmpty
                      ? const Center(child: Text('AI正在思考中...'))
                      : NotificationListener<ScrollNotification>(
                          onNotification: (ScrollNotification notification) {
                            // 当用户手动滚动时，可以在这里做一些额外处理
                            return false;
                          },
                          child: Markdown(
                            controller: _scrollController,
                            data: state.explanation,
                            selectable: true,
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
                              p: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: Colors.black87,
                              ),
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
                              blockquoteDecoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                                border: Border(
                                  left: BorderSide(
                                    color: Colors.grey[400]!,
                                    width: 4,
                                  ),
                                ),
                              ),
                            ),
                            extensionSet: md.ExtensionSet(
                              md.ExtensionSet.commonMark.blockSyntaxes,
                              [
                                ...md.ExtensionSet.commonMark.inlineSyntaxes,
                                md.EmojiSyntax(),
                              ],
                            ),
                          ),
                        ),
            ),
            if (state.isLoading && state.explanation.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Center(child: LinearProgressIndicator()),
              const SizedBox(height: 8),
              const Center(
                child: Text("继续加载中...", style: TextStyle(color: Colors.grey)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 字典内容UI
  Widget _buildDictionaryContent(WordLookupState state) {
    return Expanded(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: state.dictResult == null
                        ? const Center(
                            child: Text(
                              '没有找到该单词的释义',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : SingleChildScrollView(
                            child: _buildDictionaryResult(
                              state.dictResult!,
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  // 构建字典结果视图
  Widget _buildDictionaryResult(DictionaryResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                result.word,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (result.phonetic != null && result.phonetic!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  "[${result.phonetic}]",
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ],
          ),
          const Divider(height: 24),
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
          Row(
            children: [
              if (result.collins != null &&
                  result.collins!.isNotEmpty &&
                  result.collins != '0') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
      ),
    );
  }

  // 构建搜索建议列表
  Widget _buildSearchSuggestions(
      WordLookupState state, WordLookupNotifier notifier) {
    // 只在日语模式下显示建议
    if (state.selectedLanguage != SearchLanguage.japanese) {
      return const SizedBox.shrink();
    }

    // 如果没有建议且不在加载中，不显示
    if (state.searchSuggestions.isEmpty && !state.isLoadingSuggestions) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 240),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 30),
            spreadRadius: 0,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.isLoadingSuggestions) ...[
            const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '搜索中...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ] else ...[
            ...state.searchSuggestions.map((suggestion) {
              return InkWell(
                onTap: () {
                  final queryText = suggestion['query_text'] ?? '';
                  log.i('点击建议: ${suggestion['headword']}, 查询文本: $queryText');

                  notifier.clearSuggestions();

                  // 日语模式下直接导航，不改变状态
                  if (state.selectedLanguage == SearchLanguage.japanese) {
                    _handleJapaneseSearch(queryText);
                  } else {
                    notifier.searchWord(queryText);
                  }

                  _wordController.clear(); // 直接清空输入框
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withValues(alpha: 20),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          suggestion['headword'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.north_west,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            if (state.searchSuggestions.isNotEmpty) ...[
              InkWell(
                onTap: () => notifier.clearSuggestions(),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const Text(
                    '收起建议',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// 这是从Flutter SDK中复制过来的扩展方法，用于处理颜色透明度
extension ColorExtension on Color {
  Color withValues({int? red, int? green, int? blue, int? alpha}) {
    return Color.fromARGB(
      alpha ?? this.alpha,
      red ?? this.red,
      green ?? this.green,
      blue ?? this.blue,
    );
  }
}
