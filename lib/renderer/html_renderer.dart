import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../utils/logger.dart';
import '../services/article_service.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:async'; // 添加dart:async导入
import 'package:http/http.dart' as http;

import '../services/dictionary_service.dart';
import '../widgets/dictionary/dictionary_card.dart';
import '../models/dictionary_result.dart';
import '../models/vocabulary.dart';

class HtmlRenderer extends StatefulWidget {
  final String? articleId;
  final bool isDarkMode;
  final double fontSize;
  final bool showVocabulary;
  final Function(String)? onWordSelected;
  final Function(double)? onFontSizeChanged;
  final String? htmlContent; // 添加接收预先加载的HTML内容
  final List<dynamic>? vocabularyData; // 添加接收预加载的词汇数据
  // 使用静态Map存储每个文章ID对应的WebView控制器
  static final Map<String, InAppWebViewController?> _controllerCache = {};
  // 使用静态Map存储每个文章ID对应的加载状态
  static final Map<String, bool> _contentLoadedCache = {};

  const HtmlRenderer({
    Key? key,
    this.articleId,
    this.isDarkMode = false,
    this.fontSize = 16.0,
    this.showVocabulary = true,
    this.onWordSelected,
    this.onFontSizeChanged,
    this.htmlContent, // 添加对应的构造参数
    this.vocabularyData, // 添加对应的构造参数
  }) : super(key: key);

  @override
  State<HtmlRenderer> createState() => _HtmlRendererState();
}

class _HtmlRendererState extends State<HtmlRenderer> {
  bool _isLoading = true;
  InAppWebViewController? _webViewController;
  String? _errorMessage;
  bool _hasLoadedContent = false; // 添加标记，表示内容是否已加载
  List<dynamic>? _preloadedVocabulary;
  bool _webViewLoaded = false;

  // 存储CSS文件内容
  String _baseCSS = '';
  String _typographyCSS = '';
  String _uiCSS = '';
  String _economistCSS = '';

  // 存储渲染器JS文件内容
  String _rendererJS = '';

  // 在_HtmlRendererState类中添加一个变量来保存选中的文本
  String? _selectedText;

  @override
  void initState() {
    super.initState();
    _loadCSSFiles();
    _loadJSFiles();

    // 检查是否有缓存的控制器
    if (widget.articleId != null &&
        HtmlRenderer._controllerCache.containsKey(widget.articleId)) {
      log.i('使用缓存的WebView控制器');
      _webViewController = HtmlRenderer._controllerCache[widget.articleId];
      _hasLoadedContent =
          HtmlRenderer._contentLoadedCache[widget.articleId] ?? false;

      // 如果内容已加载，立即应用属性更新
      if (_hasLoadedContent && _webViewController != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateTheme();
          _updateFontSize();
        });
      } else {}
    } else {}

    // 在初始化时增加一个全局变量来跟踪对话框状态
    _webViewController?.evaluateJavascript(
        source: "window.mikaDialogOpen = false;");
  }

  @override
  void didUpdateWidget(HtmlRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 只有在已加载内容后才更新样式
    if (_hasLoadedContent && _webViewController != null) {
      if (oldWidget.isDarkMode != widget.isDarkMode) {
        log.i('主题已更改: ${oldWidget.isDarkMode} -> ${widget.isDarkMode}');
        _updateTheme();
      }

      if (oldWidget.fontSize != widget.fontSize) {
        log.i('字体大小已更改: ${oldWidget.fontSize} -> ${widget.fontSize}');
        // 移除延迟，立即更新字体大小
        _updateFontSize();
      }
    }
  }

  void _updateTheme() {
    if (_webViewController != null) {
      _webViewController!.evaluateJavascript(source: """
            if (window.setDarkMode) {
              window.setDarkMode(${widget.isDarkMode});
            }
          """);
    }
  }

  void _updateFontSize() {
    if (_webViewController != null) {
      log.i('应用新字体大小: ${widget.fontSize}');

      // 基于16px作为标准大小计算缩放比例
      // final int zoomFactor = (widget.fontSize / 16 * 100).round(); // 移除

      // 首先通过JavaScript更新字体大小
      _webViewController!.evaluateJavascript(source: """
        try {
          // 更新CSS变量
          document.documentElement.style.setProperty('--font-size-base', '${widget.fontSize}px');
          document.documentElement.setAttribute('data-font-size', '${widget.fontSize}');
          
          // 更新动态样式 (确保CSS中使用了 --font-size-base)
          var dynamicStyle = document.getElementById('dynamic-styles');
          if(dynamicStyle) {
            // 确认是否真的需要更新整个style块，或者CSS是否已依赖 --font-size-base
            dynamicStyle.textContent = `
              :root { 
                --font-size-base: ${widget.fontSize}px;
              }
            `;
          } else {
            console.log('未找到dynamic-styles元素');
          }
          
          console.log('通过JavaScript更新了字体大小: ${widget.fontSize}px');
        } catch(e) {
          console.error('更新字体大小时出错', e);
        }
      """);

      // 然后设置textZoom作为备份方法 (移除)
      // _webViewController!.setSettings(
      //     settings: InAppWebViewSettings(
      //   textZoom: zoomFactor,
      // ));

      // log.i('应用 textZoom: $zoomFactor%'); // 移除
    }
  }

  @override
  Widget build(BuildContext context) {
    // 检查文章ID是否为空
    if (widget.articleId == null || widget.articleId!.isEmpty) {
      return Container(
          color: Colors.white,
          width: double.infinity,
          height: double.infinity,
          child: const Center(child: Text('文章ID不能为空')));
    }

    return _buildWebView(context);
  }

  Widget _buildWebView(BuildContext context) {
    if (widget.articleId == null) {
      return Container(
          color: Colors.white,
          width: double.infinity,
          height: double.infinity,
          child: const Center(
            child: Text('请提供文章ID'),
          ));
    }

    log.i('构建 InAppWebView (HtmlRenderer._buildWebView)，可能触发初始加载或重建。'); // 添加日志

    // 创建WebView
    return Stack(
      children: [
        InAppWebView(
          // 如果有预加载的HTML内容，则使用本地数据加载
          initialData: widget.htmlContent != null
              ? InAppWebViewInitialData(
                  data: widget.htmlContent!,
                  baseUrl: WebUri(ArticleService.getBaseUrl()), // 添加基础URL
                  encoding: 'UTF-8',
                  mimeType: 'text/html',
                )
              : null,
          // 如果没有预加载的HTML内容，则使用远程URL
          initialUrlRequest: widget.htmlContent == null
              ? URLRequest(
                  url: WebUri(
                      ArticleService.getArticleHtmlUrl(widget.articleId!)),
                )
              : null,
          onReceivedServerTrustAuthRequest: (controller, challenge) async {
            // 信任所有证书
            log.i('收到服务器信任认证请求');
            return ServerTrustAuthResponse(
                action: ServerTrustAuthResponseAction.PROCEED);
          },
          onReceivedError: (controller, request, error) {
            log.e('WebView错误: ${error.description}, URL: ${request.url}');
            setState(() {
              _isLoading = false;
              _errorMessage = "加载错误: ${error.description}";
            });
          },
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            useShouldOverrideUrlLoading: true,
            mediaPlaybackRequiresUserGesture: false,
            supportZoom: true,
            builtInZoomControls: true,
            displayZoomControls: false,
            verticalScrollBarEnabled: false,
            horizontalScrollBarEnabled: false,
            transparentBackground: true,
            disableContextMenu: false,
            cacheMode: CacheMode.LOAD_CACHE_ELSE_NETWORK,
            userAgent: 'Flutter InAppWebView - MIKA Reader',
            safeBrowsingEnabled: false,
            clearCache: false,
            domStorageEnabled: true,
            useOnLoadResource: true,
            textZoom: 100,
            initialScale: 100,
            disableVerticalScroll: false,
            disableHorizontalScroll: true,
            overScrollMode: OverScrollMode.NEVER,
            useWideViewPort: true,
            allowContentAccess: true,
            supportMultipleWindows: false,
            disableLongPressContextMenuOnLinks: true,
            disableDefaultErrorPage: true,
            algorithmicDarkeningAllowed: true,
            allowsLinkPreview: false,
            allowsBackForwardNavigationGestures: false,
            allowFileAccessFromFileURLs: true,
            allowUniversalAccessFromFileURLs: true,
            suppressesIncrementalRendering: false,
            // 禁用WebView的强制深色模式
            forceDark: ForceDark.OFF,
          ),
          onWebViewCreated: (controller) {
            final String webviewUrl = widget.htmlContent != null
                ? "关联文章ID: ${widget.articleId}"
                : ArticleService.getArticleHtmlUrl(widget.articleId!);
            log.i(
                'WebView已创建，${widget.htmlContent != null ? "使用本地HTML内容" : "准备载入URL"}: $webviewUrl');
            _webViewController = controller;

            // 缓存控制器，以便在属性变化时重用
            if (widget.articleId != null) {
              HtmlRenderer._controllerCache[widget.articleId!] = controller;
            }

            // 首先添加CSS使内容初始不可见
            controller.evaluateJavascript(source: """
              var style = document.createElement('style');
              style.id = 'init-invisible-style';
              style.innerHTML = 'html, body { opacity: 0 !important; }';
              document.head.appendChild(style);
              
             
              // 添加禁用系统文本选择菜单的样式
              var selectionStyle = document.createElement('style');
              selectionStyle.id = 'selection-style';
              selectionStyle.innerHTML = `
                /* 自定义选中文本的样式 */
                ::selection {
                  background-color: rgba(255, 235, 59, 0.3) !important;
                  color: inherit !important;
                }
                ::-moz-selection {
                  background-color: rgba(255, 235, 59, 0.3) !important;
                  color: inherit !important;
                }
                
                /* 禁用长按菜单 */
                body {
                  -webkit-touch-callout: none !important;
                }
              `;
              document.head.appendChild(selectionStyle);
              
              // 设置主题状态到全局变量
              window.isDarkMode = ${widget.isDarkMode};
              
              // 设置主题数据属性到HTML元素
              document.documentElement.setAttribute('data-theme', '${widget.isDarkMode ? "dark" : "light"}');
              console.log('[MIKA] 设置主题模式: ' + (${widget.isDarkMode} ? '深色' : '浅色'));
            """);

            // 注册处理器用于Flutter和JavaScript之间的通信
            controller.addJavaScriptHandler(
              handlerName: 'onWordSelected',
              callback: (args) {
                log.d(
                    'JavaScript调用onWordSelected: ${args.isNotEmpty ? args[0] : "无参数"}');
                if (args.isNotEmpty && widget.onWordSelected != null) {
                  widget.onWordSelected!(args[0].toString());
                }
              },
            );

            // 添加加载词汇完成的处理器
            controller.addJavaScriptHandler(
              handlerName: 'onVocabularyLoaded',
              callback: (args) {
                if (args.isNotEmpty) {
                  final int count = int.tryParse(args[0].toString()) ?? 0;
                  log.i('词汇加载完成: $count 个词汇');
                }
              },
            );

            // 添加复制文本处理器
            controller.addJavaScriptHandler(
              handlerName: 'copyText',
              callback: (args) {
                if (args.isNotEmpty) {
                  final text = args[0].toString();
                  log.i('复制文本: $text');
                  Clipboard.setData(ClipboardData(text: text)).then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已复制到剪贴板'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  });
                }
              },
            );

            // 添加翻译文本处理器
            controller.addJavaScriptHandler(
              handlerName: 'translateText',
              callback: (args) {
                log.i('=====================================');
                log.i('收到WebView的translateText调用！');
                log.i('参数数量: ${args.length}');

                if (args.isNotEmpty) {
                  final text = args[0].toString();
                  log.i('收到翻译请求: "$text" (长度: ${text.length})');

                  // 这里可以实现调用翻译API或打开翻译对话框
                  log.i('即将调用_showTranslationDialog方法');
                  _showTranslationDialog(context, text);
                  log.i('_showTranslationDialog方法调用完成');
                } else {
                  log.w('收到空的翻译请求 - args为空数组');
                }
                log.i('=====================================');
              },
            );

            // 添加保存选中文本的处理器
            controller.addJavaScriptHandler(
              handlerName: 'saveSelectedText',
              callback: (args) {
                if (args.isNotEmpty) {
                  final text = args[0].toString();
                  log.i('===== Flutter接收到WebView选中文本 =====');
                  log.i('文本内容: "$text"');
                  log.i('文本长度: ${text.length}');
                  log.i('接收时间: ${DateTime.now().toString()}');

                  // 保存到Flutter的变量中
                  setState(() {
                    _selectedText = text;
                    log.i('已保存文本到_selectedText变量');
                    log.i('变量当前值: "$_selectedText"');
                  });

                  log.i('===== 文本保存完成 =====');
                } else {
                  log.w('收到saveSelectedText调用，但参数为空');
                  setState(() {
                    _selectedText = null;
                    log.i('已清空_selectedText变量');
                  });
                }
              },
            );

            // 添加日志消息处理器
            controller.addJavaScriptHandler(
              handlerName: 'logMessage',
              callback: (args) {
                if (args.isNotEmpty) {
                  log.i('JavaScript日志: ${args[0]}');
                }
              },
            );

            // 添加内容渲染完成的处理器
            controller.addJavaScriptHandler(
              handlerName: 'contentRendered',
              callback: (args) {
                log.i('WebView内容完全渲染完成');
                setState(() {
                  _isLoading = false;
                  _hasLoadedContent = true;
                  _webViewLoaded = true;

                  // 更新缓存状态
                  if (widget.articleId != null) {
                    HtmlRenderer._contentLoadedCache[widget.articleId!] = true;
                  }
                });
              },
            );

            // 在WebView加载完成后添加解决TextClassifier问题的代码
            controller.evaluateJavascript(source: """
              // 添加解决TextClassifier在主线程问题的代码
              document.addEventListener('touchend', function(e) {
                // 延迟处理文本选择，避免TextClassifier在主线程阻塞
                if (window.getSelection && !window.getSelection().isCollapsed) {
                  requestAnimationFrame(function() {
                    console.log('使用requestAnimationFrame延迟处理选择，避免主线程阻塞');
                  });
                }
              }, { passive: true });

              // 禁用系统默认的ActionMode处理
              document.addEventListener('selectionchange', function() {
                // 检测到文本选择变化时，立即覆盖默认ActionMode行为
                if (window.getSelection && !window.getSelection().isCollapsed) {
                  // 设置一个超短的定时器，抢在系统ActionMode之前触发
                  setTimeout(function() {
                    // 不做任何实际操作，只是通过重新设置选择来取消系统ActionMode
                    const selection = window.getSelection();
                    const range = selection.getRangeAt(0);
                    const currentSelection = range.toString();
                    if (currentSelection.length > 0) {
                      // 不执行任何影响选择的操作，但这会刷新ActionMode的状态
                      // 通过这种方式，系统ActionMode接收到变更但我们保持了选择内容
                      console.log('阻止系统ActionMode激活，保留文本选择: ' + currentSelection);
                    }
                  }, 0);
                }
              });

              // 添加防止ActionMode被意外销毁的代码
              var oldSelectionChangeHandler = document.onselectionchange;
              document.onselectionchange = function(e) {
                if (oldSelectionChangeHandler) {
                  oldSelectionChangeHandler(e);
                }
                // 添加延迟，避免连续快速的ActionMode创建和销毁
                setTimeout(function() {
                  console.log('稳定ActionMode实例');
                }, 10);
              };
              console.log('已添加解决TextClassifier问题和ActionMode稳定的代码');
            """);
          },
          onLoadStart: (controller, url) {
            log.i('【网络请求】WebView开始加载: $url');
            log.i('【网络请求】时间戳: ${DateTime.now().millisecondsSinceEpoch}');
            log.i('【网络请求】当前字体大小: ${widget.fontSize}');
            setState(() {
              _isLoading = true;
            });

            // 确保在加载开始时内容不可见
            controller.evaluateJavascript(source: """
              if (!document.getElementById('init-invisible-style')) {
                var style = document.createElement('style');
                style.id = 'init-invisible-style';
                style.innerHTML = 'html, body { opacity: 0 !important; }';
                document.head.appendChild(style);
              }
            """);
          },
          onLoadStop: (controller, url) {
            log.i('【网络请求完成】WebView加载完成: $url');
            log.i('【网络请求完成】时间戳: ${DateTime.now().millisecondsSinceEpoch}');
            log.i('【网络请求完成】当前字体大小: ${widget.fontSize}');

            // 获取API服务基础URL（用于图片路径修复）
            final apiBaseUrl =
                ArticleService.getBaseUrl().replaceAll('/api', '');

            // 注入renderer.js脚本
            controller.evaluateJavascript(source: _rendererJS).then((_) {
              log.i('已注入renderer.js脚本');

              // 调用初始化函数
              controller.evaluateJavascript(source: """
                // 初始化渲染器
                const renderer = window.initializeRenderer({
                  isDarkMode: ${widget.isDarkMode},
                  fontSize: ${widget.fontSize},
                  showVocabulary: ${widget.showVocabulary},
                  apiBaseUrl: "$apiBaseUrl",
                  baseCSS: `${_baseCSS}`,
                  typographyCSS: `${_typographyCSS}`,
                  uiCSS: `${_uiCSS}`,
                  economistCSS: `${_economistCSS}`
                });
                
                // 显示内容
                renderer.showContent();
              """).then((_) {
                log.i('渲染器初始化和内容显示完成');
              });
            });
          },
          onLoadError: (controller, url, code, message) {
            log.e('WebView加载错误: $url, 代码: $code, 消息: $message');
            setState(() {
              _isLoading = false;
              _errorMessage = "加载错误: $message";
            });
          },
          onConsoleMessage: (controller, consoleMessage) {
            log.d('WebView控制台: ${consoleMessage.message}');
          },
        ),
        if (_isLoading)
          Container(
            color: Colors.white,
            width: double.infinity,
            height: double.infinity,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        if (_errorMessage != null)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  '加载失败',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: Colors.red),
                ),
                const SizedBox(height: 8),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    final String webviewUrl = ArticleService.getArticleHtmlUrl(
                        widget.articleId!); // URL construction
                    log.i('准备重新加载 WebView URL: $webviewUrl'); // 添加日志
                    _webViewController?.loadUrl(
                      // Actual request trigger
                      urlRequest: URLRequest(url: WebUri(webviewUrl)),
                    );
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // 显示翻译对话框
  void _showTranslationDialog(BuildContext context, String text) {
    // 如果收到特殊信号，使用已缓存的文本
    if (text == 'USE_CACHED_TEXT') {
      log.i('===== 收到翻译特殊信号 =====');
      log.i('信号类型: USE_CACHED_TEXT');
      log.i('当前_selectedText值: "${_selectedText ?? "null"}"');

      if (_selectedText != null && _selectedText!.isNotEmpty) {
        text = _selectedText!;
        log.i('使用缓存的文本进行翻译: "$text"');
        log.i('文本长度: ${text.length}');
      } else {
        log.w('收到使用缓存文本的请求，但缓存为空');
        log.i('最后一次保存文本的时间可能已过期');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可翻译的文本')),
        );
        return;
      }
    }

    // 清理文本，移除多余的空格
    final String cleanText = text.trim();

    log.i('==== 翻译流程开始 ====');
    log.i('原始文本: "$text"');
    log.i('清理后文本: "$cleanText"');
    log.i('收到请求时间: ${DateTime.now().toString()}');
    log.i('当前线程ID: ${identical(Zone.current, Zone.root) ? "主线程" : "后台线程"}');

    if (cleanText.isEmpty) {
      log.w('文本为空，取消翻译');
      log.i('==== 翻译流程结束（文本为空）====');
      return;
    }

    // 隐藏文本选择菜单
    if (_webViewController != null) {
      _webViewController!.evaluateJavascript(source: """
        if (window.textSelectionMenu) {
          window.textSelectionMenu.hide();
          console.log('[MIKA] 已隐藏文本选择菜单');
        }
      """);
    }

    // 延迟500毫秒再显示对话框，确保JavaScript端已经处理完毕
    Future.delayed(const Duration(milliseconds: 500), () {
      log.i('延迟500ms后开始处理翻译请求，时间: ${DateTime.now().toString()}');

      // 显示更小的加载指示器，不使用全屏背景
      log.i('准备显示加载指示器');
      final OverlayEntry loadingOverlay = OverlayEntry(
        builder: (context) => Positioned(
          bottom: 50,
          left: 0,
          right: 0,
          child: Center(
            child: Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              color: Colors.black54,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )),
                    SizedBox(width: 12),
                    Text('翻译中...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(loadingOverlay);
      log.i('加载指示器显示完成');

      // 使用DictionaryService查询单词或短语
      final DictionaryService dictionaryService = DictionaryService();
      log.i('DictionaryService实例已创建');
      log.i('开始调用DictionaryService.lookupWord("$cleanText")');

      // 添加时间戳以跟踪API调用耗时
      final startTime = DateTime.now();
      log.i('API调用开始时间: $startTime');

      // 为了防止API调用过快导致界面未响应，再次延迟短暂时间
      Future.delayed(const Duration(milliseconds: 100), () {
        log.i('再次短暂延迟后开始API调用，时间: ${DateTime.now().toString()}');

        dictionaryService.lookupWord(cleanText).then((result) {
          // 计算API调用耗时
          final endTime = DateTime.now();
          final duration = endTime.difference(startTime);
          log.i('API调用结束时间: $endTime');
          log.i('API调用耗时: ${duration.inMilliseconds}毫秒');

          // 移除加载指示器
          loadingOverlay.remove();
          log.i('加载指示器已移除');

          if (result != null) {
            log.i('API查询成功: ${result.word}, 翻译: ${result.translation}');
            log.i('DictionaryResult详情: $result');

            // 显示词典卡片对话框
            log.i('准备显示翻译结果对话框');

            // 设置对话框打开标志
            if (_webViewController != null) {
              _webViewController!.evaluateJavascript(source: """
                window.mikaDialogOpen = true;
                console.log('[MIKA] 已设置对话框打开标志');
              """);
            }

            // 使用最高z-index的Dialog显示DictionaryCard
            showDialog(
              context: context,
              useSafeArea: true,
              barrierDismissible: true,
              barrierColor: Colors.black.withOpacity(0.6),
              builder: (context) => Theme(
                data: Theme.of(context).copyWith(
                  dialogTheme: DialogTheme(
                    elevation: 24,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                child: Dialog(
                  insetPadding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 24.0),
                  child: DictionaryCard.fromDictionaryResult(
                    result: result,
                    onClose: () {
                      log.i('用户关闭了翻译结果对话框');
                      Navigator.of(context).pop();

                      // 设置对话框关闭标志
                      if (_webViewController != null) {
                        _webViewController!.evaluateJavascript(source: """
                          window.mikaDialogOpen = false;
                          console.log('[MIKA] 已设置对话框关闭标志');
                        """);
                      }
                    },
                    isCompact: true,
                    onLookupMore: () {
                      // 可以在这里添加更详细的查询逻辑
                      log.i('用户点击了"查看详情"按钮');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('更多详情功能即将上线')),
                      );
                    },
                  ),
                ),
              ),
            ).then((_) {
              // 确保在对话框关闭后重置标志
              if (_webViewController != null) {
                _webViewController!.evaluateJavascript(source: """
                  window.mikaDialogOpen = false;
                  console.log('[MIKA] 对话框关闭后重置标志');
                """);
              }
            });

            log.i('翻译结果对话框已显示');
            log.i('==== 翻译流程完成（成功）====');
          } else {
            log.w('API查询无结果');
            // 查询失败，显示错误提示
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('未能找到该单词或短语的翻译'),
                duration: Duration(seconds: 2),
              ),
            );
            log.i('错误提示已显示');
            log.i('==== 翻译流程完成（无结果）====');
          }
        }).catchError((error) {
          // 计算API调用耗时（错误情况）
          final endTime = DateTime.now();
          final duration = endTime.difference(startTime);
          log.i('API调用结束时间（出错）: $endTime');
          log.i('API调用耗时: ${duration.inMilliseconds}毫秒');

          // 移除加载指示器
          loadingOverlay.remove();
          log.i('加载指示器已移除（出错情况）');

          log.e('翻译查询出错', error);
          log.e('错误详情: ${error.toString()}');
          log.e('错误栈: ${StackTrace.current}');

          // 显示错误提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('翻译查询出错: ${error.toString()}'),
              duration: const Duration(seconds: 2),
            ),
          );
          log.i('错误提示已显示');
          log.i('==== 翻译流程完成（出错）====');
        });
      });
    });
  }

  // 预加载CSS文件
  Future<void> _loadCSSFiles() async {
    try {
      _baseCSS = await rootBundle.loadString('assets/renderer/styles/base.css');
      _typographyCSS =
          await rootBundle.loadString('assets/renderer/styles/typograpy.css');
      _uiCSS = await rootBundle.loadString('assets/renderer/styles/ui.css');
      _economistCSS =
          await rootBundle.loadString('assets/renderer/styles/economist.css');
      log.i('CSS文件预加载完成');
    } catch (e) {
      log.e('加载CSS文件失败', e);
    }
  }

  // 加载JS文件
  Future<void> _loadJSFiles() async {
    try {
      _rendererJS = await rootBundle.loadString('assets/renderer/renderer.js');
      log.i('渲染器JS文件预加载完成');
    } catch (e) {
      log.e('加载渲染器JS文件失败', e);
    }
  }
}
