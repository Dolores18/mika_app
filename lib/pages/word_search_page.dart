// lib/pages/word_search_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class WordSearchPage extends StatefulWidget {
  final String word;
  final String? title;

  const WordSearchPage({
    super.key,
    required this.word,
    this.title,
  });

  @override
  State<WordSearchPage> createState() => _WordSearchPageState();
}

class _WordSearchPageState extends State<WordSearchPage> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  String? _error;
  String? _preparedHtml;

  @override
  void initState() {
    super.initState();
    log.i('初始化WordSearchPage，查询单词: ${widget.word}');
    _loadAndPrepareContent();
  }

  Future<void> _loadAndPrepareContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. 获取远程HTML
      final url = Uri.parse(
          'https://language.3049589.xyz/api/japanese/html/${Uri.encodeComponent(widget.word)}');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw http.ClientException(
            'Failed to load HTML: ${response.statusCode}');
      }
      String originalHtml = utf8.decode(response.bodyBytes);

      // 2. 加载本地CSS
      final localCss =
          await rootBundle.loadString('assets/dict/ja/gystyle.css');

      // 3. 修改HTML：移除远程CSS链接，并内联本地CSS
      String modifiedHtml = originalHtml.replaceAll(
          '<link rel="stylesheet" href="/static/obunsha/gystyle.css">', '');

      modifiedHtml = modifiedHtml.replaceFirst(
        '</head>',
        '<style>$localCss</style></head>',
      );

      setState(() {
        _preparedHtml = modifiedHtml;
        // HTML准备好后，WebView会加载，但我们仍然认为加载中，直到onLoadStop触发
      });
    } catch (e) {
      log.e('准备WebView内容失败: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSystemUIOverlayStyle();
  }

  void _updateSystemUIOverlayStyle() {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            brightness == Brightness.dark ? Brightness.dark : Brightness.light,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          SizedBox(height: topPadding),
          _buildHeader(),
          Expanded(
            child: _buildWebViewContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withOpacity(0.9),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios,
                size: 20, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '返回',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title ?? '日语词典',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.word,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_isLoading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebViewContent() {
    if (_error != null) {
      return _buildErrorContent();
    }

    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final bgColorHex =
        '#${bgColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    final textColorHex =
        theme.brightness == Brightness.dark ? '#E0E0E0' : '#212121';
    final linkColorHex =
        theme.brightness == Brightness.dark ? '#9D82E8' : '#6b4bbd';

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _preparedHtml == null
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : InAppWebView(
                initialData: InAppWebViewInitialData(data: _preparedHtml!),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  supportZoom: false,
                  verticalScrollBarEnabled: false,
                  horizontalScrollBarEnabled: false,
                  forceDark: ForceDark.OFF,
                  algorithmicDarkeningAllowed: false,
                  // 其他优化设置
                  allowFileAccess: true,
                  loadWithOverviewMode: true,
                  useWideViewPort: true,
                  domStorageEnabled: true,
                  disableDefaultErrorPage: true,
                ),
                onWebViewCreated: (controller) {
                  log.i('日语词典WebView已创建');
                  _webViewController = controller;
                },
                onLoadStop: (controller, url) {
                  log.i('日语词典WebView加载完成: $url');
                  setState(() {
                    _isLoading = false;
                  });

                  // HTML已包含基础样式，这里只注入动态的主题颜色
                  controller.evaluateJavascript(source: '''
              (function() {
                try {
                  var themeStyle = document.createElement('style');
                  themeStyle.id = 'mika-theme-style';
                  themeStyle.innerHTML = `
                    :root {
                      --mika-bg-color: ${bgColorHex};
                      --mika-text-color: ${textColorHex};
                      --mika-link-color: ${linkColorHex};
                    }
                    body, .main, .wrap, #main, #wrap, .container {
                      background-color: var(--mika-bg-color) !important;
                    }
                    * {
                       color: var(--mika-text-color) !important;
                    }
                    a, a * {
                      color: var(--mika-link-color) !important;
                      text-decoration: none !important;
                    }
                  `;
                  document.head.appendChild(themeStyle);
                  console.log('主题样式已注入');
                } catch (e) {
                  console.error('注入主题脚本失败:', e);
                }
              })();
            ''');
                },
                onReceivedError: (controller, request, error) {
                  log.e('日语词典WebView错误: ${error.description}');
                  setState(() {
                    _isLoading = false;
                    _error = error.description;
                  });
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  return NavigationActionPolicy.CANCEL;
                },
              ),
      ),
    );
  }

  Widget _buildErrorContent() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '未知错误',
            style: TextStyle(
              fontSize: 14,
              color: theme.textTheme.bodyMedium?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadAndPrepareContent,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.colorScheme.onSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }
}
