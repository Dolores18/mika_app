// lib/pages/word_search_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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

  @override
  void initState() {
    super.initState();
    log.i('初始化WordSearchPage，查询单词: ${widget.word}');

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
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      body: Column(
        children: [
          // 顶部状态栏占位
          SizedBox(height: topPadding),

          // 页面头部
          _buildHeader(),

          // WebView内容区域
          Expanded(
            child: _buildWebViewContent(),
          ),
        ],
      ),
    );
  }

  // 构建页面头部
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
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
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '返回',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 20,
          ),

          const SizedBox(width: 8),

          // 标题和单词
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title ?? '日语词典',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.word,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6b4bbd),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 加载状态指示器
          if (_isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  // 构建WebView内容
  Widget _buildWebViewContent() {
    if (_error != null) {
      return _buildErrorContent();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(
                'https://language.3049589.xyz/api/japanese/html/${Uri.encodeComponent(widget.word)}'),
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            // 稳定性优化
            supportZoom: false,
            verticalScrollBarEnabled: false,
            horizontalScrollBarEnabled: false,
            // 内存和性能优化 - 参考 html_renderer.dart 的设置
            cacheMode: CacheMode.LOAD_CACHE_ELSE_NETWORK,
            forceDark: ForceDark.OFF,
            clearCache: false, // 关键：不清除缓存
            // 内存管理 - 参考 html_renderer.dart 的设置
            allowFileAccess: true,
            allowContentAccess: true,
            allowFileAccessFromFileURLs: true,
            allowUniversalAccessFromFileURLs: true,
            // 滚动优化
            scrollBarDefaultDelayBeforeFade: 0,
            scrollBarFadeDuration: 0,
            // 性能优化
            loadWithOverviewMode: true,
            useWideViewPort: true,
            // 其他稳定性设置
            domStorageEnabled: true,
            useOnLoadResource: true,
            disableDefaultErrorPage: true,
            algorithmicDarkeningAllowed: true,
          ),
          onWebViewCreated: (controller) {
            log.i('日语词典WebView已创建');
            _webViewController = controller;

            // 设置WebView错误处理
            controller.addJavaScriptHandler(
              handlerName: 'errorHandler',
              callback: (args) {
                log.e('JavaScript错误: $args');
              },
            );
          },
          onLoadStart: (controller, url) {
            log.i('日语词典WebView开始加载: $url');
            setState(() {
              _isLoading = true;
              _error = null;
            });
          },
          onLoadStop: (controller, url) {
            log.i('日语词典WebView加载完成: $url');
            setState(() {
              _isLoading = false;
            });

            // 注入优化脚本 - 参考 html_renderer.dart 的方式
            controller.evaluateJavascript(source: """
              try {
                // 隐藏滚动条
                var style = document.createElement('style');
                style.id = 'mika-scrollbar-style';
                style.textContent = '::-webkit-scrollbar { display: none; } * { scrollbar-width: none; }';
                document.head.appendChild(style);
                
                // 优化触摸体验
                document.body.style.webkitTouchCallout = 'none';
                document.body.style.webkitUserSelect = 'none';
                document.body.style.touchAction = 'manipulation';
                
                // 允许文本选择
                var textElements = document.querySelectorAll('p, span, div');
                for (var i = 0; i < textElements.length; i++) {
                  textElements[i].style.webkitUserSelect = 'text';
                }
                
                // 设置初始样式使内容可见
                document.body.style.opacity = '1';
                
                console.log('日语WebView优化完成');
              } catch (e) {
                console.error('优化脚本执行失败:', e);
                // 发送错误到Flutter
                if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                  window.flutter_inappwebview.callHandler('errorHandler', e.message);
                }
              }
            """);
          },
          onReceivedError: (controller, request, error) {
            log.e('日语词典WebView错误: ${error.description}');
            setState(() {
              _isLoading = false;
              _error = error.description;
            });
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            // 阻止导航到外部链接
            final url = navigationAction.request.url.toString();
            if (url.contains('search-page') || url.startsWith('http')) {
              log.i('阻止导航到: $url');
              return NavigationActionPolicy.CANCEL;
            }
            return NavigationActionPolicy.ALLOW;
          },
        ),
      ),
    );
  }

  // 构建错误内容
  Widget _buildErrorContent() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
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
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '未知错误',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _error = null;
                _isLoading = true;
              });
              // 重新加载
              _webViewController?.reload();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6b4bbd),
              foregroundColor: Colors.white,
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
    // 清理WebView资源 - 不清除缓存，参考 html_renderer.dart
    _webViewController?.dispose();

    // 恢复系统UI设置
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }
}
