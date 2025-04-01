// 文章内容渲染器
class ArticleRenderer {
    constructor() {
        console.log('ArticleRenderer构造函数开始执行');
        
        // 获取内容容器元素
        this.content = document.getElementById('content');
        if (!this.content) {
            console.error('构造函数中未找到ID为"content"的元素');
            // 创建一个内容容器
            this.content = document.createElement('article');
            this.content.id = 'content';
            document.body.appendChild(this.content);
            console.log('已创建一个新的内容容器元素');
        }
        
        console.log('内容容器元素:', this.content);
        
        // 监听文档属性变化，用于主题切换
        const observer = new MutationObserver(mutations => {
            mutations.forEach(mutation => {
                if (mutation.attributeName === 'data-theme') {
                    this.updateTheme();
                }
                if (mutation.attributeName === 'data-font-size') {
                    this.updateFontSize();
                }
                if (mutation.attributeName === 'data-show-vocabulary') {
                    this.updateVocabulary();
                }
            });
        });
        
        observer.observe(document.documentElement, {
            attributes: true,
            attributeFilter: ['data-theme', 'data-font-size', 'data-show-vocabulary']
        });
        
        // 初始化设置
        this.updateTheme();
        this.updateFontSize();
        
        console.log('ArticleRenderer构造函数执行完成');
        
        // 尝试向Flutter发送日志
        this.logToFlutter('ArticleRenderer初始化完成');
    }
    
    // 向Flutter发送日志
    logToFlutter(message) {
        console.log(`[RENDERER] ${message}`);
        try {
            if (window.flutter_inappwebview) {
                window.flutter_inappwebview.callHandler('logMessage', message);
            }
        } catch (e) {
            console.warn('无法发送日志到Flutter:', e);
        }
    }
    
    // 更新主题
    updateTheme() {
        const isDarkMode = document.documentElement.getAttribute('data-theme') === 'dark';
        if (isDarkMode) {
            document.documentElement.classList.add('dark-theme');
        } else {
            document.documentElement.classList.remove('dark-theme');
        }
        this.logToFlutter(`主题已更新: ${isDarkMode ? '暗色' : '亮色'}`);
    }
    
    // 更新字体大小
    updateFontSize() {
        const fontSize = document.documentElement.getAttribute('data-font-size') || 16;
        document.documentElement.style.setProperty('--font-size', `${fontSize}px`);
        this.logToFlutter(`字体大小已更新: ${fontSize}px`);
    }
    
    // 更新词汇显示
    updateVocabulary() {
        const showVocabulary = document.documentElement.getAttribute('data-show-vocabulary') === 'true';
        const vocabularyWords = document.querySelectorAll('.vocabulary-word');
        vocabularyWords.forEach(word => {
            word.style.display = showVocabulary ? 'inline' : 'none';
        });
        this.logToFlutter(`词汇显示已更新: ${showVocabulary ? '显示' : '隐藏'}`);
    }
    
    // 加载文章内容
    async loadArticle(articleId) {
        try {
            if (!articleId) {
                throw new Error('文章ID为空');
            }
            
            this.logToFlutter(`开始加载文章，ID: ${articleId}`);
            
            if (!this.content) {
                this.logToFlutter('内容容器元素不存在，尝试重新获取');
                this.content = document.getElementById('content');
                if (!this.content) {
                    this.logToFlutter('创建新的内容容器元素');
                    this.content = document.createElement('article');
                    this.content.id = 'content';
                    document.getElementById('app-container').appendChild(this.content);
                }
            }
            
            // 显示加载中
            this.content.innerHTML = '<p>正在加载文章内容...</p>';
            
            // 构建API请求URL，确保使用/api前缀
            const apiUrl = `/api/articles/${articleId}/html`;
            this.logToFlutter(`请求文章内容: ${apiUrl}`);
            
            const response = await fetch(apiUrl, {
                headers: {
                    'Accept': 'text/html,application/xhtml+xml',
                    'X-Requested-With': 'XMLHttpRequest'
                }
            });
            this.logToFlutter(`收到响应: 状态 ${response.status}`);
            
            if (!response.ok) {
                const errorText = await response.text();
                this.logToFlutter(`响应错误: ${errorText}`);
                throw new Error(`文章加载失败: HTTP ${response.status}`);
            }
            
            const html = await response.text();
            this.logToFlutter(`成功获取HTML内容，长度: ${html.length}`);
            
            this.renderArticle(html);
            
            // 通知Flutter文章加载完成
            try {
                this.logToFlutter('通知Flutter文章加载完成');
                window.flutter_inappwebview.callHandler('onArticleLoaded');
            } catch (error) {
                this.logToFlutter(`无法通知Flutter文章已加载: ${error.message}`);
            }
        } catch (error) {
            this.logToFlutter(`加载文章错误: ${error.message}`);
            
            if (this.content) {
                this.content.innerHTML = `
                    <div style="text-align: center; padding: 20px;">
                        <h2 style="color: #e53935;">加载失败</h2>
                        <p>${error.message}</p>
                        <button onclick="window.renderer.loadArticle('${articleId}')">重试</button>
                    </div>
                `;
            }
            
            // 通知Flutter发生错误
            try {
                window.flutter_inappwebview.callHandler('onArticleError', error.message);
            } catch (e) {
                this.logToFlutter(`无法发送错误到Flutter: ${e.message}`);
            }
        }
    }
    
    // 渲染文章内容
    renderArticle(html) {
        if (!this.content) {
            this.logToFlutter('渲染文章失败：未找到内容容器元素');
            return;
        }
        
        this.content.innerHTML = html;
        this.logToFlutter('已渲染文章HTML内容');
        
        this.processImages();
        this.processVocabulary();
    }
    
    // 处理图片
    processImages() {
        const images = document.querySelectorAll('img');
        this.logToFlutter(`处理文章中的图片: ${images.length}张`);
        
        images.forEach(img => {
            img.onerror = () => {
                this.logToFlutter(`图片加载失败: ${img.src}`);
                img.src = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgdmlld0JveD0iMCAwIDIwMCAyMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PHJlY3Qgd2lkdGg9IjIwMCIgaGVpZ2h0PSIyMDAiIGZpbGw9IiNFNUU1RTUiLz48dGV4dCB4PSI1MCUiIHk9IjUwJSIgZG9taW5hbnQtYmFzZWxpbmU9Im1pZGRsZSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC1mYW1pbHk9InNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IiM5OTk5OTkiPkltYWdlIG5vdCBmb3VuZDwvdGV4dD48L3N2Zz4=';
            };
        });
    }
    
    // 从URL直接加载文章内容
    async loadArticleFromUrl(url) {
        try {
            if (!url) {
                throw new Error('文章URL为空');
            }
            
            this.logToFlutter(`开始从URL加载文章: ${url}`);
            
            if (!this.content) {
                this.logToFlutter('内容容器元素不存在，尝试重新获取');
                this.content = document.getElementById('content');
                if (!this.content) {
                    this.logToFlutter('创建新的内容容器元素');
                    this.content = document.createElement('article');
                    this.content.id = 'content';
                    document.getElementById('app-container').appendChild(this.content);
                }
            }
            
            // 显示加载中
            this.content.innerHTML = '<p>正在加载文章内容...</p>';
            
            this.logToFlutter(`请求文章内容: ${url}`);
            
            const response = await fetch(url, {
                headers: {
                    'Accept': 'text/html,application/xhtml+xml',
                    'X-Requested-With': 'XMLHttpRequest'
                }
            });
            this.logToFlutter(`收到响应: 状态 ${response.status}`);
            
            if (!response.ok) {
                const errorText = await response.text();
                this.logToFlutter(`响应错误: ${errorText}`);
                throw new Error(`文章加载失败: HTTP ${response.status}`);
            }
            
            const html = await response.text();
            this.logToFlutter(`成功获取HTML内容，长度: ${html.length}`);
            
            this.renderArticle(html);
            
            // 通知Flutter文章加载完成
            try {
                this.logToFlutter('通知Flutter文章加载完成');
                if (window.flutter_inappwebview) {
                    window.flutter_inappwebview.callHandler('onArticleLoaded');
                }
            } catch (error) {
                this.logToFlutter(`无法通知Flutter文章已加载: ${error.message}`);
            }
        } catch (error) {
            this.logToFlutter(`加载文章错误: ${error.message}`);
            
            if (this.content) {
                this.content.innerHTML = `
                    <div style="text-align: center; padding: 20px;">
                        <h2 style="color: #e53935;">加载失败</h2>
                        <p>${error.message}</p>
                        <button onclick="window.location.reload()">重试</button>
                    </div>
                `;
            }
            
            // 通知Flutter发生错误
            try {
                if (window.flutter_inappwebview) {
                    window.flutter_inappwebview.callHandler('onArticleError', error.message);
                }
            } catch (e) {
                this.logToFlutter(`无法发送错误到Flutter: ${e.message}`);
            }
        }
    }
    
    // 处理重点词汇
    async processVocabulary() {
        const showVocabulary = document.documentElement.getAttribute('data-show-vocabulary') === 'true';
        if (!showVocabulary) {
            this.logToFlutter('词汇突出显示已关闭，跳过处理');
            return;
        }
        
        try {
            // 使用URL查询参数获取文章ID，而不是从路径中获取
            const urlParams = new URLSearchParams(window.location.search);
            const articleId = urlParams.get('id');
            
            if (!articleId) {
                this.logToFlutter('处理词汇时未找到文章ID');
                return;
            }
            
            this.logToFlutter(`请求词汇列表，文章ID: ${articleId}`);
            
            const response = await fetch(`/api/articles/${articleId}/vocabulary`);
            
            if (!response.ok) {
                this.logToFlutter(`获取词汇失败: HTTP ${response.status}`);
                return;
            }
            
            const vocabulary = await response.json();
            this.logToFlutter(`成功获取词汇列表，数量: ${vocabulary.length}`);
            
            this.highlightVocabulary(vocabulary);
        } catch (error) {
            this.logToFlutter(`处理词汇时出错: ${error.message}`);
        }
    }
    
    // 高亮重点词汇
    highlightVocabulary(vocabulary) {
        if (!this.content || !vocabulary || vocabulary.length === 0) {
            this.logToFlutter('无法高亮词汇：内容元素不存在或词汇列表为空');
            return;
        }
        
        try {
            this.logToFlutter(`开始高亮 ${vocabulary.length} 个词汇`);
            let highlightCount = 0;
            
            vocabulary.forEach(word => {
                if (!word.word) {
                    this.logToFlutter(`无效词汇对象: ${JSON.stringify(word)}`);
                    return;
                }
                
                try {
                    // 转义正则表达式特殊字符
                    const escapedWord = word.word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
                    const regex = new RegExp(`\\b${escapedWord}\\b`, 'gi');
                    let html = this.content.innerHTML;
                    
                    // 检查是否有匹配
                    if (!regex.test(html)) {
                        this.logToFlutter(`未找到词汇: ${word.word}`);
                        return;
                    }
                    
                    // 重置正则表达式状态
                    regex.lastIndex = 0;
                    
                    this.content.innerHTML = html.replace(regex, match => {
                        highlightCount++;
                        return `<span class="vocabulary-word" data-word="${word.word}">${match}</span>`;
                    });
                } catch (e) {
                    this.logToFlutter(`处理词汇 "${word.word}" 时出错: ${e.message}`);
                }
            });
            
            this.logToFlutter(`成功高亮 ${highlightCount} 个词汇实例`);
            
            // 添加点击事件处理程序
            const vocabularyWords = this.content.querySelectorAll('.vocabulary-word');
            vocabularyWords.forEach(word => {
                word.addEventListener('click', () => {
                    const selectedWord = word.getAttribute('data-word');
                    this.logToFlutter(`用户点击词汇: ${selectedWord}`);
                    
                    try {
                        window.flutter_inappwebview.callHandler('onWordSelected', selectedWord);
                    } catch (e) {
                        this.logToFlutter(`无法发送词汇选择到Flutter: ${e.message}`);
                    }
                });
            });
        } catch (error) {
            this.logToFlutter(`高亮词汇出错: ${error.message}`);
        }
    }
}

// 创建全局调试日志函数
window.debugLog = function(message) {
    console.log(`[DEBUG] ${message}`);
    try {
        if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('logMessage', message);
        }
    } catch (e) {
        console.error('发送日志到Flutter失败:', e);
    }
};

// 捕获全局错误
window.onerror = function(message, source, lineno, colno, error) {
    const errorMsg = `JavaScript错误: ${message}, 在 ${source} 第 ${lineno} 行`;
    console.error(errorMsg, error);
    window.debugLog(errorMsg);
    return false;
};

// 等待DOM加载完成后再初始化
document.addEventListener('DOMContentLoaded', () => {
    try {
        // 获取文章ID
        const urlParams = new URLSearchParams(window.location.search);
        const articleId = urlParams.get('id');
        
        if (!articleId) {
            addDebugMessage('未获取到文章ID');
            return;
        }

        // 初始化渲染器并加载文章
        const renderer = new ArticleRenderer();
        renderer.loadArticle(articleId);
        
        // 记录初始化成功
        addDebugMessage(`渲染器初始化成功，正在加载文章ID: ${articleId}`);
    } catch (error) {
        addDebugMessage(`渲染器初始化失败: ${error.message}`);
        console.error('渲染器初始化失败:', error);
    }
}); 