import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 单词测试',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const WordTestScreen(),
    );
  }
}

class WordTestScreen extends StatefulWidget {
  const WordTestScreen({Key? key}) : super(key: key);

  @override
  State<WordTestScreen> createState() => _WordTestScreenState();
}

class _WordTestScreenState extends State<WordTestScreen> {
  final TextEditingController _wordController = TextEditingController();
  String _explanation = '';
  bool _isLoading = false;
  StreamSubscription? _streamSubscription;

  @override
  void dispose() {
    _wordController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  // 解码 Unicode 转义序列
  String decodeUnicodeEscapes(String text) {
    if (text.isEmpty) return '';

    try {
      // 替换所有 Unicode 转义序列为实际字符
      RegExp unicodeRegex = RegExp(r'\\u([0-9a-fA-F]{4})');
      return text.replaceAllMapped(unicodeRegex, (Match m) {
        try {
          int charCode = int.parse(m.group(1)!, radix: 16);
          return String.fromCharCode(charCode);
        } catch (e) {
          return m.group(0)!;
        }
      });
    } catch (e) {
      // 如果解析过程中出错，返回原始文本
      return text;
    }
  }

  // 清理响应文本
  String cleanResponseText(String text) {
    if (text.isEmpty) return '';

    try {
      // 首先解码 Unicode 转义序列
      String decoded = decodeUnicodeEscapes(text);

      // 移除 JSON 内容标记和其他格式化工件
      decoded = decoded.replaceAll(RegExp(r'\{"content":\s*"'), '');
      decoded = decoded.replaceAll(RegExp(r'"\}\{"content":\s*"'), '');
      decoded = decoded.replaceAll(RegExp(r'"\}'), '');

      // 替换常见的转义序列
      decoded = decoded.replaceAll('\\n', '\n');
      decoded = decoded.replaceAll('\\t', '\t');
      decoded = decoded.replaceAll('\\"', '"');
      decoded = decoded.replaceAll('\\\\', '\\');

      return decoded;
    } catch (e) {
      // 如果处理过程中出错，返回原始文本
      return text;
    }
  }

  Future<void> _fetchExplanation(String word) async {
    if (word.isEmpty) return;

    setState(() {
      _isLoading = true;
      _explanation = '';
    });

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

                // 清理接收到的文本
                String cleanedText = cleanResponseText(buffer);

                setState(() {
                  _explanation = cleanedText;
                });
              }
            }
          }
        },
        onDone: () {
          setState(() {
            _isLoading = false;

            // 最终清理文本
            _explanation = cleanResponseText(buffer);
          });
        },
        onError: (error) {
          setState(() {
            _explanation = '错误: $error';
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _explanation = '错误: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 单词测试')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _wordController,
              decoration: InputDecoration(
                labelText: '输入一个单词',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _wordController.clear(),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  _isLoading
                      ? null
                      : () => _fetchExplanation(_wordController.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
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
                      : const Text('获取解释', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_wordController.text.isNotEmpty)
                      Text(
                        'Word: ${_wordController.text}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    if (_wordController.text.isNotEmpty)
                      const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child:
                            _explanation.isEmpty && !_isLoading
                                ? const Text('解释将显示在这里')
                                : SelectableText(
                                  _explanation,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),
                      ),
                    ),
                    if (_isLoading) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
