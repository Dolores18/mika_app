import 'dart:io';
import 'package:flutter/material.dart';

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
    const Center(child: Text('学习')),
    const Center(child: Text('占位符')),
    const Center(child: Text('我的')),
  ];

  void toggleSearchState(bool isActive) {
    setState(() {
      _isSearchActive = isActive;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _currentIndex == 2
              ? WordLookupPage(onSearchStateChanged: toggleSearchState)
              : _pages[_currentIndex],
      bottomNavigationBar:
          _isSearchActive
              ? null
              : Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE4EC), // 使用与应用背景相同的淡粉色
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: BottomNavigationBar(
                    type: BottomNavigationBarType.fixed,
                    currentIndex: _currentIndex,
                    onTap: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    selectedItemColor: const Color(0xFF6b4bbd), // 与查询按钮相同的紫色
                    unselectedItemColor: Colors.grey[600],
                    backgroundColor: Colors.transparent, // 透明背景，让Container的颜色显示
                    elevation: 0, // 移除阴影
                    showSelectedLabels: true,
                    showUnselectedLabels: true,
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home),
                        label: '首页',
                      ),
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
                ),
              ),
    );
  }
}
