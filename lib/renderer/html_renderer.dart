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
import '../server/local_server.dart'; // 添加本地服务器导入
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

  // 在_HtmlRendererState类中添加一个变量来保存选中的文本
  String? _selectedText;

  @override
  void initState() {
    super.initState();
    _loadCSSFiles();

    // 记录初始化时是否有预加载的词汇数据
    if (widget.vocabularyData != null) {
      log.i('HtmlRenderer初始化时收到预加载词汇数据: ${widget.vocabularyData!.length} 个词汇');
      if (widget.vocabularyData!.isNotEmpty) {
        log.i('预加载词汇示例: ${widget.vocabularyData![0]}');
      }
    } else {
      log.w('HtmlRenderer初始化时没有收到预加载词汇数据');
    }

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
          _updateVocabulary();

          // 如果有预加载的词汇数据，应用它
          if (widget.vocabularyData != null &&
              widget.vocabularyData!.isNotEmpty) {
            log.i('使用控制器缓存，应用预加载词汇数据: ${widget.vocabularyData!.length} 个词汇');
            _preloadedVocabulary = widget.vocabularyData;
            _applyPreloadedVocabulary();
          } else {
            log.w('使用控制器缓存，但没有预加载词汇数据');
          }
        });
      } else {
        _initializeWebViewAndLoadData();
      }
    } else {
      _initializeWebViewAndLoadData();
    }
  }

  @override
  void dispose() {
    // 不要在dispose中释放控制器，让它保持在缓存中
    super.dispose();
  }

  void _initializeWebViewAndLoadData() async {
    // 确保本地服务器已启动
    try {
      log.i('确保本地服务器已启动');
      // LocalServer.start() 会返回服务器的基础URL
      await LocalServer.start();

      // 使用预加载的词汇数据
      if (widget.showVocabulary && widget.vocabularyData != null) {
        _preloadedVocabulary = widget.vocabularyData;
        log.i('使用预加载的词汇数据: ${_preloadedVocabulary?.length ?? 0} 个词汇');
        if (_preloadedVocabulary != null && _preloadedVocabulary!.isNotEmpty) {
          log.i('预加载词汇示例[0]: ${_preloadedVocabulary![0]}');
          // 打印原始词汇数据结构
          log.i('词汇数据结构检查: ${_preloadedVocabulary!.runtimeType}');
        } else {
          log.w('预加载词汇数据为空');
        }
      } else {
        log.w(
            '未使用预加载词汇数据: showVocabulary=${widget.showVocabulary}, vocabularyData=${widget.vocabularyData != null}');
      }
    } catch (e) {
      log.e('启动本地服务器失败', e);
    }
  }

  // 预加载词汇数据
  void _preloadVocabularyData() async {
    try {
      // 构建API请求URL
      final apiUrl = '/api/articles/${widget.articleId}/with_analysis';

      // 记录开始预加载词汇数据
      log.i('开始预加载词汇数据：$apiUrl');

      // 创建HTTP客户端实例
      final client = http.Client();

      // 发起请求获取文章分析数据（包含词汇）
      final response = await client.get(
        Uri.parse('http://127.0.0.1:8000$apiUrl'),
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        },
      );

      if (response.statusCode == 200) {
        // 解析响应数据
        final data = jsonDecode(response.body);

        // 提取词汇数据
        if (data != null &&
            data['analysis'] != null &&
            data['analysis']['vocabulary'] != null) {
          _preloadedVocabulary = data['analysis']['vocabulary'];
          log.i('词汇数据预加载成功: ${_preloadedVocabulary?.length ?? 0} 个词汇');

          // 检查WebView是否已加载完成，如果已完成则立即应用词汇
          if (_webViewLoaded && _webViewController != null) {
            _applyPreloadedVocabulary();
          }
        } else {
          log.w('词汇数据格式不正确或为空');
        }
      } else {
        log.e('预加载词汇数据失败: HTTP ${response.statusCode}');
      }
    } catch (e) {
      log.e('预加载词汇数据时出错', e);
    }
  }

  // 将预加载的词汇数据应用到WebView
  void _applyPreloadedVocabulary() {
    if (_preloadedVocabulary == null || _webViewController == null) {
      log.w(
          '无法应用预加载词汇: _preloadedVocabulary=${_preloadedVocabulary != null}, _webViewController=${_webViewController != null}');
      return;
    }

    log.i('开始应用预加载的词汇数据: ${_preloadedVocabulary!.length} 个词汇');

    try {
      // 将词汇数据转换为JSON字符串
      final vocabularyJson = jsonEncode(_preloadedVocabulary);
      log.i('词汇数据JSON长度: ${vocabularyJson.length}');

      if (vocabularyJson.length > 100) {
        log.i('词汇JSON预览: ${vocabularyJson.substring(0, 100)}...');
      } else {
        log.i('词汇JSON完整内容: $vocabularyJson');
      }

      // 将词汇数据传递给WebView
      _webViewController!.evaluateJavascript(source: """
        console.log('开始处理预加载词汇数据（从缓存控制器）: ${_preloadedVocabulary!.length} 个词汇');
        if (window.processPreloadedVocabulary) {
          console.log('找到 processPreloadedVocabulary 函数，开始处理词汇');
          window.processPreloadedVocabulary($vocabularyJson);
          console.log('词汇处理完成');
        } else {
          console.error('processPreloadedVocabulary函数未定义');
        }
      """).then((value) {
        log.i('词汇数据JavaScript处理完成: $value');
      }).catchError((error) {
        log.e('词汇数据JavaScript处理错误', error);
      });
    } catch (e) {
      log.e('应用预加载词汇数据时出错', e);
    }
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

      if (oldWidget.showVocabulary != widget.showVocabulary) {
        log.i(
            '词汇高亮已更改: ${oldWidget.showVocabulary} -> ${widget.showVocabulary}');
        _updateVocabulary();
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
      final int zoomFactor = (widget.fontSize / 16 * 100).round();

      // 首先通过JavaScript更新字体大小
      _webViewController!.evaluateJavascript(source: """
        try {
          // 更新CSS变量
          document.documentElement.style.setProperty('--font-size-base', '${widget.fontSize}px');
          document.documentElement.setAttribute('data-font-size', '${widget.fontSize}');
          
          // 更新动态样式
          var dynamicStyle = document.getElementById('dynamic-styles');
          if(dynamicStyle) {
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

      // 然后设置textZoom作为备份方法
      _webViewController!.setSettings(
          settings: InAppWebViewSettings(
        textZoom: zoomFactor,
      ));

      log.i('应用 textZoom: $zoomFactor%');
    }
  }

  void _updateVocabulary() {
    if (_webViewController != null) {
      _webViewController!.evaluateJavascript(source: """
            if (window.highlightVocabulary) {
              window.highlightVocabulary(${widget.showVocabulary});
            }
          """);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 检查文章ID是否为空
    if (widget.articleId == null || widget.articleId!.isEmpty) {
      return const Center(child: Text('文章ID不能为空'));
    }

    return _buildWebView(context);
  }

  Widget _buildWebView(BuildContext context) {
    if (widget.articleId == null) {
      return const Center(
        child: Text('请提供文章ID'),
      );
    }

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
              
              // 添加词汇高亮样式
              var vocabStyle = document.createElement('style');
              vocabStyle.id = 'vocabulary-style';
              vocabStyle.innerHTML = `
                .vocabulary-word {
                  background-color: ${widget.showVocabulary ? '#fff59d' : 'transparent'} !important;
                  color: ${widget.showVocabulary ? '#000' : 'inherit'} !important;
                  border-radius: 2px !important;
                  cursor: pointer !important;
                  padding: 0 2px !important;
                  margin: 0 -2px !important;
                  transition: all 0.2s ease !important;
                  display: inline-block !important;
                }
                
                .vocabulary-word:hover {
                  background-color: #ffd54f !important;
                  box-shadow: 0 1px 2px rgba(0,0,0,0.1) !important;
                }
              `;
              document.head.appendChild(vocabStyle);
              
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
            log.i('WebView开始加载: $url');
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
            log.i('WebView加载完成: $url');

            // 获取API服务基础URL（用于图片路径修复）
            final apiBaseUrl =
                ArticleService.getBaseUrl().replaceAll('/api', '');

            // 设置主题属性到HTML元素上，供JavaScript读取
            final isDarkModeStr = widget.isDarkMode ? 'dark' : 'light';
            controller.evaluateJavascript(
                source: r"""
              // 设置数据属性，让JavaScript可以访问主题模式
              document.documentElement.setAttribute('data-theme', 'DARK_MODE_PLACEHOLDER');
              console.log('[MIKA] 已设置主题模式属性: data-theme=DARK_MODE_PLACEHOLDER');
              
              // 将主题状态和其他配置设置为全局变量
              window.appConfig = {
                isDarkMode: IS_DARK_MODE_PLACEHOLDER,
                fontSize: FONT_SIZE_PLACEHOLDER,
                showVocabulary: SHOW_VOCABULARY_PLACEHOLDER
              };
              console.log('[MIKA] 已设置全局配置对象');
            """
                    .replaceAll('DARK_MODE_PLACEHOLDER', isDarkModeStr)
                    .replaceAll('IS_DARK_MODE_PLACEHOLDER',
                        widget.isDarkMode.toString())
                    .replaceAll(
                        'FONT_SIZE_PLACEHOLDER', widget.fontSize.toString())
                    .replaceAll('SHOW_VOCABULARY_PLACEHOLDER',
                        widget.showVocabulary.toString()));

            // 注入CSS并处理文档配置
            controller.evaluateJavascript(source: """
              // 确保内容在样式应用前不可见
              if (!document.getElementById('init-invisible-style')) {
                var style = document.createElement('style');
                style.id = 'init-invisible-style';
                style.innerHTML = 'html, body { opacity: 0 !important; transition: opacity 0.3s ease; }';
                document.head.appendChild(style);
              }
              
              // 处理所有图片，防止它们阻塞页面渲染
              (function prepareImages() {
                const images = document.querySelectorAll('img');
                console.log('处理图片延迟加载: 发现 ' + images.length + ' 张图片');
                
                for (let i = 0; i < images.length; i++) {
                  const img = images[i];
                  const src = img.getAttribute('src');
                  
                  if (src && !src.startsWith('data:')) {
                    // 保存原始src
                    img.setAttribute('data-src', src);
                    
                    // 设置宽高属性，避免布局跳动
                    if (!img.getAttribute('width') && !img.getAttribute('height')) {
                      if (img.naturalWidth && img.naturalHeight) {
                        img.setAttribute('width', img.naturalWidth);
                        img.setAttribute('height', img.naturalHeight);
                      } else {
                        // 设置默认宽高比
                        img.style.aspectRatio = '16/9';
                      }
                    }
                    
                    // 替换为占位符
                    img.setAttribute('src', 'data:image/svg+xml;charset=utf-8,%3Csvg xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22 viewBox%3D%220 0 1 1%22%2F%3E');
                    
                    // 设置背景色
                    img.style.backgroundColor = '${widget.isDarkMode ? "#333" : "#f0f0f0"}';
                  }
                }
              })();
              
              // 检查并准备所有图片路径
              (function prepareImagePaths() {
                const apiBaseUrl = "$apiBaseUrl";
                console.log('准备图片路径: 使用基础URL ' + apiBaseUrl);
                
                const images = document.querySelectorAll('img[data-src]');
                let preparedCount = 0;
                
                for (let i = 0; i < images.length; i++) {
                  const img = images[i];
                  const src = img.getAttribute('data-src');
                  
                  if (src && !src.startsWith('http') && !src.startsWith('data:') && !src.startsWith('//')) {
                    // 修复相对路径
                    const newSrc = src.startsWith('/') 
                      ? apiBaseUrl + src 
                      : apiBaseUrl + '/' + src;
                    
                    img.setAttribute('data-fixed-src', newSrc);
                    preparedCount++;
                  } else if (src) {
                    img.setAttribute('data-fixed-src', src);
                  }
                }
                
                console.log('图片路径准备完成: 共 ' + preparedCount + ' 个图片路径已修复');
              })();
              
              // 添加全局滚动事件处理，解决文本选择与滚动冲突
              (function setupScrollHandler() {
                let isScrolling = false;
                let scrollTimeout;
                
                // 滚动开始时禁用文本选择
                document.addEventListener('scroll', function() {
                  clearTimeout(scrollTimeout);
                  
                  if (!isScrolling) {
                    isScrolling = true;
                    
                    // 隐藏任何已显示的文本选择菜单
                    if (window.textSelectionMenu) {
                      window.textSelectionMenu.hide();
                    }
                    
                    // 禁用文本选择，防止在滚动时意外选择
                    document.body.style.userSelect = 'none';
                    document.body.style.webkitUserSelect = 'none';
                  }
                  
                  // 滚动停止后一段时间恢复文本选择功能
                  scrollTimeout = setTimeout(function() {
                    isScrolling = false;
                    document.body.style.userSelect = 'text';
                    document.body.style.webkitUserSelect = 'text';
                    console.log('滚动停止，恢复文本选择');
                  }, 300);
                }, { passive: true });
                
                console.log('滚动处理器已设置，将在滚动时暂时禁用文本选择');
              })();
              
              // 添加CSS样式
              var baseStyles = document.getElementById('base-styles');
              if (!baseStyles) {
                // 添加基础样式
                var baseStyle = document.createElement('style');
                baseStyle.id = 'base-style';
                baseStyle.textContent = `${_baseCSS}`;
                document.head.appendChild(baseStyle);
                
                // 添加排版样式
                var typographyStyle = document.createElement('style');
                typographyStyle.id = 'typography-style';
                typographyStyle.textContent = `${_typographyCSS}`;
                document.head.appendChild(typographyStyle);
                
                // 添加UI样式
                var uiStyle = document.createElement('style');
                uiStyle.id = 'ui-style';
                uiStyle.textContent = `${_uiCSS}`;
                document.head.appendChild(uiStyle);
                
                // 添加经济学人样式
                var economistStyle = document.createElement('style');
                economistStyle.id = 'economist-style';
                economistStyle.textContent = `${_economistCSS}`;
                document.head.appendChild(economistStyle);
                
                // 添加动态配置样式
                const cssContent = document.createElement('style');
                cssContent.id = 'dynamic-styles';
                cssContent.textContent = `
                  :root { 
                    --font-size-base: ${widget.fontSize}px;
                  }
                `;
                document.head.appendChild(cssContent);
              }
              
              // 修改文档属性来控制主题和词汇显示
              document.documentElement.setAttribute('data-theme', '${widget.isDarkMode ? 'dark' : 'light'}');
              document.documentElement.setAttribute('data-show-vocabulary', '${widget.showVocabulary}');
              document.documentElement.setAttribute('data-font-size', '${widget.fontSize}');
              document.documentElement.style.setProperty('--font-size-base', '${widget.fontSize}px');
              
              // 注入JS函数来更新主题
              window.setDarkMode = function(isDark) {
                document.documentElement.setAttribute('data-theme', isDark ? 'dark' : 'light');
              };
              
              // 注入JS函数来更新词汇显示
              window.highlightVocabulary = function(show) {
                document.documentElement.setAttribute('data-show-vocabulary', show);
                // 更新词汇元素样式已经通过CSS处理，无需JavaScript
              };
              
              // 添加词汇点击处理
              document.addEventListener('click', function(e) {
                // 检查是否点击了词汇元素
                if (e.target && e.target.classList && e.target.classList.contains('vocabulary-word')) {
                  e.preventDefault();
                  e.stopPropagation();
                  const word = e.target.getAttribute('data-word');
                  console.log('词汇点击:', word);
                  
                  // 调用Flutter处理函数
                  if (window.flutter_inappwebview && word) {
                    window.flutter_inappwebview.callHandler('onWordSelected', word);
                  }
                }
              });
              
              // 添加viewport元标签确保适当缩放
              var viewportMeta = document.createElement('meta');
              viewportMeta.name = 'viewport';
              viewportMeta.content = 'width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes, viewport-fit=cover';
              document.head.appendChild(viewportMeta);
              
              // 添加禁用系统文本选择菜单的CSS
              var disableSelectionMenuStyle = document.createElement('style');
              disableSelectionMenuStyle.textContent = `
                /* 禁用默认的文本选择行为 */
                * {
                  -webkit-touch-callout: none;
                  -webkit-user-select: text;
                  -khtml-user-select: text;
                  -moz-user-select: text;
                  -ms-user-select: text;
                  user-select: text;
                }
                
                /* 确保文本仍然可选，但禁用默认菜单 */
                ::selection {
                  background: #ffeb3b40;
                  color: inherit;
                }
              `;
              document.head.appendChild(disableSelectionMenuStyle);
              
              // 移除所有已有的样式表
              Array.from(document.querySelectorAll('link[rel="stylesheet"], style')).forEach(sheet => {
                if (!sheet.hasAttribute('data-mika-custom') && 
                    sheet.id !== 'init-invisible-style' && 
                    sheet.id !== 'base-style' && 
                    sheet.id !== 'typography-style' && 
                    sheet.id !== 'ui-style' && 
                    sheet.id !== 'economist-style' && 
                    sheet.id !== 'dynamic-styles') {
                  sheet.disabled = true;
                  sheet.remove();
                }
              });
              
              // 创建自定义文本选择菜单
              const createTextSelectionMenu = function() {
                console.log('[MIKA] 创建自定义文本选择菜单');
                
                // 创建一个全局变量来保存当前选中的文本
                window.currentSelectedText = '';
                
                // 获取当前主题，从全局配置或数据属性
                const isDarkMode = window.appConfig ? window.appConfig.isDarkMode : (document.documentElement.getAttribute('data-theme') === 'dark');
                console.log('[MIKA] 检测到的主题模式: ' + (isDarkMode ? '深色' : '浅色'));
                
                // 创建菜单元素
                const menu = document.createElement('div');
                menu.id = 'text-selection-menu';
                menu.style.cssText = `
                  position: fixed !important;
                  z-index: 99999 !important;
                  background-color: #ffffff !important;
                  border: 1px solid #e0e0e0 !important;
                  border-radius: 8px !important;
                  box-shadow: 0 4px 12px rgba(0,0,0,0.15) !important;
                  padding: 8px !important;
                  display: none;
                  opacity: 1 !important;
                  visibility: visible !important;
                  transform: translate(-50%, 0) !important; /* 只在水平方向居中 */
                  transition: transform 0.15s ease-out !important;
                `;
                
                // 创建复制按钮
                const copyBtn = document.createElement('button');
                copyBtn.textContent = '复制';
                copyBtn.style.cssText = `
                  background-color: #f5f5f5 !important;
                  color: #000000 !important;
                  border: none !important;
                  border-radius: 4px !important;
                  padding: 8px 12px !important;
                  margin-right: 8px !important;
                  font-size: 14px !important;
                  font-weight: bold !important;
                  cursor: pointer !important;
                  transition: background-color 0.2s !important;
                `;
                
                copyBtn.addEventListener('mouseover', function() {
                  this.style.backgroundColor = isDarkMode ? '#444444' : '#e0e0e0';
                });
                
                copyBtn.addEventListener('mouseout', function() {
                  this.style.backgroundColor = isDarkMode ? '#333333' : '#f5f5f5';
                });
                
                copyBtn.addEventListener('click', function(e) {
                  e.preventDefault();
                  e.stopPropagation();
                  
                  const selection = window.getSelection();
                  if (selection && !selection.isCollapsed) {
                    const text = selection.toString().trim();
                    if (text && window.flutter_inappwebview) {
                      window.flutter_inappwebview.callHandler('copyText', text);
                      console.log('[MIKA] 复制文本: ' + text);
                    }
                  }
                  
                  hideMenu();
                  return false;
                });
                
                // 创建翻译按钮
                const translateBtn = document.createElement('button');
                translateBtn.textContent = '翻译';
                translateBtn.style.cssText = `
                  background-color: #f5f5f5 !important;
                  color: #000000 !important;
                  border: none !important;
                  border-radius: 4px !important;
                  padding: 8px 12px !important;
                  font-size: 14px !important;
                  font-weight: bold !important;
                  cursor: pointer !important;
                  transition: background-color 0.2s !important;
                `;
                
                translateBtn.addEventListener('mouseover', function() {
                  this.style.backgroundColor = isDarkMode ? '#444444' : '#e0e0e0';
                });
                
                translateBtn.addEventListener('mouseout', function() {
                  this.style.backgroundColor = isDarkMode ? '#333333' : '#f5f5f5';
                });
                
                // 添加ID方便调试
                translateBtn.id = 'translate-btn';
                
                // 添加点击事件，确保事件冒泡被阻止
                translateBtn.addEventListener('click', function(e) {
                  e.preventDefault();
                  e.stopPropagation();
                  
                  console.log('[MIKA] 翻译按钮被点击 - 时间戳: ' + new Date().toISOString());
                  
                  // 直接调用Flutter的translateText方法，让Flutter使用已缓存的文本
                  if (window.flutter_inappwebview) {
                    try {
                      // 禁用按钮，防止重复点击
                      translateBtn.disabled = true;
                      translateBtn.style.opacity = '0.5';
                      translateBtn.textContent = '翻译中...';
                      
                      console.log('[MIKA] 准备调用Flutter桥接: translateText');
                      
                      // 发送一个特殊信号，让Flutter使用已缓存的文本进行翻译
                      window.flutter_inappwebview.callHandler('translateText', 'USE_CACHED_TEXT');
                      console.log('[MIKA] 调用Flutter桥接成功完成');
                      
                      // 延迟500毫秒后隐藏菜单，确保API调用已经开始处理
                      setTimeout(function() {
                        console.log('[MIKA] API调用已发送，现在隐藏菜单');
                        hideMenu();
                        
                        // 恢复按钮状态
                        setTimeout(function() {
                          translateBtn.disabled = false;
                          translateBtn.style.opacity = '1';
                          translateBtn.textContent = '翻译';
                        }, 500);
                      }, 500);
                    } catch (error) {
                      console.error('[MIKA] 调用Flutter桥接失败: ', error);
                      
                      // 恢复按钮状态
                      translateBtn.disabled = false;
                      translateBtn.style.opacity = '1';
                      translateBtn.textContent = '翻译';
                      
                      // 错误情况下立即隐藏菜单
                      hideMenu();
                    }
                  } else {
                    console.error('[MIKA] 无法调用翻译: window.flutter_inappwebview未定义');
                    hideMenu();
                  }
                  
                  return false;
                });
                
                // 添加按钮到菜单
                menu.appendChild(copyBtn);
                menu.appendChild(translateBtn);
                document.body.appendChild(menu);
                
                // 隐藏菜单
                function hideMenu() {
                  menu.style.display = 'none';
                  console.log('[MIKA] 文本选择菜单已隐藏');
                }
                
                // 点击其他区域隐藏菜单
                document.addEventListener('mousedown', function(e) {
                  if (e.target !== menu && !menu.contains(e.target)) {
                    hideMenu();
                  }
                });
                
                document.addEventListener('touchstart', function(e) {
                  if (e.target !== menu && !menu.contains(e.target)) {
                    hideMenu();
                  }
                }, { passive: true });
                
                // 滚动时隐藏菜单
                document.addEventListener('scroll', hideMenu, { passive: true });
                
                // 创建菜单对象
                const menuObj = {
                  show: function(x, y) {
                    // 确保菜单不会超出视口
                    const viewportWidth = window.innerWidth;
                    const viewportHeight = window.innerHeight;
                    
                    // 先设置位置以便获取菜单尺寸
                    menu.style.display = 'block';
                    menu.style.left = '0';
                    menu.style.top = '0';
                    
                    // 获取菜单尺寸
                    const menuWidth = menu.offsetWidth;
                    const menuHeight = menu.offsetHeight;
                    
                    // 计算最终位置，确保在视口内
                    let finalX = Math.min(Math.max(menuWidth / 2, x), viewportWidth - menuWidth / 2);
                    // 如果菜单在顶部显示会超出视口，则在选择文本下方显示
                    let finalY = y - menuHeight - 5; // 默认在选择文本上方显示
                    if (finalY < 10) {
                      finalY = y + 25; // 改为在选择文本下方显示
                    }
                    
                    // 设置最终位置
                    menu.style.left = finalX + 'px';
                    menu.style.top = finalY + 'px';
                    
                    console.log('[MIKA] 显示文本选择菜单: x=' + finalX + ', y=' + finalY + 
                                ', 视口: ' + viewportWidth + 'x' + viewportHeight + 
                                ', 菜单: ' + menuWidth + 'x' + menuHeight);
                  },
                  hide: hideMenu
                };
                
                // 将菜单添加到DOM
                document.body.appendChild(menu);
                
                // 将菜单对象设置为全局变量，便于其他函数访问
                window.textSelectionMenu = menuObj;
                
                console.log('[MIKA] 文本选择菜单已创建完成，并设置为全局变量window.textSelectionMenu');
                
                return menuObj;
              };
              
              // 创建滚动容器并包裹所有内容
              var scrollableDiv = document.getElementById('scrollable-content');
              if (!scrollableDiv) {
                scrollableDiv = document.createElement('div');
                scrollableDiv.id = 'scrollable-content';
                
                // 将body内容移动到滚动容器中
                while (document.body.firstChild) {
                  scrollableDiv.appendChild(document.body.firstChild);
                }
                document.body.appendChild(scrollableDiv);
              }
              
              // 为文章内容添加容器以提供适当的边距
              var articleContent = document.querySelector('article, .content, section, main');
              if (articleContent) {
                // 如果已经有内容容器，确保它有正确的类名
                if (!articleContent.classList.contains('article-content')) {
                  articleContent.classList.add('article-content');
                }
              } else {
                // 如果没有找到文章容器，创建一个包裹所有内容
                var contentDiv = document.createElement('div');
                contentDiv.className = 'article-content';
                
                // 将滚动容器内的内容移至文章容器
                while (scrollableDiv.firstChild) {
                  contentDiv.appendChild(scrollableDiv.firstChild);
                }
                scrollableDiv.appendChild(contentDiv);
              }
              
              // 添加监听选择变化事件，显示自定义菜单
              document.addEventListener('selectionchange', function() {
                const selection = window.getSelection();
                if (selection.isCollapsed) {
                  // 没有选择，隐藏菜单
                  textSelectionMenu.hide();
                  // 通知Flutter清空选中的文本
                  if (window.flutter_inappwebview) {
                    window.flutter_inappwebview.callHandler('saveSelectedText', '');
                  }
                } else {
                  // 有文本被选中，但延迟显示菜单，确保选择已完成
                  setTimeout(function() {
                    const selection = window.getSelection();
                    if (selection && !selection.isCollapsed) {
                      const selectedText = selection.toString().trim();
                      if (selectedText && selectedText.length > 0) {
                        try {
                          // 立即将选中的文本发送到Flutter
                          if (window.flutter_inappwebview) {
                            window.flutter_inappwebview.callHandler('saveSelectedText', selectedText);
                          }
                          
                          const range = selection.getRangeAt(0);
                          const rect = range.getBoundingClientRect();
                          
                          // 计算选中区域的中间位置
                          const x = rect.left + (rect.width / 2);
                          // 将菜单位置稍微上移，避免遮挡文本
                          const y = rect.top - 10;
                          
                          textSelectionMenu.show(x, y);
                          
                          // 将选中的文本发送到控制台，便于调试
                          console.log('[MIKA] 选中文本: "' + selectedText + '", 长度: ' + selectedText.length);
                          console.log('[MIKA] 已发送选中文本到Flutter');
                        } catch (e) {
                          console.error('[MIKA] 显示菜单时出错:', e);
                        }
                      }
                    } else {
                      textSelectionMenu.hide();
                    }
                  }, 300); // 延迟时间从150ms增加到300ms，确保选择完全稳定
                }
              });
              
              // 全局拦截上下文菜单事件，阻止默认的选择菜单显示
              document.addEventListener('contextmenu', function(e) {
                const selection = window.getSelection();
                // 如果有文本选择，则阻止默认菜单显示
                if (selection && !selection.isCollapsed) {
                  e.preventDefault();
                  return false;
                }
                // 否则允许默认菜单显示（例如链接右键菜单）
                return true;
              });
              
              // 阻止ActionMode菜单出现 (Android)
              document.addEventListener('touchstart', function(e) {
                // 禁用长按选择文本的默认行为
                const target = e.target;
                if (target && (
                    target.tagName === 'P' || 
                    target.tagName === 'SPAN' || 
                    target.tagName === 'DIV' || 
                    target.tagName === 'ARTICLE'
                )) {
                  // 只应用于正文区域，不影响按钮等交互元素
                  e.target.style.webkitUserSelect = 'text';
                  e.target.style.webkitTouchCallout = 'none';
                }
              }, { passive: false });
              
              // 阻止默认选择行为 (iOS)
              document.addEventListener('touchend', function(e) {
                // 如果有选择，显示我们的自定义菜单而非系统菜单
                const selection = window.getSelection();
                if (selection && !selection.isCollapsed) {
                  // 允许选择完成，然后立即清除ActionMode
                  setTimeout(function() {
                    if (window.getSelection().toString().trim().length > 0) {
                      // 触发自定义菜单的显示
                      document.dispatchEvent(new Event('selectionchange'));
                    }
                  }, 200); // 延迟时间从50ms增加到200ms，给系统更多时间完成选择
                }
              }, { passive: false });
              
              // 添加点击处理，支持单词点击查询功能
              document.addEventListener('dblclick', function(e) {
                const selection = window.getSelection();
                if (selection && !selection.isCollapsed) {
                  const selectedText = selection.toString().trim();
                  if (selectedText && !selectedText.includes(' ')) {
                    console.log('双击选择单词: ' + selectedText);
                    // 调用Flutter处理单词查询
                    if (window.flutter_inappwebview) {
                      window.flutter_inappwebview.callHandler('onWordSelected', selectedText);
                    }
                  }
                }
              });
              
              // 初始化文本选择菜单
              const textSelectionMenu = createTextSelectionMenu();
              
              // 应用初始设置
              setDarkMode(${widget.isDarkMode});
              highlightVocabulary(${widget.showVocabulary});
            """).then((_) {
              // 在样式和函数注入后，加载词汇数据
              if (widget.showVocabulary) {
                if (widget.vocabularyData != null &&
                    widget.vocabularyData!.isNotEmpty) {
                  log.i('使用预加载的词汇数据: ${widget.vocabularyData!.length} 个词汇');

                  // 将预加载的词汇数据作为参数传递给JavaScript函数
                  final vocabularyJson = jsonEncode(widget.vocabularyData);
                  controller.evaluateJavascript(source: """
                    if (window.processPreloadedVocabulary) {
                      console.log('调用processPreloadedVocabulary函数处理预加载词汇数据');
                      window.processPreloadedVocabulary($vocabularyJson);
                    } else {
                      console.error('processPreloadedVocabulary函数未定义');
                    }
                  """);
                } else {
                  log.w('没有可用的预加载词汇数据');
                }
              } else {
                log.i('词汇高亮功能已禁用');
              }

              // 先显示文本内容
              controller.evaluateJavascript(source: """
                // 显示文本内容
                var invisibleStyle = document.getElementById('init-invisible-style');
                if (invisibleStyle) {
                  invisibleStyle.innerHTML = 'html, body { opacity: 1 !important; transition: opacity 0.3s ease; }';
                  console.log('文本内容显示中，添加淡入效果');
                  
                  // 完成后移除样式元素
                  setTimeout(function() {
                    invisibleStyle.remove();
                    console.log('初始渲染完成，样式元素已移除');
                    
                    // 文本内容显示后，延迟300ms再加载图片
                    setTimeout(function() {
                      console.log('开始加载图片...');
                      const images = document.querySelectorAll('img[data-fixed-src]');
                      let loadedCount = 0;
                      const totalImages = images.length;
                      
                      if (totalImages === 0) {
                        console.log('没有需要加载的图片');
                        return;
                      }
                      
                      console.log('开始加载 ' + totalImages + ' 张图片');
                      
                      for (let i = 0; i < images.length; i++) {
                        const img = images[i];
                        const fixedSrc = img.getAttribute('data-fixed-src');
                        
                        if (fixedSrc) {
                          // 添加图片加载完成事件
                          img.onload = function() {
                            loadedCount++;
                            img.style.backgroundColor = 'transparent';
                            img.style.transition = 'background-color 0.3s ease';
                            console.log('图片加载完成 (' + loadedCount + '/' + totalImages + ')');
                          };
                          
                          img.onerror = function() {
                            loadedCount++;
                            console.error('图片加载失败: ' + fixedSrc);
                            // 添加错误提示样式
                            img.style.backgroundColor = '${widget.isDarkMode ? "#5c2b2b" : "#ffebee"}';
                            img.style.border = '1px solid ${widget.isDarkMode ? "#8c3b3b" : "#ffcdd2"}';
                          };
                          
                          // 开始加载图片
                          img.setAttribute('src', fixedSrc);
                          img.removeAttribute('data-fixed-src');
                        }
                      }
                    }, 300);
                  }, 300);
                }
              """);

              setState(() {
                _isLoading = false;
                _hasLoadedContent = true;
                _webViewLoaded = true;

                // 更新缓存状态
                if (widget.articleId != null) {
                  HtmlRenderer._contentLoadedCache[widget.articleId!] = true;
                }
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
          const Center(
            child: CircularProgressIndicator(),
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
                    final String webviewUrl =
                        ArticleService.getArticleHtmlUrl(widget.articleId!);
                    _webViewController?.loadUrl(
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

    // 延迟500毫秒再显示对话框，确保JavaScript端已经处理完毕
    Future.delayed(const Duration(milliseconds: 500), () {
      log.i('延迟500ms后开始处理翻译请求，时间: ${DateTime.now().toString()}');

      // 显示加载对话框
      log.i('准备显示加载对话框');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      log.i('加载对话框显示完成');

      // 使用DictionaryService查询单词或短语
      final DictionaryService dictionaryService = DictionaryService();
      log.i('DictionaryService实例已创建');
      log.i('开始调用DictionaryService.lookupWord("$cleanText")');

      // 添加时间戳以跟踪API调用耗时
      final startTime = DateTime.now();
      log.i('API调用开始时间: $startTime');

      // 为了防止API调用过快导致界面未响应，再次延迟500毫秒
      Future.delayed(const Duration(milliseconds: 500), () {
        log.i('再次延迟500ms后开始API调用，时间: ${DateTime.now().toString()}');

        dictionaryService.lookupWord(cleanText).then((result) {
          // 计算API调用耗时
          final endTime = DateTime.now();
          final duration = endTime.difference(startTime);
          log.i('API调用结束时间: $endTime');
          log.i('API调用耗时: ${duration.inMilliseconds}毫秒');

          // 为了确保用户能看到加载过程，至少显示加载对话框1秒钟
          Future.delayed(const Duration(milliseconds: 1000), () {
            log.i('延迟1秒后关闭加载对话框，确保用户看到加载过程');

            // 关闭加载对话框
            log.i('准备关闭加载对话框');
            Navigator.of(context).pop();
            log.i('加载对话框已关闭');

            if (result != null) {
              log.i('API查询成功: ${result.word}, 翻译: ${result.translation}');
              log.i('DictionaryResult详情: $result');

              // 从DictionaryResult创建一个Vocabulary对象
              final vocabulary = Vocabulary(
                word: result.word,
                translation: result.translation ?? '未找到翻译',
                context: '', // 无上下文
                example: '', // 无例句
              );
              log.i('已创建Vocabulary对象: ${vocabulary.word}');

              // 显示词典卡片对话框
              log.i('准备显示翻译结果对话框');
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  contentPadding: const EdgeInsets.all(8),
                  content: SingleChildScrollView(
                    child: DictionaryCard.fromVocabulary(
                      vocabulary: vocabulary,
                      onClose: () {
                        log.i('用户关闭了翻译结果对话框');
                        Navigator.of(context).pop();
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
              );
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
          });
        }).catchError((error) {
          // 计算API调用耗时（错误情况）
          final endTime = DateTime.now();
          final duration = endTime.difference(startTime);
          log.i('API调用结束时间（出错）: $endTime');
          log.i('API调用耗时: ${duration.inMilliseconds}毫秒');

          // 延迟一段时间后关闭加载对话框
          Future.delayed(const Duration(milliseconds: 1000), () {
            // 关闭加载对话框
            log.i('准备关闭加载对话框（出错）');
            Navigator.of(context, rootNavigator: true).pop();
            log.i('加载对话框已关闭（出错）');

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

  // 测试翻译功能
  void _testTranslationFeature() {
    log.i('开始测试翻译功能');
    final testWord = 'hello';

    // 首先测试API连接是否正常
    _testDictionaryAPI().then((success) {
      if (success) {
        log.i('API测试成功，继续调用翻译对话框');
        // 直接调用翻译对话框
        _showTranslationDialog(context, testWord);
      } else {
        log.e('API测试失败，检查网络连接和API服务');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('翻译服务不可用，请检查网络连接'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    log.i('翻译功能测试已触发');
  }

  // 测试字典API是否可用
  Future<bool> _testDictionaryAPI() async {
    log.i('开始测试字典API连接');
    final DictionaryService dictionaryService = DictionaryService();

    try {
      log.i('使用单词"test"测试API');
      final result = await dictionaryService.lookupWord('test');

      if (result != null) {
        log.i('API测试成功，收到响应: ${result.word}');
        return true;
      } else {
        log.w('API测试返回空结果');
        return false;
      }
    } catch (e) {
      log.e('API测试失败', e);
      return false;
    }
  }
}
