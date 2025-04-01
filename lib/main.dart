import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'server/local_server.dart';
import 'utils/logger.dart';

import 'pages/word_lookup_page.dart';
import 'pages/reading_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  HttpOverrides.global = MyHttpOverrides();

  // 应用启动时就初始化本地服务器
  try {
    log.i('应用启动，初始化本地服务器');
    final serverUrl = await LocalServer.start();
    log.i('本地服务器已启动: $serverUrl');
  } catch (e) {
    log.e('启动本地服务器失败: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 语言助手',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: const Color(0xFFFCE4EC), // 淡粉色
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isSearchActive = false;

  final List<Widget> _pages = [
    const Center(child: Text('首页')),
    const ReadingPage(),
    const Center(child: Text('占位符')),
    const Center(child: Text('我的')),
  ];

  void toggleSearchState(bool isActive) {
    // 防止在构建过程中被调用导致错误
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isSearchActive != isActive) {
          setState(() {
            _isSearchActive = isActive;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentIndex == 2
          ? WordLookupPage(onSearchStateChanged: toggleSearchState)
          : _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          // 如果当前在搜索页面且搜索激活，先关闭搜索
          if (_currentIndex == 2 && _isSearchActive) {
            toggleSearchState(false);
          }
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: const Color(0xFF6b4bbd),
        unselectedItemColor: Colors.grey[600],
        backgroundColor: const Color(0xFFFCE4EC),
        elevation: 8,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: '学习'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'AI查询'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
