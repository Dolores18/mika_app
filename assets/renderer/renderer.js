// MIKA阅读器渲染器JavaScript代码
// 处理HTML内容、应用样式和添加交互功能

// 创建MIKA渲染器接口对象
window.mikaRenderer = {
  // 设置字体大小
  setFontSize: function(size) {
    // 更新CSS变量
    document.documentElement.style.setProperty('--font-size-base', size + 'px');
    document.documentElement.setAttribute('data-font-size', size);
    
    // 更新动态样式
    var dynamicStyle = document.getElementById('dynamic-styles');
    if (dynamicStyle) {
      dynamicStyle.textContent = `
        :root { 
          --font-size-base: ${size}px;
        }
      `;
    } else {
      console.log('[MIKA] 未找到dynamic-styles元素');
    }
    
    console.log('[MIKA] 字体大小设置为: ' + size + 'px');
  },
  
  // 设置暗色/亮色主题
  setDarkMode: function(isDark) {
    console.log('[MIKA] 设置主题: ' + (isDark ? '深色' : '浅色'));
    
    // 1. 更新HTML根元素属性
    document.documentElement.setAttribute('data-theme', isDark ? 'dark' : 'light');
    
    // 2. 更新meta标签
    this._updateColorSchemeMeta(isDark);
    
    // 3. 修改文本选择菜单样式（如果存在）
    if (window.textSelectionMenu) {
      const menu = document.getElementById('text-selection-menu');
      if (menu) {
        // 根据主题设置菜单背景色
        menu.style.backgroundColor = isDark ? '#1e1e1e' : '#ffffff';
        menu.style.borderColor = isDark ? '#333333' : '#e0e0e0';
        
        // 设置菜单按钮颜色
        const buttons = menu.querySelectorAll('button');
        buttons.forEach(button => {
          button.style.backgroundColor = isDark ? '#333333' : '#f5f5f5';
          button.style.color = isDark ? '#ffffff' : '#000000';
        });
      }
    }
    
    console.log('[MIKA] 主题更新完成');
  },
  
  // 私有：更新颜色方案meta标签
  _updateColorSchemeMeta: function(isDark) {
    // 更新color-scheme meta标签
    var colorSchemeMeta = document.querySelector('meta[name="color-scheme"]');
    if (!colorSchemeMeta) {
      colorSchemeMeta = document.createElement('meta');
      colorSchemeMeta.name = 'color-scheme';
      document.head.appendChild(colorSchemeMeta);
    }
    colorSchemeMeta.content = isDark ? 'dark' : 'light';
    
    // 更新theme-color meta标签
    var themeColorMeta = document.querySelector('meta[name="theme-color"]');
    if (!themeColorMeta) {
      themeColorMeta = document.createElement('meta');
      themeColorMeta.name = 'theme-color';
      document.head.appendChild(themeColorMeta);
    }
    themeColorMeta.content = isDark ? '#121212' : '#ffffff';
    
    // 更新CSS变量
    document.documentElement.style.setProperty('color-scheme', isDark ? 'dark' : 'light only', 'important');
  },
  
  // 设置词汇显示状态
  setVocabularyVisibility: function(show) {
    console.log('[MIKA] 设置词汇显示: ' + (show ? '显示' : '隐藏'));
    document.documentElement.setAttribute('data-show-vocabulary', show);
  },
  
  // 高亮相关函数
  // 存储已高亮文本的数组
  _highlightedTexts: [],
  
  // 创建唯一标识符
  _createHighlightId: function() {
    return 'mika-highlight-' + Date.now() + '-' + Math.floor(Math.random() * 1000);
  },
  
  // 高亮当前选中的文本
  highlightSelection: function() {
    const selection = window.getSelection();
    if (!selection || selection.isCollapsed) {
      console.log('[MIKA] 没有选中文本，无法高亮');
      return null;
    }
    
    try {
      const text = selection.toString().trim();
      if (!text || text.length === 0) {
        console.log('[MIKA] 选中的文本为空，无法高亮');
        return null;
      }
      
      // 获取选区范围
      const range = selection.getRangeAt(0);
      
      // 创建高亮标识符
      const highlightId = this._createHighlightId();
      
      // 创建一个包含选区的span元素
      const highlightEl = document.createElement('span');
      highlightEl.id = highlightId;
      highlightEl.className = 'mika-highlight';
      highlightEl.style.backgroundColor = 'rgba(255, 255, 0, 0.3)';
      highlightEl.style.borderRadius = '2px';
      highlightEl.style.padding = '0 1px';
      highlightEl.style.cursor = 'pointer';
      highlightEl.dataset.mikaHighlight = 'true';
      highlightEl.dataset.text = text;
      
      // 添加点击事件处理器
      highlightEl.addEventListener('click', (e) => {
        // 调用Flutter方法显示高亮选项
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('onHighlightClicked', {
            id: highlightId,
            text: text
          });
        }
        e.stopPropagation();
      });
      
      // 将选区内容包裹在span中
      range.surroundContents(highlightEl);
      
      // 清除选择
      selection.removeAllRanges();
      
      // 记录高亮信息
      const highlightInfo = {
        id: highlightId,
        text: text,
        timestamp: Date.now()
      };
      
      this._highlightedTexts.push(highlightInfo);
      
      // 通知Flutter高亮已创建
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('onHighlightCreated', highlightInfo);
      }
      
      console.log('[MIKA] 文本高亮成功: ' + text);
      return highlightInfo;
    } catch (e) {
      console.error('[MIKA] 创建高亮时出错: ', e);
      return null;
    }
  },
  
  // 移除指定ID的高亮
  removeHighlight: function(highlightId) {
    const highlightEl = document.getElementById(highlightId);
    if (!highlightEl) {
      console.log('[MIKA] 未找到ID为 ' + highlightId + ' 的高亮元素');
      return false;
    }
    
    try {
      // 获取父节点
      const parent = highlightEl.parentNode;
      
      // 获取高亮元素中的所有子节点
      const fragment = document.createDocumentFragment();
      while (highlightEl.firstChild) {
        fragment.appendChild(highlightEl.firstChild);
      }
      
      // 将子节点插入到高亮元素的位置
      parent.replaceChild(fragment, highlightEl);
      
      // 从数组中移除高亮信息
      this._highlightedTexts = this._highlightedTexts.filter(item => item.id !== highlightId);
      
      // 通知Flutter高亮已移除
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('onHighlightRemoved', highlightId);
      }
      
      console.log('[MIKA] 移除高亮成功: ' + highlightId);
      return true;
    } catch (e) {
      console.error('[MIKA] 移除高亮时出错: ', e);
      return false;
    }
  },
  
  // 获取所有高亮内容
  getAllHighlights: function() {
    return this._highlightedTexts;
  },
  
  // 移除所有高亮
  removeAllHighlights: function() {
    try {
      // 复制数组以避免在遍历过程中修改
      const highlights = [...this._highlightedTexts];
      
      // 移除每个高亮
      for (const highlight of highlights) {
        this.removeHighlight(highlight.id);
      }
      
      // 以防有遗漏，通过类名查找所有高亮元素
      const remainingHighlights = document.querySelectorAll('.mika-highlight');
      remainingHighlights.forEach(el => {
        // 获取父节点
        const parent = el.parentNode;
        
        // 创建文档片段
        const fragment = document.createDocumentFragment();
        
        // 将高亮元素的内容移至片段
        while (el.firstChild) {
          fragment.appendChild(el.firstChild);
        }
        
        // 替换高亮元素
        parent.replaceChild(fragment, el);
      });
      
      // 清空数组
      this._highlightedTexts = [];
      
      // 通知Flutter所有高亮已移除
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('onAllHighlightsRemoved');
      }
      
      console.log('[MIKA] 所有高亮已移除');
      return true;
    } catch (e) {
      console.error('[MIKA] 移除所有高亮时出错: ', e);
      return false;
    }
  }
};

// 初始化渲染器
function initializeRenderer(options) {
  const { isDarkMode, fontSize, showVocabulary, apiBaseUrl, baseCSS, typographyCSS, uiCSS, economistCSS } = options;
  
  console.log('[MIKA] 开始初始化渲染器');
  console.log('[MIKA] 配置:', options);
  
  // 确保在初始化时强制使用浅色主题
  document.documentElement.setAttribute('data-theme', 'light');
  
  // 添加防止自动暗色模式的样式
  var preventAutoDarkStyle = document.createElement('style');
  preventAutoDarkStyle.id = 'prevent-auto-dark-style';
  preventAutoDarkStyle.textContent = `
    /* 禁用WebView自动应用的深色模式 */
    html {
      color-scheme: only light !important;
      forced-color-adjust: none !important;
    }
    
    /* 确保最高优先级应用我们的主题 */
    @media (prefers-color-scheme: dark) {
      :root:not([data-theme="dark"]) {
        color-scheme: only light !important;
      }
      
      :root[data-theme="dark"] {
        color-scheme: only dark !important;
      }
    }
  `;
  document.head.appendChild(preventAutoDarkStyle);
  
  // 更新META标签
  var colorSchemeMeta = document.querySelector('meta[name="color-scheme"]');
  if (!colorSchemeMeta) {
    colorSchemeMeta = document.createElement('meta');
    colorSchemeMeta.name = 'color-scheme';
    document.head.appendChild(colorSchemeMeta);
  }
  colorSchemeMeta.content = 'only light';
  
  // 更新主题颜色META标签
  var themeColorMeta = document.querySelector('meta[name="theme-color"]');
  if (!themeColorMeta) {
    themeColorMeta = document.createElement('meta');
    themeColorMeta.name = 'theme-color';
    document.head.appendChild(themeColorMeta);
  }
  themeColorMeta.content = '#ffffff';
  
  // 处理HTML内容 - 移除第一个h1标签
  console.log('[MIKA] 开始处理HTML内容');
  
  try {
    // 查找body下的第一个h1标签
    const body = document.body;
    if (body) {
      const h1Tags = body.getElementsByTagName('h1');
      if (h1Tags && h1Tags.length > 0) {
        const firstH1 = h1Tags[0];
        console.log('[MIKA] 找到第一个h1标签: ' + firstH1.textContent);
        
        // 移除该h1标签
        firstH1.parentNode.removeChild(firstH1);
        console.log('[MIKA] 已移除第一个h1标签');
      } else {
        console.log('[MIKA] 未找到h1标签');
      }
    } else {
      console.log('[MIKA] 未找到body元素');
    }
  } catch (e) {
    console.error('[MIKA] 处理HTML内容时出错', e);
  }

  // 添加CSS样式
  var baseStyles = document.getElementById('base-styles');
  if (!baseStyles) {
    // 添加基础样式
    var baseStyle = document.createElement('style');
    baseStyle.id = 'base-style';
    baseStyle.textContent = baseCSS;
    document.head.appendChild(baseStyle);
    
    // 添加排版样式
    var typographyStyle = document.createElement('style');
    typographyStyle.id = 'typography-style';
    typographyStyle.textContent = typographyCSS;
    document.head.appendChild(typographyStyle);
    
    // 添加UI样式
    var uiStyle = document.createElement('style');
    uiStyle.id = 'ui-style';
    uiStyle.textContent = uiCSS;
    document.head.appendChild(uiStyle);
    
    // 添加经济学人样式
    var economistStyle = document.createElement('style');
    economistStyle.id = 'economist-style';
    economistStyle.textContent = economistCSS;
    document.head.appendChild(economistStyle);
    
    // 添加动态配置样式
    const cssContent = document.createElement('style');
    cssContent.id = 'dynamic-styles';
    cssContent.textContent = `
      :root { 
        --font-size-base: ${fontSize}px;
      }
    `;
    document.head.appendChild(cssContent);
  }
  // 添加图片居中样式
  var imageStyle = document.createElement('style');
  imageStyle.id = 'image-center-style';
  imageStyle.textContent = `
    .article-content img {
      display: block;
      margin-left: auto;
      margin-right: auto;
      max-width: 100%;
      width: 100%;
      height: auto;
      box-sizing: border-box;
      padding: 10px 0;
    }
    
    /* 对大图片增加特殊处理 */
    .article-content figure {
      margin: 1em 0;
      width: 100%;
      text-align: center;
    }
    
    /* 图片说明文字样式 */
    .article-content figcaption {
      font-size: 0.85em;
      color: #666;
      text-align: center;
      margin-top: 5px;
    }
  `;
  document.head.appendChild(imageStyle);
  // 立即通知Flutter基本内容已准备好，可以移除遮罩
  console.log('[MIKA] 基本内容已处理完成，通知Flutter移除遮罩');
  if (window.flutter_inappwebview) {
    window.flutter_inappwebview.callHandler('contentRendered');
  }
                  
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
        img.style.backgroundColor = isDarkMode ? "#333" : "#f0f0f0";
      }
    }
  })();
  
  // 检查并准备所有图片路径
  (function prepareImagePaths() {
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
  
  // 修改文档属性来控制主题和词汇显示
  document.documentElement.setAttribute('data-theme', isDarkMode ? 'dark' : 'light');
  document.documentElement.setAttribute('data-show-vocabulary', showVocabulary);
  document.documentElement.setAttribute('data-font-size', fontSize);
  document.documentElement.style.setProperty('--font-size-base', fontSize + 'px');
  
  // 注入JS函数来更新主题
  window.setDarkMode = function(isDark) {
    // 调用mikaRenderer中的方法，保持向后兼容
    if (window.mikaRenderer && window.mikaRenderer.setDarkMode) {
      window.mikaRenderer.setDarkMode(isDark);
    } else {
      // 旧的实现作为备用方案
      document.documentElement.setAttribute('data-theme', isDark ? 'dark' : 'light');
      console.warn('[MIKA] mikaRenderer.setDarkMode未找到，使用备用方法');
    }
  };
  
  // 注入JS函数来更新词汇显示
  window.highlightVocabulary = function(show) {
    // 调用mikaRenderer中的方法，保持向后兼容
    if (window.mikaRenderer && window.mikaRenderer.setVocabularyVisibility) {
      window.mikaRenderer.setVocabularyVisibility(show);
    } else {
      // 旧的实现作为备用方案
      document.documentElement.setAttribute('data-show-vocabulary', show);
      console.warn('[MIKA] mikaRenderer.setVocabularyVisibility未找到，使用备用方法');
    }
  };
  
  // 确保setVocabularyVisibility函数存在(与highlightVocabulary保持一致)
  window.setVocabularyVisibility = function(show) {
    // 调用mikaRenderer中的方法，保持向后兼容
    if (window.mikaRenderer && window.mikaRenderer.setVocabularyVisibility) {
      window.mikaRenderer.setVocabularyVisibility(show);
    } else {
      // 旧的实现作为备用方案
      document.documentElement.setAttribute('data-show-vocabulary', show);
      console.warn('[MIKA] mikaRenderer.setVocabularyVisibility未找到，使用备用方法');
    }
  };
  
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
  
  // 添加禁用系统文本选择菜单的CSS，但允许文本选择
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
  
  // 修改selectionchange事件处理器 - 现在只负责检测选择和发送信息给Flutter
  document.addEventListener('selectionchange', function() {
    // 如果对话框已打开，不处理文本选择
    if (window.mikaDialogOpen) {
      console.log('[MIKA] 对话框已打开，不处理文本选择');
      return;
    }
    
    const selection = window.getSelection();
    if (selection.isCollapsed) {
      // 没有选择，通知Flutter清空选中的文本
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('saveSelectedText', '');
        window.flutter_inappwebview.callHandler('hideTextSelectionMenu');
      }
    } else {
      // 有文本被选中，但延迟显示菜单，确保选择已完成
      setTimeout(function() {
        // 再次检查对话框状态，因为可能在延迟期间打开了对话框
        if (window.mikaDialogOpen) {
          console.log('[MIKA] 检测到对话框已打开，不显示文本选择菜单');
          return;
        }
        
        const selection = window.getSelection();
        if (selection && !selection.isCollapsed) {
          const selectedText = selection.toString().trim();
          if (selectedText && selectedText.length > 0) {
            try {
              // 获取选区位置信息
              const range = selection.getRangeAt(0);
              const rect = range.getBoundingClientRect();
              
              // 计算选中区域的位置
              const x = rect.left + (rect.width / 2);
              const y = rect.bottom;
              const top = rect.top;
              const width = rect.width;
              const height = rect.height;
              
              // 向Flutter发送选中文本和坐标信息
              if (window.flutter_inappwebview) {
                // 保存选中文本
                window.flutter_inappwebview.callHandler('saveSelectedText', selectedText);
                
                // 发送选区坐标信息给Flutter处理
                console.log('[MIKA] 发送文本选择坐标到Flutter:', {
                  text: selectedText,
                  x: x,
                  y: y,
                  top: top,
                  left: rect.left,
                  width: width,
                  height: height,
                  viewportWidth: window.innerWidth,
                  viewportHeight: window.innerHeight
                });
                
                window.flutter_inappwebview.callHandler('textSelectionCoordinates', {
                  text: selectedText,
                  x: x,
                  y: y,
                  top: top,
                  left: rect.left,
                  width: width,
                  height: height,
                  viewportWidth: window.innerWidth,
                  viewportHeight: window.innerHeight
                });
                
                console.log('[MIKA] 选中文本: "' + selectedText + '", 长度: ' + selectedText.length + 
                            ', 位置: x=' + x + ', y=' + y);
              }
            } catch (e) {
              console.error('[MIKA] 处理文本选择时出错:', e);
            }
          }
        }
      }, 300); // 延迟以确保选择完全稳定
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
    // 如果有选择，使用Flutter的自定义菜单而非系统菜单
    const selection = window.getSelection();
    if (selection && !selection.isCollapsed) {
      // 允许选择完成，然后立即清除ActionMode
      setTimeout(function() {
        if (window.getSelection().toString().trim().length > 0) {
          // 触发自定义事件处理
          document.dispatchEvent(new Event('selectionchange'));
        }
      }, 200); // 延迟时间给系统更多时间完成选择
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
  
  // 应用初始设置
  window.mikaRenderer.setDarkMode(isDarkMode);
  window.mikaRenderer.setFontSize(fontSize);
  window.mikaRenderer.setVocabularyVisibility(showVocabulary);
  
  console.log('[MIKA] 渲染器初始化完成');
  
  return {
    showContent: function() {
      // 显示文本内容
      var invisibleStyle = document.getElementById('init-invisible-style');
      if (invisibleStyle) {
        invisibleStyle.innerHTML = 'html, body { opacity: 1 !important; transition: opacity 0.3s ease; }';
        console.log('文本内容显示中，添加淡入效果');
        
        // 监听过渡动画完成
        document.body.addEventListener('transitionend', function fadeInComplete() {
          // 移除监听器，避免重复触发
          document.body.removeEventListener('transitionend', fadeInComplete);
          
          invisibleStyle.remove();
          console.log('初始渲染完成，样式元素已移除');

          // 开始加载图片
          console.log('开始加载图片...');
          const images = document.querySelectorAll('img[data-fixed-src]');
          let loadedCount = 0;
          const totalImages = images.length;
          
          if (totalImages === 0) {
            console.log('没有需要加载的图片');
            return;
          }
          
          console.log('开始加载 ' + totalImages + ' 张图片');
          
          // 设置图片加载完成的检查
          const checkAllImagesLoaded = function() {
            if (loadedCount >= totalImages) {
              console.log('所有图片加载完成');
            }
          };
          
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
                checkAllImagesLoaded();
              };
              
              img.onerror = function() {
                loadedCount++;
                console.error('图片加载失败: ' + fixedSrc);
                // 添加错误提示样式
                img.style.backgroundColor = isDarkMode ? "#5c2b2b" : "#ffebee";
                img.style.border = '1px solid ' + (isDarkMode ? "#8c3b3b" : "#ffcdd2");
                checkAllImagesLoaded();
              };
              
              // 开始加载图片
              img.setAttribute('src', fixedSrc);
              img.removeAttribute('data-fixed-src');
            }
          }
        }, { once: true });
      }
    }
  };
}

// 在全局作用域中暴露函数
window.initializeRenderer = initializeRenderer;
