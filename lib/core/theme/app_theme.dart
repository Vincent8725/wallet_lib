import 'package:flutter/material.dart';

class AppTheme {
  // 主色调 - 蓝色
  static const Color primaryColor = Color(0xFF1E88E5); // 使用Material蓝色500
  static const Color primaryLightColor = Color(0xFF6AB7FF); // 蓝色300
  static const Color primaryDarkColor = Color(0xFF005CB2); // 蓝色700
  
  // 辅助色
  static const Color accentColor = Color(0xFF03A9F4); // 浅蓝色500
  
  // 背景色
  static const Color backgroundColor = Colors.white;
  static const Color cardColor = Colors.white;
  
  // 文本颜色
  static const Color textPrimaryColor = Color(0xFF212121); // 深灰色900
  static const Color textSecondaryColor = Color(0xFF757575); // 灰色600
  
  // 错误颜色
  static const Color errorColor = Color(0xFFD32F2F); // 红色700
  
  // 成功颜色
  static const Color successColor = Color(0xFF388E3C); // 绿色700
  
  // 警告颜色
  static const Color warningColor = Color(0xFFFFA000); // 琥珀色700
  
  // 获取主题数据
  static ThemeData getTheme() {
    return ThemeData(
      // 主色调
      primaryColor: primaryColor,
      primaryColorLight: primaryLightColor,
      primaryColorDark: primaryDarkColor,
      
      // 应用整体颜色方案
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        error: errorColor,
        surface: cardColor,
      ),
      
      // 应用栏主题
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      
      // 卡片主题
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      
      // 文本按钮主题
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      
      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      
      // 底部导航栏主题
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      
      // 浮动按钮主题
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      
      // 切换开关主题
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withValues(alpha: 128); // 使用withValues替代withOpacity，128约等于255*0.5
          }
          return Colors.grey.withValues(alpha: 128);
        }),
      ),
      
      // 复选框主题
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      
      // 滑块主题
      sliderTheme: const SliderThemeData(
        activeTrackColor: primaryColor,
        thumbColor: primaryColor,
      ),
      
      // 进度指示器主题
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
      ),
      
      // 分割线颜色
      dividerColor: Colors.grey[300],
      
      // 移除自定义字体配置，使用系统默认字体
      // fontFamily: 'PingFang SC',
    );
  }
}