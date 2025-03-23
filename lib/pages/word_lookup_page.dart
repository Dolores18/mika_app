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
      title: 'AI Word Test',
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

      _streamSubscription = stream.listen(
        (data) {
          final lines = data.split('\n');
          for (var line in lines) {
            if (line.startsWith('data: ')) {
              final eventData = line.substring(6);
              if (eventData != '[DONE]') {
                setState(() {
                  _explanation += eventData;
                });
              }
            }
          }
        },
        onDone: () {
          setState(() {
            _isLoading = false;
          });
        },
        onError: (error) {
          setState(() {
            _explanation = 'Error: $error';
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _explanation = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Word Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _wordController,
              decoration: InputDecoration(
                labelText: 'Enter a word',
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
                      : const Text('Get Explanation'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
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
                      Text(
                        _explanation.isEmpty && !_isLoading
                            ? 'Explanation will appear here'
                            : _explanation,
                        style: const TextStyle(fontSize: 16),
                      ),
                      if (_isLoading && _explanation.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Center(child: CircularProgressIndicator()),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
