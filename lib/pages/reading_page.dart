import 'package:flutter/material.dart';
import '../models/article.dart';
import 'article_list_page.dart';
import 'article_detail_page.dart';
import '../services/article_service.dart';
import '../utils/logger.dart';

class ReadingPage extends StatefulWidget {
  const ReadingPage({super.key});

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  String _selectedSource = '全部';
  final List<String> _sources = ['全部', '经济学人'];
  final ArticleService _articleService = ArticleService();
  List<Map<String, dynamic>> _topics = [];
  bool _isLoading = true;
  String? _error;

  // 定义固定的主题分类数据
  final List<Map<String, dynamic>> _fixedTopics = [
    {'id': 1, 'topic': '政治', 'count': 0},
    {'id': 2, 'topic': '经济', 'count': 0},
    {'id': 3, 'topic': '科技', 'count': 0},
    {'id': 4, 'topic': '文化', 'count': 0},
    {'id': 5, 'topic': '其他', 'count': 0},
  ];

  final List<Article> _latestArticles = [
    Article(
      id: 1,
      title: '全球芯片竞争加剧，台湾面临压力',
      sectionId: 1,
      sectionTitle: '科技专栏',
      issueId: 1,
      issueDate: '2024-03-20',
      issueTitle: '2024年第12期',
      order: 1,
      path: '/articles/1',
      hasImages: false,
      audioUrl: 'https://example.com/audio/1.mp3',
      analysis: ArticleAnalysis(
        id: 1,
        articleId: 1,
        readingTime: 8,
        difficulty: Difficulty(
          level: 'B1-B2',
          description: '适合中级英语学习者阅读',
          features: ['包含常见词汇', '句子结构适中', '主题贴近生活'],
        ),
        topics: Topics(
          primary: '科技',
          secondary: ['半导体', '全球竞争'],
          keywords: ['芯片', '台湾', '科技竞争'],
        ),
        summary: Summary(
          short: '随着全球芯片需求增长，台湾半导体产业面临来自多方的竞争压力...',
          keyPoints: ['全球芯片需求增长', '台湾半导体产业面临竞争', '多方压力增加'],
        ),
        vocabulary: [
          Vocabulary(
            word: 'semiconductor',
            translation: '半导体',
            context: 'semiconductor industry',
            example: 'The semiconductor industry is facing challenges.',
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ),
    Article(
      id: 2,
      title: '中央银行如何应对通胀？',
      sectionId: 2,
      sectionTitle: '经济专栏',
      issueId: 2,
      issueDate: '2024-03-19',
      issueTitle: '2024年第11期',
      order: 1,
      path: '/articles/2',
      hasImages: false,
      audioUrl: 'https://example.com/audio/2.mp3',
      analysis: ArticleAnalysis(
        id: 2,
        articleId: 2,
        readingTime: 10,
        difficulty: Difficulty(
          level: 'C1-C2',
          description: '适合高级英语学习者阅读',
          features: ['专业术语较多', '复杂的经济概念', '深入的分析'],
        ),
        topics: Topics(
          primary: '经济',
          secondary: ['货币政策', '通货膨胀'],
          keywords: ['央行', '通胀', '货币政策'],
        ),
        summary: Summary(
          short: '面对持续上升的通胀压力，各国央行采取了不同的货币政策...',
          keyPoints: ['通胀压力上升', '各国央行政策差异', '货币政策调整'],
        ),
        vocabulary: [
          Vocabulary(
            word: 'inflation',
            translation: '通货膨胀',
            context: 'rising inflation',
            example: 'The central bank is concerned about rising inflation.',
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ),
    Article(
      id: 3,
      title: '气候变化与南极冰川融化',
      sectionId: 3,
      sectionTitle: '环境专栏',
      issueId: 3,
      issueDate: '2024-03-18',
      issueTitle: '2024年第10期',
      order: 1,
      path: '/articles/3',
      hasImages: true,
      audioUrl: 'https://example.com/audio/3.mp3',
      analysis: ArticleAnalysis(
        id: 3,
        articleId: 3,
        readingTime: 7,
        difficulty: Difficulty(
          level: 'B1-B2',
          description: '适合中级英语学习者阅读',
          features: ['科学术语解释', '数据可视化', '环境议题'],
        ),
        topics: Topics(
          primary: '环境',
          secondary: ['气候变化', '极地研究'],
          keywords: ['冰川', '气候变化', '南极'],
        ),
        summary: Summary(
          short: '最新研究表明，气候变化正在加速南极冰川的融化速度...',
          keyPoints: ['冰川融化加速', '气候变化影响', '最新研究结果'],
        ),
        vocabulary: [
          Vocabulary(
            word: 'glacier',
            translation: '冰川',
            context: 'Antarctic glacier',
            example: 'The Antarctic glaciers are melting at an alarming rate.',
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 尝试从API获取主题数量
      final apiTopics = await _articleService.getTopics();

      // 如果API成功返回，使用API返回的数据
      if (mounted) {
        setState(() {
          // 直接使用API返回的主题数据
          _topics = List.from(apiTopics);
          _isLoading = false;
        });
      }
    } catch (e) {
      log.e('加载主题失败', e);

      // 只有在API失败时才使用固定主题数据作为备选
      setState(() {
        _topics = List.from(_fixedTopics);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : CustomScrollView(
                  slivers: [
                    // 顶部标题
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '英语阅读',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                // TODO: 实现搜索功能
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 来源筛选条
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children:
                                _sources.map((source) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: ChoiceChip(
                                      label: Text(source),
                                      selected: _selectedSource == source,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _selectedSource = source;
                                          });
                                        }
                                      },
                                      backgroundColor: Colors.white.withOpacity(
                                        0.7,
                                      ),
                                      selectedColor: const Color(
                                        0xFF6b4bbd,
                                      ).withOpacity(0.2),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                      ),
                    ),

                    // 主题分类网格
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '主题分类',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 1.2,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                              itemCount: _topics.length,
                              itemBuilder: (context, index) {
                                final topic = _topics[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => ArticleListPage(
                                              initialTopic:
                                                  topic['id'].toString(),
                                            ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _getTopicIcon(topic['topic']),
                                          size: 32,
                                          color: const Color(0xFF6b4bbd),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          topic['topic'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '${topic['count']} 篇',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 最新文章
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '最新文章',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),
                            SizedBox(
                              height: 220,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _latestArticles.length,
                                itemBuilder: (context, index) {
                                  final article = _latestArticles[index];
                                  return _buildArticleCard(article);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 底部空间
                    const SliverToBoxAdapter(child: SizedBox(height: 30)),
                  ],
                ),
      ),
    );
  }

  Widget _buildArticleCard(Article article) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      ArticleDetailPage(articleId: article.id.toString()),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Text(
                article.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // 摘要
              if (article.analysis != null)
                Text(
                  article.analysis!.summary.short,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              // 文章信息
              Row(
                children: [
                  // 来源
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6b4bbd).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      article.sectionTitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6b4bbd),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 日期
                  Text(
                    article.issueDate,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 8),
                  // 阅读时间
                  if (article.analysis != null)
                    Text(
                      '${article.analysis!.readingTime} 分钟',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  const SizedBox(width: 8),
                  // 难度
                  if (article.analysis != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(
                          article.analysis!.difficulty.level,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        article.analysis!.difficulty.level,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getDifficultyColor(String level) {
    switch (level) {
      case 'A1-A2':
        return Colors.green;
      case 'B1-B2':
        return Colors.orange;
      case 'C1-C2':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTopicIcon(String topic) {
    switch (topic) {
      case '政治':
        return Icons.account_balance;
      case '经济':
        return Icons.monetization_on;
      case '科技':
        return Icons.devices;
      case '文化':
        return Icons.theater_comedy;
      case '其他':
        return Icons.more_horiz;
      default:
        return Icons.article;
    }
  }
}
