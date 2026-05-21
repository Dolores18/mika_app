import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'server/local_server.dart';
import 'services/database_service.dart';
import 'utils/logger.dart';

import 'pages/word_lookup_page.dart';
import 'package:mika_app/pages/reading_page.dart' as reading_page;
import 'pages/profile_page.dart';

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

  // 初始化数据库
  try {
    log.i('初始化数据库');
    await DatabaseService.instance.database;
    log.i('数据库初始化成功');
  } catch (e) {
    log.e('数据库初始化失败: $e');
  }

  // 启动时清理上次遗留的音频缓存文件
  try {
    final tempDir = await getTemporaryDirectory();
    final files = tempDir.listSync();
    int count = 0;
    for (final file in files) {
      if (file is File && file.path.contains('audio_') && file.path.endsWith('.mp3')) {
        await file.delete();
        count++;
      }
    }
    if (count > 0) {
      log.i('[AudioCache] 启动时清理了 $count 个音频缓存文件');
    }
  } catch (e) {
    log.w('[AudioCache] 清理音频缓存失败: $e');
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
    return GetMaterialApp(
      title: 'AI 语言助手',
      theme: ThemeData(
        primarySwatch: Colors.grey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.grey,
          accentColor: const Color(0xFF6b4bbd),
          backgroundColor: Colors.white,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.grey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: const Color(0xFF121212), // 标准的深色主题背景
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.grey,
          accentColor: const Color(0xFF9D82E8), // 稍亮的紫色以提高对比度
          backgroundColor: const Color(0xFF121212),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system, // 跟随系统设置
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
    reading_page.ReadingPage(),
    const Center(child: Text('占位符')),
    ProfilePage(),
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
        selectedItemColor: Theme.of(context).colorScheme.secondary,
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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