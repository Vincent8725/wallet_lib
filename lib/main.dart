import 'package:flutter/material.dart';
import 'features/home/screens/main_screen.dart';
import 'core/theme/app_theme.dart'; // 导入主题配置

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '数字钱包',
      theme: AppTheme.getTheme(), // 应用蓝色主题
      // theme: ThemeData(
      //   primarySwatch: Colors.blue,
      //   visualDensity: VisualDensity.adaptivePlatformDensity,
      //   // 确保使用 material design 图标
      //   iconTheme: const IconThemeData(
      //     color: Colors.blue,
      //   ),
      // ),
      home: MainScreen(),
    );
  }
}
