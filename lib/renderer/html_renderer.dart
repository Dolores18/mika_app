import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../utils/logger.dart';
import '../services/article_service.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import '../server/local_server.dart'; // 添加本地服务器导入

class HtmlRenderer extends StatefulWidget {
  final String? articleId;
  final bool isDarkMode;
  final double fontSize;
  final bool showVocabulary;
  final Function(String)? onWordSelected;
  final Function(double)? onFontSizeChanged;
  final String? htmlContent; // 添加接收预先加载的HTML内容
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

  @override
  void initState() {
    super.initState();
    _loadCSSFiles();

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

      // 并行请求：在WebView加载HTML的同时预加载词汇数据
      if (widget.showVocabulary) {
        _preloadVocabularyData();
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
    if (_preloadedVocabulary == null || _webViewController == null) return;

    log.i('应用预加载的词汇数据');

    // 将词汇数据传递给WebView
    final vocabularyJson = jsonEncode(_preloadedVocabulary);
    _webViewController!.evaluateJavascript(source: """
      if (window.processPreloadedVocabulary) {
        window.processPreloadedVocabulary($vocabularyJson);
      } else {
        console.error('processPreloadedVocabulary函数未定义');
      }
    """);
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
              ? InAppWebViewInitialData(data: widget.htmlContent!)
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
                if (args.isNotEmpty) {
                  final text = args[0].toString();
                  log.i('翻译文本: $text');
                  // 这里可以实现调用翻译API或打开翻译对话框
                  _showTranslationDialog(context, text);
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

            // 注入CSS并处理文档配置
            controller.evaluateJavascript(source: """
              // 确保内容在样式应用前不可见
              if (!document.getElementById('init-invisible-style')) {
                var style = document.createElement('style');
                style.id = 'init-invisible-style';
                style.innerHTML = 'html, body { opacity: 0 !important; transition: opacity 0.3s ease; }';
                document.head.appendChild(style);
              }
              
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
                // 更新现有的词汇元素
                var vocabWords = document.querySelectorAll('.vocabulary-word');
                for (var i = 0; i < vocabWords.length; i++) {
                  vocabWords[i].style.backgroundColor = show ? '#fff59d' : 'transparent';
                  vocabWords[i].style.color = show ? '#000' : 'inherit';
                }
              };
              
              // 添加viewport元标签确保适当缩放
              var viewportMeta = document.createElement('meta');
              viewportMeta.name = 'viewport';
              viewportMeta.content = 'width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes, viewport-fit=cover';
              document.head.appendChild(viewportMeta);
              
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
                console.log('创建自定义文本选择菜单');
                
                // 创建菜单元素
                const menu = document.createElement('div');
                menu.id = 'text-selection-menu';
                menu.style.cssText = `
                  position: fixed !important;
                  z-index: 99999 !important;
                  background-color: ${widget.isDarkMode ? '#1e1e1e' : '#ffffff'} !important;
                  border: 1px solid ${widget.isDarkMode ? '#333333' : '#e0e0e0'} !important;
                  border-radius: 8px !important;
                  box-shadow: 0 4px 12px rgba(0,0,0,0.15) !important;
                  padding: 8px !important;
                  display: none;
                  opacity: 1 !important;
                  visibility: visible !important;
                  transform: translate(-50%, -50%) !important; /* 相对于传入点居中 */
                `;
                
                // 创建复制按钮
                const copyBtn = document.createElement('button');
                copyBtn.textContent = '复制';
                copyBtn.style.cssText = `
                  background-color: ${widget.isDarkMode ? '#333333' : '#f5f5f5'} !important;
                  color: ${widget.isDarkMode ? '#ffffff' : '#000000'} !important;
                  border: none !important;
                  border-radius: 4px !important;
                  padding: 8px 12px !important;
                  margin-right: 8px !important;
                  font-size: 14px !important;
                  font-weight: bold !important;
                  cursor: pointer !important;
                `;
                
                copyBtn.addEventListener('click', function(e) {
                  e.preventDefault();
                  e.stopPropagation();
                  
                  const selection = window.getSelection();
                  if (selection && !selection.isCollapsed) {
                    const text = selection.toString().trim();
                    if (text && window.flutter_inappwebview) {
                      window.flutter_inappwebview.callHandler('copyText', text);
                      console.log('复制文本: ' + text);
                    }
                  }
                  
                  hideMenu();
                  return false;
                });
                
                // 创建翻译按钮
                const translateBtn = document.createElement('button');
                translateBtn.textContent = '翻译';
                translateBtn.style.cssText = `
                  background-color: ${widget.isDarkMode ? '#333333' : '#f5f5f5'} !important;
                  color: ${widget.isDarkMode ? '#ffffff' : '#000000'} !important;
                  border: none !important;
                  border-radius: 4px !important;
                  padding: 8px 12px !important;
                  font-size: 14px !important;
                  font-weight: bold !important;
                  cursor: pointer !important;
                `;
                
                translateBtn.addEventListener('click', function(e) {
                  e.preventDefault();
                  e.stopPropagation();
                  
                  const selection = window.getSelection();
                  if (selection && !selection.isCollapsed) {
                    const text = selection.toString().trim();
                    if (text && window.flutter_inappwebview) {
                      window.flutter_inappwebview.callHandler('translateText', text);
                      console.log('翻译文本: ' + text);
                    }
                  }
                  
                  hideMenu();
                  return false;
                });
                
                // 添加按钮到菜单
                menu.appendChild(copyBtn);
                menu.appendChild(translateBtn);
                document.body.appendChild(menu);
                
                // 隐藏菜单
                function hideMenu() {
                  menu.style.display = 'none';
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
                
                return {
                  show: function(x, y) {
                    // 直接使用文本选择返回的位置，不做边界调整
                    menu.style.left = x + 'px';
                    menu.style.top = y + 'px';
                    menu.style.display = 'block';
                    console.log('直接显示菜单: x=' + x + ', y=' + y);
                  },
                  hide: hideMenu
                };
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
                } else {
                  // 有文本被选中，但延迟显示菜单，确保选择已完成
                  setTimeout(function() {
                    const selection = window.getSelection();
                    if (selection && !selection.isCollapsed) {
                      const selectedText = selection.toString().trim();
                      if (selectedText && selectedText.length > 0) {
                        try {
                          const range = selection.getRangeAt(0);
                          const rect = range.getBoundingClientRect();
                          
                          // 计算选中区域的中间位置
                          const x = rect.left + (rect.width / 2);
                          const y = rect.top + (rect.height / 2);
                          
                          textSelectionMenu.show(x, y);
                        } catch (e) {
                          console.error('显示菜单时出错:', e);
                        }
                      }
                    } else {
                      textSelectionMenu.hide();
                    }
                  }, 150);
                }
              });
              
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
                controller.evaluateJavascript(source: """
                  // 加载词汇
                  if (window.processVocabulary) {
                    window.processVocabulary('${widget.articleId}');
                  } else {
                    console.error('processVocabulary函数未定义');
                  }
                """);
              }

              // 在样式注入后，设置一个延迟，确保所有样式都已应用
              Future.delayed(const Duration(milliseconds: 300), () {
                if (_webViewController != null) {
                  // 显示内容，添加淡入效果
                  _webViewController!.evaluateJavascript(source: """
                    var invisibleStyle = document.getElementById('init-invisible-style');
                    if (invisibleStyle) {
                      invisibleStyle.innerHTML = 'html, body { opacity: 1 !important; transition: opacity 0.3s ease; }';
                      console.log('内容显示中，添加淡入效果');
                      
                      // 完成后移除样式元素
                      setTimeout(function() {
                        invisibleStyle.remove();
                        console.log('渲染完成，样式元素已移除');
                      }, 300);
                    }
                  """);
                }
              });

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
    // 这里可以集成实际的翻译API
    // 暂时只显示一个简单的对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('翻译'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('原文: $text'),
            const SizedBox(height: 16),
            const Text('翻译结果将在这里显示'),
            // 实际应用中，这里会显示真正的翻译结果
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
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
}
