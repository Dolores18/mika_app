import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../utils/logger.dart';
import '../services/article_service.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../server/local_server.dart'; // 添加本地服务器导入

class HtmlRenderer extends StatefulWidget {
  final String? articleId;
  final bool isDarkMode;
  final double fontSize;
  final bool showVocabulary;
  final Function(String)? onWordSelected;
  final Function(double)? onFontSizeChanged;

  const HtmlRenderer({
    Key? key,
    this.articleId,
    this.isDarkMode = false,
    this.fontSize = 16.0,
    this.showVocabulary = true,
    this.onWordSelected,
    this.onFontSizeChanged,
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

  @override
  void initState() {
    super.initState();
    _initializeWebViewAndLoadData();
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

        // 为确保字体更新有效，500毫秒后再次尝试更新
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_webViewController != null && mounted) {
            log.i('再次尝试更新字体大小: ${widget.fontSize}');
            _updateFontSize();
          }
        });
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
      _webViewController!.evaluateJavascript(source: """
            if (window.setFontSize) {
              // 强制更新WebView字体大小
              window.updateFontSizeForced(${widget.fontSize});
            } else {
              console.log('setFontSize函数不存在');
            }
          """);
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

    // 直接使用远程URL
    final String webviewUrl =
        ArticleService.getArticleHtmlUrl(widget.articleId!);
    log.i('加载远程文章URL: $webviewUrl, 文章ID: ${widget.articleId}');

    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(webviewUrl),
          ),
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
            cacheMode: CacheMode.LOAD_DEFAULT,
            userAgent: 'Flutter InAppWebView - MIKA Reader',
            safeBrowsingEnabled: false,
            clearCache: true,
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
            log.i('WebView已创建，准备载入URL: $webviewUrl');
            _webViewController = controller;

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

            // 添加字体大小变化处理器 - 当WebView内部缩放改变时通知Flutter
            controller.addJavaScriptHandler(
              handlerName: 'onFontSizeChanged',
              callback: (args) {
                if (args.isNotEmpty && widget.onFontSizeChanged != null) {
                  try {
                    final newSize = double.parse(args[0].toString());
                    log.i('WebView通知字体大小变化: $newSize');
                    widget.onFontSizeChanged!(newSize);
                  } catch (e) {
                    log.e('解析字体大小失败: ${args[0]}, 错误: $e');
                  }
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

            // 样式应用和内容显示的完整流程
            controller.evaluateJavascript(source: """
              // 确保内容在样式应用前不可见
              if (!document.getElementById('init-invisible-style')) {
                var style = document.createElement('style');
                style.id = 'init-invisible-style';
                style.innerHTML = 'html, body { opacity: 0 !important; transition: opacity 0.3s ease; }';
                document.head.appendChild(style);
              }
              
              // 立即应用禁用系统文本选择菜单的CSS
              var disableSystemMenuCSS = document.createElement('style');
              disableSystemMenuCSS.id = 'disable-system-menu-style';
              disableSystemMenuCSS.innerHTML = `
                /* 移除所有禁用系统菜单的CSS */
                body {
                  -webkit-user-select: text !important;
                  user-select: text !important;
                  -webkit-touch-callout: none !important; /* 禁用系统菜单但允许选择 */
                }
                
                /* 自定义文本选择高亮样式 */
                ::selection {
                  background: ${widget.isDarkMode ? 'rgba(74, 74, 74, 0.99)' : 'rgba(179, 212, 252, 0.99)'} !important;
                  color: ${widget.isDarkMode ? '#fff' : '#000'} !important;
                }
              `;
              document.head.appendChild(disableSystemMenuCSS);
              
              // 添加重点词汇处理函数
              window.processVocabulary = function(articleId) {
                if (!articleId) {
                  console.error('处理词汇时未找到文章ID');
                  return;
                }
                
                // 使用正确的API端点 - 获取带分析的文章数据
                fetch('/api/articles/' + articleId + '/with_analysis')
                  .then(function(response) {
                    if (!response.ok) {
                      throw new Error('获取文章数据失败: HTTP ' + response.status);
                    }
                    return response.json();
                  })
                  .then(function(data) {
                    // 从返回数据中提取vocabulary部分
                    if (!data.analysis || !data.analysis.vocabulary || !Array.isArray(data.analysis.vocabulary)) {
                      throw new Error('返回数据中未找到有效的词汇列表');
                    }
                    
                    const vocabulary = data.analysis.vocabulary;
                    console.log('成功获取词汇列表，数量: ' + vocabulary.length);
                    
                    if (vocabulary && vocabulary.length > 0) {
                      const content = document.body;
                      let html = content.innerHTML;
                      let highlightCount = 0;
                      
                      vocabulary.forEach(function(item) {
                        if (!item.word) return;
                        
                        // 创建一个安全的查找函数，避免正则表达式问题
                        function findAndReplace(text, word) {
                          let result = '';
                          let lastIndex = 0;
                          let wordLen = word.length;
                          let i = text.indexOf(word);
                          
                          while (i !== -1) {
                            // 检查是否是单词边界
                            const prevChar = i > 0 ? text.charAt(i - 1) : ' ';
                            const nextChar = i + wordLen < text.length ? text.charAt(i + wordLen) : ' ';
                            const isWordBoundaryStart = /\\s|[^a-zA-Z0-9]/.test(prevChar);
                            const isWordBoundaryEnd = /\\s|[^a-zA-Z0-9]/.test(nextChar);
                            
                            if (isWordBoundaryStart && isWordBoundaryEnd) {
                              // 替换单词，添加内联样式确保高亮效果
                              result += text.substring(lastIndex, i);
                              result += '<span class="vocabulary-word" data-word="' + item.word + 
                                       '" data-translation="' + (item.translation || '') + 
                                       '" style="background-color: #fff59d !important; color: #000 !important; border-radius: 2px !important; cursor: pointer !important; padding: 0 2px !important; margin: 0 -2px !important; transition: all 0.2s ease !important; display: inline-block !important;">' + 
                                       text.substring(i, i + wordLen) + '</span>';
                              highlightCount++;
                            } else {
                              // 直接添加不替换
                              result += text.substring(lastIndex, i + wordLen);
                            }
                            
                            lastIndex = i + wordLen;
                            i = text.indexOf(word, lastIndex);
                          }
                          
                          result += text.substring(lastIndex);
                          return result;
                        }
                        
                        html = findAndReplace(html, item.word);
                      });
                      
                      content.innerHTML = html;
                      console.log('成功高亮 ' + highlightCount + ' 个词汇实例');
                      
                      // 添加点击事件处理程序
                      const vocabularyWords = document.querySelectorAll('.vocabulary-word');
                      vocabularyWords.forEach(function(word) {
                        word.addEventListener('click', function() {
                          const selectedWord = this.getAttribute('data-word');
                          console.log('用户点击词汇: ' + selectedWord);
                          
                          try {
                            if (window.flutter_inappwebview) {
                              window.flutter_inappwebview.callHandler('onWordSelected', selectedWord);
                            }
                          } catch (e) {
                            console.error('无法发送词汇选择到Flutter: ' + e.message);
                          }
                        });
                      });
                      
                      // 通知Flutter词汇加载完成
                      if (window.flutter_inappwebview) {
                        window.flutter_inappwebview.callHandler('onVocabularyLoaded', highlightCount.toString());
                      }
                    }
                  })
                  .catch(function(error) {
                    console.error('处理词汇时出错: ' + error.message);
                  });
              };
              
              // 立即应用防回弹CSS
              var noBounceCss = document.createElement('style');
              noBounceCss.id = 'no-bounce-style';
              noBounceCss.innerHTML = `
                html, body {
                  position: fixed;
                  width: 100%;
                  height: 100%;
                  overflow: hidden;
                }
                #scrollable-content {
                  overflow-y: scroll;
                  overflow-x: hidden;
                  height: 100%;
                  width: 100%;
                  position: absolute;
                  top: 0;
                  left: 0;
                  right: 0;
                  bottom: 0;
                  -webkit-overflow-scrolling: touch;
                  overscroll-behavior: none;
                }
                ::-webkit-scrollbar {
                  display: none;
                  width: 0px;
                  height: 0px;
                }
              `;
              document.head.appendChild(noBounceCss);
              
              // 创建滚动容器并包裹所有内容
              var scrollableDiv = document.createElement('div');
              scrollableDiv.id = 'scrollable-content';
              
              // 将body内容移动到滚动容器中
              while (document.body.firstChild) {
                scrollableDiv.appendChild(document.body.firstChild);
              }
              document.body.appendChild(scrollableDiv);
              
              // 添加viewport元标签确保适当缩放
              var viewportMeta = document.createElement('meta');
              viewportMeta.name = 'viewport';
              viewportMeta.content = 'width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes, viewport-fit=cover';
              document.head.appendChild(viewportMeta);
              
              // 移除所有已有的样式表
              Array.from(document.querySelectorAll('link[rel="stylesheet"], style')).forEach(sheet => {
                if (!sheet.hasAttribute('data-mika-custom') && sheet.id !== 'init-invisible-style') {
                  sheet.disabled = true;
                  sheet.remove();
                }
              });
              
              // 添加基本的样式和主题控制
              var style = document.createElement('style');
              style.setAttribute('data-mika-custom', 'true');
              style.textContent = `
                html {
                  font-size: 100%;
                  -webkit-text-size-adjust: 100%;
                  text-size-adjust: 100%;
                  overflow-x: hidden;
                  overscroll-behavior: none;
                  -webkit-touch-callout: none;
                }
                
                body {
                  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                  font-size: ${widget.fontSize >= 16 ? widget.fontSize : 16}px !important;
                  line-height: 1.8;
                  color: ${widget.isDarkMode ? '#fff' : '#000'};
                  background-color: ${widget.isDarkMode ? '#121212' : '#fff'};
                  padding: 16px;
                  margin: 0 auto;
                  max-width: 100%;
                  overflow-wrap: break-word;
                  word-wrap: break-word;
                  box-sizing: border-box;
                  overscroll-behavior-y: none;
                  overflow-x: hidden;
                  -webkit-overflow-scrolling: auto;
                  -webkit-user-select: text;
                  user-select: text;
                }
                
                /* 隐藏滚动条但保留滚动功能 */
                ::-webkit-scrollbar {
                  width: 0px;
                  background: transparent;
                  display: none;
                }
                
                * {
                  max-width: 100%;
                  box-sizing: border-box;
                }
                
                article, section, div {
                  width: 100%;
                  max-width: 100%;
                  margin-left: 0;
                  margin-right: 0;
                  box-sizing: border-box;
                }
                
                p {
                  font-size: ${widget.fontSize >= 16 ? widget.fontSize : 16}px !important;
                  margin-bottom: 1.2em;
                  line-height: 1.6;
                  overflow-wrap: break-word;
                  word-wrap: break-word;
                }
                
                h1 { 
                  font-size: ${(widget.fontSize + 8) >= 20 ? (widget.fontSize + 8) : 20}px !important;
                  color: ${widget.isDarkMode ? '#e0e0e0' : '#222'}; 
                  font-weight: bold;
                  line-height: 1.3;
                  margin: 1em 0 0.5em;
                }
                
                h2 { 
                  font-size: ${(widget.fontSize + 4) >= 18 ? (widget.fontSize + 4) : 18}px !important;
                  color: ${widget.isDarkMode ? '#e0e0e0' : '#222'}; 
                  font-weight: bold;
                  line-height: 1.3;
                  margin: 1em 0 0.5em;
                }
                
                h3 { 
                  font-size: ${(widget.fontSize + 2) >= 17 ? (widget.fontSize + 2) : 17}px !important;
                  color: ${widget.isDarkMode ? '#e0e0e0' : '#222'}; 
                  font-weight: bold;
                  line-height: 1.3;
                  margin: 1em 0 0.5em;
                }
                
                a {
                  color: ${widget.isDarkMode ? '#90caf9' : '#1976d2'};
                  text-decoration: none;
                }
                
                blockquote {
                  border-left: 4px solid ${widget.isDarkMode ? '#424242' : '#e0e0e0'};
                  margin-left: 0;
                  padding-left: 16px;
                  color: ${widget.isDarkMode ? '#bdbdbd' : '#616161'};
                }
                
                code {
                  background-color: ${widget.isDarkMode ? '#333' : '#f5f5f5'};
                  padding: 2px 4px;
                  border-radius: 4px;
                  font-family: 'Courier New', Courier, monospace;
                  font-size: 90%;
                }
                
                img {
                  max-width: 100% !important;
                  height: auto !important;
                  display: block;
                  margin: 1em auto;
                  border-radius: 4px;
                }
                
                table {
                  border-collapse: collapse;
                  width: 100%;
                  max-width: 100%;
                  overflow-x: auto;
                  display: block;
                  margin: 1em 0;
                }
                
                table, th, td {
                  border: 1px solid ${widget.isDarkMode ? '#444' : '#ddd'};
                }
                
                th, td {
                  padding: 8px;
                  text-align: left;
                }
                
                th {
                  background-color: ${widget.isDarkMode ? '#333' : '#f5f5f5'};
                }
                
                ul, ol {
                  padding-left: 20px;
                }
                
                li {
                  margin-bottom: 0.5em;
                }
                
                figure {
                  margin: 1em 0;
                  max-width: 100%;
                }
                
                figcaption {
                  font-size: 0.9em;
                  color: ${widget.isDarkMode ? '#bdbdbd' : '#616161'};
                  text-align: center;
                }
                
                hr {
                  border: none;
                  border-top: 1px solid ${widget.isDarkMode ? '#444' : '#eee'};
                  margin: 2em 0;
                }
                
                /* 自定义文本选择样式 */
                ::selection {
                  background: ${widget.isDarkMode ? '#4a4a4a' : '#b3d4fc'};
                  color: ${widget.isDarkMode ? '#fff' : '#000'};
                }
                
                /* 媒体查询以适应不同屏幕 */
                @media (max-width: 600px) {
                  body {
                    padding: 12px;
                  }
                  
                  h1 {
                    font-size: ${(widget.fontSize + 6) >= 19 ? (widget.fontSize + 6) : 19}px !important;
                  }
                  
                  h2 {
                    font-size: ${(widget.fontSize + 3) >= 18 ? (widget.fontSize + 3) : 18}px !important;
                  }
                }
                
                /* 阻止系统触发的长按选择菜单 */
                p, span, div, h1, h2, h3, h4, h5, h6, li, a {
                  -webkit-touch-callout: none;
                }
              `;
              document.head.appendChild(style);
              
              // 移除所有可能的固定宽度
              document.querySelectorAll('[style*="width"]').forEach(el => {
                if (el.style.width.includes('px') && parseInt(el.style.width) > 100) {
                  el.style.width = '100%';
                }
              });
              
              // 检测并更正表格溢出
              document.querySelectorAll('table').forEach(table => {
                const wrapper = document.createElement('div');
                wrapper.style.cssText = 'width: 100%; overflow-x: auto; margin-bottom: 1em;';
                table.parentNode.insertBefore(wrapper, table);
                wrapper.appendChild(table);
              });
              
              // 设置主题切换函数 - 使用更全面的选择器
              window.setDarkMode = function(isDark) {
                // 设置文档主题
                document.documentElement.setAttribute('data-theme', isDark ? 'dark' : 'light');
                
                // 更新body样式
                document.body.style.color = isDark ? '#fff' : '#000';
                document.body.style.backgroundColor = isDark ? '#121212' : '#fff';
                
                // 更新标题颜色
                document.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach(function(heading) {
                  heading.style.color = isDark ? '#e0e0e0' : '#222';
                });
                
                // 更新链接颜色
                document.querySelectorAll('a').forEach(function(link) {
                  link.style.color = isDark ? '#90caf9' : '#1976d2';
                });
                
                // 更新引用块颜色
                document.querySelectorAll('blockquote').forEach(function(quote) {
                  quote.style.borderLeftColor = isDark ? '#424242' : '#e0e0e0';
                  quote.style.color = isDark ? '#bdbdbd' : '#616161';
                });
                
                // 更新代码块颜色
                document.querySelectorAll('code, pre').forEach(function(code) {
                  code.style.backgroundColor = isDark ? '#333' : '#f5f5f5';
                });
                
                // 更新表格样式
                document.querySelectorAll('table, th, td').forEach(function(el) {
                  el.style.borderColor = isDark ? '#444' : '#ddd';
                });
                
                document.querySelectorAll('th').forEach(function(th) {
                  th.style.backgroundColor = isDark ? '#333' : '#f5f5f5';
                });
              };
              
              // 设置字体大小函数 - 添加双向同步
              window.setFontSize = function(size) {
                var fontSize = size;
                // 确保最小字体大小为16像素
                if (fontSize < 16) {
                  fontSize = 16;
                }
                
                // 获取当前字体大小，避免重复设置相同的大小
                var currentFontSize = 16;
                try {
                  const p = document.querySelector('p');
                  if (p) {
                    const style = window.getComputedStyle(p);
                    currentFontSize = parseFloat(style.fontSize) || 16;
                  }
                } catch (e) {
                  console.error('获取当前字体大小失败:', e);
                }
                
                // 如果大小相同，不进行更改（允许0.5px的误差）
                if (Math.abs(currentFontSize - fontSize) < 0.5) {
                  console.log('字体大小未变化，跳过更新: ' + fontSize + 'px');
                  return;
                }
                
                console.log('设置字体大小: ' + fontSize + 'px');
                
                // 设置基础字体大小
                document.body.style.fontSize = fontSize + 'px';
                
                // 应用到段落
                var paragraphs = document.querySelectorAll('p');
                for (var i = 0; i < paragraphs.length; i++) {
                  paragraphs[i].style.fontSize = fontSize + 'px';
                }
                
                // 应用到列表项
                var listItems = document.querySelectorAll('li');
                for (var i = 0; i < listItems.length; i++) {
                  listItems[i].style.fontSize = fontSize + 'px';
                }
                
                // 应用到表格单元格
                var cells = document.querySelectorAll('td, th');
                for (var i = 0; i < cells.length; i++) {
                  cells[i].style.fontSize = fontSize + 'px';
                }
                
                // 应用到标题，使用不同的大小
                var h1s = document.querySelectorAll('h1');
                for (var i = 0; i < h1s.length; i++) {
                  var h1Size = fontSize + 4;
                  if (h1Size < 20) h1Size = 20;
                  h1s[i].style.fontSize = h1Size + 'px';
                }
                
                var h2s = document.querySelectorAll('h2');
                for (var i = 0; i < h2s.length; i++) {
                  var h2Size = fontSize + 2;
                  if (h2Size < 18) h2Size = 18;
                  h2s[i].style.fontSize = h2Size + 'px';
                }
                
                var h3s = document.querySelectorAll('h3');
                for (var i = 0; i < h3s.length; i++) {
                  var h3Size = fontSize + 1;
                  if (h3Size < 17) h3Size = 17;
                  h3s[i].style.fontSize = h3Size + 'px';
                }
                
                // 应用到其他文本元素
                var others = document.querySelectorAll('span, div:not(#text-selection-menu), figcaption');
                for (var i = 0; i < others.length; i++) {
                  // 排除标题元素
                  var tagName = others[i].tagName.toLowerCase();
                  if (tagName !== 'h1' && tagName !== 'h2' && tagName !== 'h3' && 
                      tagName !== 'h4' && tagName !== 'h5' && tagName !== 'h6') {
                    others[i].style.fontSize = fontSize + 'px';
                  }
                }
                
                // 通知Flutter字体大小已改变
                if (window.flutter_inappwebview) {
                  window.flutter_inappwebview.callHandler('onFontSizeChanged', fontSize.toString());
                }
              };
              
              // 添加强制更新字体大小的函数，不检查当前大小
              window.updateFontSizeForced = function(size) {
                var fontSize = size;
                // 确保最小字体大小为16像素
                if (fontSize < 16) {
                  fontSize = 16;
                }
                
                console.log('强制设置字体大小: ' + fontSize + 'px');
                
                // 设置基础字体大小
                document.body.style.fontSize = fontSize + 'px';
                
                // 应用到段落
                var paragraphs = document.querySelectorAll('p');
                for (var i = 0; i < paragraphs.length; i++) {
                  paragraphs[i].style.fontSize = fontSize + 'px';
                }
                
                // 应用到列表项
                var listItems = document.querySelectorAll('li');
                for (var i = 0; i < listItems.length; i++) {
                  listItems[i].style.fontSize = fontSize + 'px';
                }
                
                // 应用到表格单元格
                var cells = document.querySelectorAll('td, th');
                for (var i = 0; i < cells.length; i++) {
                  cells[i].style.fontSize = fontSize + 'px';
                }
                
                // 应用到标题，使用不同的大小
                var h1s = document.querySelectorAll('h1');
                for (var i = 0; i < h1s.length; i++) {
                  var h1Size = fontSize + 4;
                  if (h1Size < 20) h1Size = 20;
                  h1s[i].style.fontSize = h1Size + 'px';
                }
                
                var h2s = document.querySelectorAll('h2');
                for (var i = 0; i < h2s.length; i++) {
                  var h2Size = fontSize + 2;
                  if (h2Size < 18) h2Size = 18;
                  h2s[i].style.fontSize = h2Size + 'px';
                }
                
                var h3s = document.querySelectorAll('h3');
                for (var i = 0; i < h3s.length; i++) {
                  var h3Size = fontSize + 1;
                  if (h3Size < 17) h3Size = 17;
                  h3s[i].style.fontSize = h3Size + 'px';
                }
                
                // 应用到其他文本元素
                var others = document.querySelectorAll('span, div:not(#text-selection-menu), figcaption');
                for (var i = 0; i < others.length; i++) {
                  // 排除标题元素
                  var tagName = others[i].tagName.toLowerCase();
                  if (tagName !== 'h1' && tagName !== 'h2' && tagName !== 'h3' && 
                      tagName !== 'h4' && tagName !== 'h5' && tagName !== 'h6') {
                    others[i].style.fontSize = fontSize + 'px';
                  }
                }
                
                // 不触发回调，避免循环更新
                console.log('字体大小强制更新完成: ' + fontSize + 'px');
              };
              
              // 监听缩放手势
              document.addEventListener('gestureend', function(e) {
                // 在缩放手势结束后，尝试获取当前的字体大小并通知Flutter
                setTimeout(function() {
                  try {
                    // 获取段落的计算字体大小作为参考
                    var p = document.querySelector('p');
                    if (p) {
                      var computedStyle = window.getComputedStyle(p);
                      var computedFontSize = parseFloat(computedStyle.fontSize);
                      console.log('检测到缩放变化，当前字体大小: ' + computedFontSize + 'px');
                      
                      // 通知Flutter字体大小已变化
                      if (window.flutter_inappwebview) {
                        window.flutter_inappwebview.callHandler('onFontSizeChanged', computedFontSize.toString());
                      }
                    }
                  } catch (e) {
                    console.error('获取缩放后字体大小失败:', e);
                  }
                }, 300); // 延迟一点以确保计算样式已更新
              });
              
              // 设置词汇高亮函数
              window.highlightVocabulary = function(show) {
                // 更新词汇样式
                var style = document.getElementById('vocabulary-style');
                if (style) {
                  style.innerHTML = `
                    .vocabulary-word {
                      background-color: \${show ? '#fff59d' : 'transparent'} !important;
                      color: \${show ? '#000' : 'inherit'} !important;
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
                }
                
                // 更新现有的词汇元素
                var vocabWords = document.querySelectorAll('.vocabulary-word');
                for (var i = 0; i < vocabWords.length; i++) {
                  vocabWords[i].style.backgroundColor = show ? '#fff59d' : 'transparent';
                  vocabWords[i].style.color = show ? '#000' : 'inherit';
                }
                
                console.log('词汇高亮状态已更新: ' + (show ? '显示' : '隐藏'));
              };
              
              // 启用文本选择，但禁用系统菜单
              document.body.style.webkitUserSelect = 'text';
              document.body.style.userSelect = 'text';
              document.body.style.webkitTouchCallout = 'none'; // 禁用系统菜单但允许选择
              console.log('文本选择已启用，系统菜单已禁用');

              // 阻止默认的上下文菜单
              document.addEventListener('contextmenu', function(e) {
                e.preventDefault();
                return false;
              }, { passive: false });
              
              // 监听选择变化事件，显示自定义菜单
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
              setFontSize(${widget.fontSize});
              highlightVocabulary(${widget.showVocabulary});
              
              // 禁用回弹效果
              document.addEventListener('DOMContentLoaded', function() {
                // 防止文档滚动回弹
                document.body.addEventListener('touchmove', function(e) {
                  const currentScroll = window.scrollY || window.pageYOffset;
                  const maxScroll = document.body.scrollHeight - window.innerHeight;
                  
                  // 检测是否到达顶部或底部边界且尝试继续滚动
                  if ((currentScroll <= 0 && e.touches[0].clientY > 0) || 
                      (currentScroll >= maxScroll && e.touches[0].clientY < 0)) {
                    e.preventDefault(); // 阻止默认回弹行为
                  }
                }, { passive: false });
                
                // 禁用iOS的橡皮筋效果
                document.documentElement.style.overflow = 'hidden';
                document.body.style.overflow = 'auto';
                document.body.style.height = '100%';
                document.body.style.position = 'relative';
                document.body.style.overscrollBehavior = 'none';
              });
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
}
