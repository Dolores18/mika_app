import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

class WordLookupPage extends StatefulWidget {
  final Function(bool)? onSearchStateChanged; // 添加回调函数属性

  const WordLookupPage({Key? key, this.onSearchStateChanged}) : super(key: key);

  @override
  State<WordLookupPage> createState() => _WordLookupPageState();
}

class _WordLookupPageState extends State<WordLookupPage> {
  final TextEditingController _wordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _explanation = '';
  bool _isLoading = false;
  StreamSubscription? _streamSubscription;

  @override
  void dispose() {
    _wordController.dispose();
    _scrollController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  // 解码Unicode转义序列
  String decodeUnicodeEscapes(String text) {
    // 替换所有Unicode转义序列为实际字符
    RegExp unicodeRegex = RegExp(r'\\u([0-9a-fA-F]{4})');
    return text.replaceAllMapped(unicodeRegex, (Match m) {
      try {
        int charCode = int.parse(m.group(1)!, radix: 16);
        return String.fromCharCode(charCode);
      } catch (e) {
        return m.group(0)!;
      }
    });
  }

  // 处理API响应数据
  String processApiResponse(String text) {
    // 解码Unicode转义序列
    String decoded = decodeUnicodeEscapes(text);

    try {
      // 尝试提取JSON内容
      RegExp jsonPattern = RegExp(r'\{.*?\}');
      Iterable<Match> matches = jsonPattern.allMatches(decoded);

      String result = '';
      for (Match match in matches) {
        try {
          Map<String, dynamic> jsonData = json.decode(match.group(0)!);
          if (jsonData.containsKey('content')) {
            result += jsonData['content'].toString();
          }
        } catch (e) {
          // 忽略无效的JSON
        }
      }

      if (result.isNotEmpty) {
        return result;
      }
    } catch (e) {
      // 如果JSON解析失败，继续使用基本处理
    }

    // 基本清理 - 如果JSON解析失败
    decoded = decoded.replaceAll(RegExp(r'\{"content":\s*"'), '');
    decoded = decoded.replaceAll(RegExp(r'"\}\{"content":\s*"'), '');
    decoded = decoded.replaceAll(RegExp(r'"\}'), '');

    // 替换转义序列
    decoded = decoded.replaceAll('\\n', '\n');
    decoded = decoded.replaceAll('\\t', '\t');
    decoded = decoded.replaceAll('\\"', '"');
    decoded = decoded.replaceAll('\\\\', '\\');

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

  Future<void> _fetchExplanation(String word) async {
    if (word.isEmpty) return;

    setState(() {
      _isLoading = true;
      _explanation = '';
    });

    // 通知父组件搜索开始，显示搜索状态
    widget.onSearchStateChanged?.call(true);

    try {
      await _streamSubscription?.cancel();

      final request = http.Request(
        'GET',
        Uri.parse(
          'https://language.3049589.xyz/api/ai/explain/$word?stream=true',
        ),
      );
      request.headers['Accept'] = 'text/event-stream';

      final response = await http.Client().send(request);
      final stream = response.stream.transform(utf8.decoder);

      String buffer = '';

      _streamSubscription = stream.listen(
        (data) {
          final lines = data.split('\n');
          for (var line in lines) {
            if (line.startsWith('data: ')) {
              final eventData = line.substring(6);
              if (eventData != '[DONE]') {
                buffer += eventData;

                // 处理API响应
                String processedText = processApiResponse(buffer);

                setState(() {
                  _explanation = processedText;
                  _scrollToBottom();
                });
              }
            }
          }
        },
        onDone: () {
          setState(() {
            _isLoading = false;

            // 最终处理
            _explanation = processApiResponse(buffer);
            _scrollToBottom();
          });

          // 搜索完成，可以选择保持导航栏隐藏或显示
          // 如果希望结果显示时保持导航栏隐藏，保持为true
          // 如果希望搜索完成后显示导航栏，改为false
          widget.onSearchStateChanged?.call(true); // 保持隐藏状态
        },
        onError: (error) {
          setState(() {
            _explanation = 'Error: $error';
            _isLoading = false;
          });

          // 发生错误时恢复导航栏
          widget.onSearchStateChanged?.call(false);
        },
      );
    } catch (e) {
      setState(() {
        _explanation = 'Error: $e';
        _isLoading = false;
      });

      // 发生错误时恢复导航栏
      widget.onSearchStateChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _wordController,
            decoration: InputDecoration(
              labelText: '输入单词',
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _wordController.clear(),
              ),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              if (!_isLoading) {
                _fetchExplanation(value.trim());
              }
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed:
                _isLoading
                    ? null
                    : () => _fetchExplanation(_wordController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Text('获取解释'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_wordController.text.isNotEmpty)
                    const SizedBox(height: 8),
                  Expanded(
                    child:
                        _explanation.isEmpty && !_isLoading
                            ? const Text('解释将显示在这里')
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
                  if (_isLoading) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ),
          // 添加一个返回按钮，用于显示导航栏
          if (_explanation.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // 清空解释内容
                setState(() {
                  _explanation = '';
                });
                // 显示导航栏
                widget.onSearchStateChanged?.call(false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black87,
              ),
              child: const Text('返回'),
            ),
          ],
        ],
      ),
    );
  }
}
