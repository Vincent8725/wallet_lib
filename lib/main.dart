import 'package:flutter/material.dart';
import 'features/home/screens/main_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '多链钱包',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // 确保使用 material design 图标
        iconTheme: IconThemeData(
          color: Colors.blue,
        ),
      ),
      home: MainScreen(),
    );
  }
}
