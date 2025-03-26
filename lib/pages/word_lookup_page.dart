import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../utils/logger.dart';
import 'dart:math';

class WordLookupPage extends StatefulWidget {
  final Function(bool)? onSearchStateChanged;
  final String? wordToLookup;

  const WordLookupPage({
    super.key,
    this.onSearchStateChanged,
    this.wordToLookup,
  });

  @override
  State<WordLookupPage> createState() => _WordLookupPageState();
}

class _WordLookupPageState extends State<WordLookupPage> {
  final TextEditingController _wordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _explanation = '';
  bool _isLoading = false;
  bool _showResults = false;
  String _searchedWord = '';
  StreamSubscription? _streamSubscription;
  bool _isAIMode = false; // 新增：控制是否使用AI模式
  Map<String, dynamic>? _dictResult; // 新增：存储字典API结果

  @override
  void initState() {
    super.initState();
    log.i('初始化WordLookupPage');

    // 设置全屏模式，让内容延伸到挖孔区域
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
    // 设置系统UI透明，允许内容显示在状态栏和挖孔区域下方
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
      Future.microtask(() => _searchWord(widget.wordToLookup!));
    }
  }

  @override
  void dispose() {
    log.i('销毁WordLookupPage');
    _wordController.dispose();
    _scrollController.dispose();
    _streamSubscription?.cancel();
    // 退出页面时恢复正常模式
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  // 解码Unicode转义序列
  String decodeUnicodeEscapes(String text) {
    if (text.isEmpty) {
      log.v('解码Unicode转义序列: 输入为空');
      return text;
    }

    // 检查是否需要解码
    if (!text.contains('\\u')) {
      log.v('解码Unicode转义序列: 无需解码（无Unicode序列）');
      return text;
    }

    log.v(
      '解码Unicode转义序列: 输入长度 ${text.length}, 包含 ${RegExp(r'\\u').allMatches(text).length} 个Unicode序列',
    );

    // 替换所有Unicode转义序列为实际字符
    RegExp unicodeRegex = RegExp(r'\\u([0-9a-fA-F]{4})');
    String result = text.replaceAllMapped(unicodeRegex, (Match m) {
      try {
        int charCode = int.parse(m.group(1)!, radix: 16);
        return String.fromCharCode(charCode);
      } catch (e) {
        log.w('Unicode解码失败: ${m.group(0)}', e);
        return m.group(0)!;
      }
    });

    log.v('解码完成: 输出长度 ${result.length}');
    return result;
  }

  // 处理API响应数据
  String processApiResponse(String text) {
    log.v('处理API响应数据: 输入长度 ${text.length}');

    // 解码Unicode转义序列
    String decoded = decodeUnicodeEscapes(text);

    try {
      // 简化JSON提取逻辑，减少正则表达式使用
      if (decoded.startsWith('{') && decoded.endsWith('}')) {
        log.v('尝试直接解析JSON对象');
        try {
          Map<String, dynamic> jsonData = json.decode(decoded);
          if (jsonData.containsKey('content')) {
            String content = jsonData['content'].toString();
            log.v('直接JSON解析成功: 内容长度 ${content.length}');
            return content;
          }
        } catch (e) {
          log.v(
            '直接JSON解析失败: ${e.toString().substring(0, min(50, e.toString().length))}',
          );
        }
      }

      // 尝试提取JSON内容 - 只在第一种方法失败时使用
      log.v('尝试使用正则表达式提取JSON');
      RegExp jsonPattern = RegExp(r'\{.*?\}');
      Iterable<Match> matches = jsonPattern.allMatches(decoded);
      log.v('找到 ${matches.length} 个JSON匹配');

      String result = '';
      for (Match match in matches) {
        try {
          Map<String, dynamic> jsonData = json.decode(match.group(0)!);
          if (jsonData.containsKey('content')) {
            result += jsonData['content'].toString();
          }
        } catch (e) {
          // 静默处理JSON解析错误
        }
      }

      if (result.isNotEmpty) {
        log.v('使用正则表达式提取成功: 内容长度 ${result.length}');
        return result;
      } else {
        log.v('使用正则表达式提取失败: 未找到有效内容');
      }
    } catch (e) {
      log.v(
        'JSON提取过程异常: ${e.toString().substring(0, min(50, e.toString().length))}',
      );
    }

    // 基本清理 - 如果JSON解析失败
    log.v('使用基本文本处理方法');
    decoded = decoded.replaceAll(RegExp(r'\{"content":\s*"'), '');
    decoded = decoded.replaceAll(RegExp(r'"\}\{"content":\s*"'), '');
    decoded = decoded.replaceAll(RegExp(r'"\}'), '');

    // 替换转义序列
    decoded = decoded.replaceAll('\\n', '\n');
    decoded = decoded.replaceAll('\\t', '\t');
    decoded = decoded.replaceAll('\\"', '"');
    decoded = decoded.replaceAll('\\\\', '\\');

    log.v('基本处理完成: 输出长度 ${decoded.trim().length}');
    return decoded.trim();
  }

  // 在数据更新时滚动到底部
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 新增：搜索单词函数，根据模式选择不同API
  Future<void> _searchWord(String word) async {
    if (word.isEmpty) return;

    log.i('开始搜索单词: "$word"，模式: ${_isAIMode ? "AI" : "普通"}');
    _searchedWord = word;

    setState(() {
      _showResults = true;
      _isLoading = true;
      _explanation = '';
      _dictResult = null;
    });

    widget.onSearchStateChanged?.call(true);

    if (_isAIMode) {
      // 使用AI模式查询
      _fetchAIExplanation(word);
    } else {
      // 使用普通字典查询
      _fetchDictionaryExplanation(word);
    }
  }

  // 新增：普通字典查询
  Future<void> _fetchDictionaryExplanation(String word) async {
    log.i('使用字典API查询: "$word"');
    try {
      final uri = Uri.parse('https://language.3049589.xyz/api/stardict/$word');
      log.d('字典API请求URL: $uri');

      final response = await http.get(uri);

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        log.i('字典API请求成功: $word');
        try {
          final result = json.decode(response.body);
          log.d(
            '字典返回结果: ${result.toString().substring(0, min(100, result.toString().length))}...',
          );
          setState(() {
            _dictResult = result;
            _explanation = '';
          });
        } catch (e) {
          log.e('字典API结果解析失败', e);
          setState(() {
            _explanation = '解析结果出错: $e';
          });
        }
      } else {
        log.w('字典API请求失败: HTTP ${response.statusCode}');
        setState(() {
          _explanation = '查询失败: HTTP ${response.statusCode}';
        });
      }

      widget.onSearchStateChanged?.call(false);
    } catch (e) {
      log.e('字典API请求异常', e);
      setState(() {
        _explanation = '查询出错: $e';
        _isLoading = false;
      });

      widget.onSearchStateChanged?.call(false);
    }
  }

  // 修改原有AI查询函数名
  Future<void> _fetchAIExplanation(String word) async {
    log.i('使用AI API查询: "$word"');
    try {
      await _streamSubscription?.cancel();

      final uri = Uri.parse(
        'https://language.3049589.xyz/api/ai/explain/$word?stream=true',
      );
      log.d('AI API请求URL: $uri');

      final request = http.Request('GET', uri);
      request.headers['Accept'] = 'text/event-stream';

      final response = await http.Client().send(request);
      final stream = response.stream.transform(utf8.decoder);

      // 改用累积处理后的文本，而不是原始buffer
      String processedContent = '';
      // 跟踪是否已收到内容
      bool hasReceivedContent = false;

      _streamSubscription = stream.listen(
        (data) {
          final lines = data.split('\n');
          for (var line in lines) {
            if (line.startsWith('data: ')) {
              final eventData = line.substring(6);
              if (eventData != '[DONE]') {
                // 只处理新收到的数据片段，而不是整个缓冲区
                log.d('收到新数据片段，长度: ${eventData.length}');
                String newChunk = processApiResponse(eventData);
                log.d('处理后新内容长度: ${newChunk.length}');

                // 追加到已处理内容
                processedContent += newChunk;

                // 记录渲染状态
                log.i('准备渲染AI内容，当前总长度: ${processedContent.length}字符');

                // 只有当有实质性内容更新时才更新UI
                if (newChunk.trim().isNotEmpty) {
                  // 在收到第一个有效内容时关闭加载指示器
                  final bool shouldHideLoading = !hasReceivedContent;
                  hasReceivedContent = true;

                  setState(() {
                    log.i(
                      '渲染AI内容: ${processedContent.substring(max(0, processedContent.length - 20))}...',
                    );
                    if (shouldHideLoading) {
                      log.i('关闭加载指示器，显示内容');
                      _isLoading = false;
                    }
                    _explanation = processedContent;
                    _scrollToBottom();
                  });
                }
              }
            }
          }
        },
        onDone: () {
          log.i('AI流式响应完成: $word');
          setState(() {
            log.i('渲染最终内容，总长度: ${processedContent.length}字符');
            _isLoading = false; // 确保加载指示器关闭
            // 使用已处理的内容，无需重新处理
            _explanation = processedContent;
            _scrollToBottom();
          });

          widget.onSearchStateChanged?.call(false);
        },
        onError: (error) {
          log.e('AI流式响应错误', error);
          setState(() {
            _explanation = 'Error: $error';
            _isLoading = false;
          });

          widget.onSearchStateChanged?.call(false);
        },
      );
    } catch (e) {
      log.e('AI API请求异常', e);
      setState(() {
        _explanation = 'Error: $e';
        _isLoading = false;
      });

      widget.onSearchStateChanged?.call(false);
    }
  }

  void _clearAndShowNavBar() {
    log.i('清空结果，返回搜索页');
    setState(() {
      _explanation = '';
      _showResults = false;
      _searchedWord = '';
      _dictResult = null;
    });
    widget.onSearchStateChanged?.call(false);
  }

  // 新增：构建字典结果视图
  Widget _buildDictionaryResult() {
    if (_dictResult == null) {
      return const SizedBox();
    }

    log.d('构建字典结果视图');
    // 提取数据
    final word = _dictResult!['word'] ?? '';
    final phonetic = _dictResult!['phonetic'] ?? '';
    final translation = _dictResult!['translation'] ?? '';
    final definition = _dictResult!['definition'] ?? '';
    final collins = _dictResult!['collins'] ?? '';
    final oxford = _dictResult!['oxford'] ?? '';
    final tag = _dictResult!['tag'] ?? '';
    final exchange = _dictResult!['exchange'] ?? '';

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
                word,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (phonetic is String && phonetic.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  "[$phonetic]",
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ],
          ),
          const Divider(height: 24),
          if (translation is String && translation.isNotEmpty) ...[
            Text(
              "中文释义：$translation",
              style: const TextStyle(fontSize: 16, color: Colors.blue),
            ),
            const SizedBox(height: 8),
          ],
          if (definition is String && definition.isNotEmpty) ...[
            Text("英文释义：$definition", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
          ],
          if (tag is String && tag.isNotEmpty) ...[
            Text(
              "词汇分类：$tag",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
          ],
          if (exchange is String && exchange.isNotEmpty) ...[
            Text(
              "变形：$exchange",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              if (collins != null && collins != '' && collins != '0') ...[
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
                    "柯林斯星级：$collins",
                    style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (oxford != null && oxford != '' && oxford != '0') ...[
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
                    "牛津核心：$oxford",
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

  @override
  Widget build(BuildContext context) {
    // 获取屏幕安全区域信息
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;

    return PopScope(
      canPop: !_showResults,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          _clearAndShowNavBar();
        }
      },
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0 && _showResults) {
            _clearAndShowNavBar();
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
              if (!_showResults) ...[
                Container(
                  margin: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    top: 30,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: 230,
                            ), // 透明度使其更融入背景
                            borderRadius: BorderRadius.circular(36),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withValues(
                                  alpha: 30,
                                ), // 更轻微的阴影
                                spreadRadius: 0,
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.search,
                                color: Colors.grey,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _wordController,
                                  decoration: const InputDecoration(
                                    hintText: '输入单词',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    isCollapsed: false,
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                  textAlignVertical: TextAlignVertical.center,
                                  onSubmitted: (value) {
                                    if (!_isLoading &&
                                        value.trim().isNotEmpty) {
                                      _searchWord(value.trim());
                                    }
                                  },
                                ),
                              ),
                              // 新增：AI模式切换按钮
                              IconButton(
                                onPressed: () {
                                  log.i('切换AI模式: ${!_isAIMode}');
                                  setState(() {
                                    _isAIMode = !_isAIMode;
                                  });
                                },
                                icon: Icon(
                                  Icons.auto_awesome,
                                  color:
                                      _isAIMode
                                          ? const Color(0xFF6b4bbd)
                                          : Colors.grey,
                                  size: 18,
                                ),
                                tooltip: _isAIMode ? 'AI模式已开启' : 'AI模式已关闭',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius: 16,
                              ),
                              MaterialButton(
                                onPressed:
                                    _isLoading
                                        ? null
                                        : () {
                                          final word =
                                              _wordController.text.trim();
                                          if (word.isNotEmpty) {
                                            _searchWord(word);
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
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
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
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios),
                        onPressed: _clearAndShowNavBar,
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
                              _searchedWord,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(width: 8),
                            if (_isAIMode)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF6b4bbd,
                                  ).withOpacity(0.1),
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
                          color:
                              _isAIMode ? const Color(0xFF6b4bbd) : Colors.grey,
                        ),
                        onPressed: () {
                          log.i('结果页切换AI模式: ${!_isAIMode}');
                          setState(() {
                            _isAIMode = !_isAIMode;
                            // 模式切换后重新搜索当前单词
                            if (_searchedWord.isNotEmpty) {
                              _searchWord(_searchedWord);
                            }
                          });
                        },
                        tooltip: _isAIMode ? '切换为普通模式' : '切换为AI模式',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_isAIMode) ...[
                  // AI模式直接在背景上渲染
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child:
                                _explanation.isEmpty && _isLoading
                                    ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                    : _explanation.isEmpty
                                    ? const Center(child: Text('AI正在思考中...'))
                                    : Markdown(
                                      controller: _scrollController,
                                      data: _explanation,
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
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        blockquote: const TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                          color: Colors.black54,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        blockquoteDecoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border(
                                            left: BorderSide(
                                              color: Colors.grey[400]!,
                                              width: 4,
                                            ),
                                          ),
                                        ),
                                      ),
                                      extensionSet: md.ExtensionSet(
                                        md
                                            .ExtensionSet
                                            .commonMark
                                            .blockSyntaxes,
                                        [
                                          ...md
                                              .ExtensionSet
                                              .commonMark
                                              .inlineSyntaxes,
                                          md.EmojiSyntax(),
                                        ],
                                      ),
                                    ),
                          ),
                          if (_isLoading && _explanation.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Center(child: LinearProgressIndicator()),
                            const SizedBox(height: 8),
                            const Center(
                              child: Text(
                                "继续加载中...",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // 普通模式使用白色背景容器
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child:
                                        _dictResult == null
                                            ? const Center(
                                              child: Text(
                                                '没有找到该单词的释义',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            )
                                            : SingleChildScrollView(
                                              child: _buildDictionaryResult(),
                                            ),
                                  ),
                                  if (_isLoading) ...[
                                    const SizedBox(height: 16),
                                    const Center(
                                      child: Text(
                                        "正在加载...",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
