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
    
    // 创建菜单元素
    const menu = document.createElement('div');
    menu.id = 'text-selection-menu';
    menu.style.cssText = `
      position: fixed !important;
      z-index: 2147483646 !important; /* 最高优先级，但低于Dialog的backdrop */
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
    
    // 在菜单对象中改进show方法
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
        
        // 确保菜单不会出现在屏幕顶部，始终在文本下方显示
        let finalY = y + 25; // 默认在文本下方显示
        
        // 如果菜单在底部会超出视口，则调整为在文本上方显示
        if (finalY + menuHeight > viewportHeight - 10) {
          finalY = y - menuHeight - 10;
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
  
  // 修改selectionchange事件处理器
  document.addEventListener('selectionchange', function() {
    // 如果对话框已打开，不处理文本选择
    if (window.mikaDialogOpen) {
      console.log('[MIKA] 对话框已打开，不处理文本选择');
      return;
    }
    
    const selection = window.getSelection();
    if (selection.isCollapsed) {
      // 没有选择，隐藏菜单
      if (window.textSelectionMenu) {
        window.textSelectionMenu.hide();
      }
      // 通知Flutter清空选中的文本
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('saveSelectedText', '');
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
              // 立即将选中的文本发送到Flutter
              if (window.flutter_inappwebview) {
                window.flutter_inappwebview.callHandler('saveSelectedText', selectedText);
              }
              
              // 检查是否有对话框或模态框
              const hasBackdrop = document.querySelector('.modal-backdrop, [class*="-backdrop"]');
              if (hasBackdrop) {
                console.log('[MIKA] 检测到backdrop元素，不显示文本选择菜单');
                return;
              }
              
              const range = selection.getRangeAt(0);
              const rect = range.getBoundingClientRect();
              
              // 计算选中区域的中间位置
              const x = rect.left + (rect.width / 2);
              const y = rect.bottom + 10; // 将菜单定位在文本下方
              
              if (window.textSelectionMenu) {
                window.textSelectionMenu.show(x, y);
              }
              
              // 将选中的文本发送到控制台，便于调试
              console.log('[MIKA] 选中文本: "' + selectedText + '", 长度: ' + selectedText.length);
            } catch (e) {
              console.error('[MIKA] 显示菜单时出错:', e);
            }
          }
        } else if (window.textSelectionMenu) {
          window.textSelectionMenu.hide();
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
