import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/word_lookup_page.dart';

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
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
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 语言助手',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isSearchActive = false; // 添加搜索状态变量

  // 页面列表
  final List<Widget> _pages = [
    const Center(child: Text('首页')),
    const Center(child: Text('学习')),
    const Center(child: Text('占位符')), // 占位符，实际会在build方法中替换
    const Center(child: Text('我的')),
  ];

  // 切换搜索状态的方法
  void toggleSearchState(bool isActive) {
    setState(() {
      _isSearchActive = isActive;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 移除AppBar，现代应用更简洁
      body:
          _currentIndex == 2
              ? WordLookupPage(onSearchStateChanged: toggleSearchState)
              : _pages[_currentIndex],
      bottomNavigationBar:
          _isSearchActive
              ? null // 当搜索激活时隐藏导航栏
              : BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                selectedItemColor: Colors.deepPurple,
                unselectedItemColor: Colors.grey,
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.school),
                    label: '学习',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.search),
                    label: 'AI查询',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person),
                    label: '我的',
                  ),
                ],
              ),
    );
  }
}
