import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class HomeController extends GetxController {
  final isChineseToEnglish = true.obs;
  final sourceText = ''.obs;
  final translatedText = ''.obs;
  final polishedText = ''.obs;
  final firstColumnWidth = 0.0.obs;
  final secondColumnWidth = 0.0.obs;

  late final TextEditingController sourceController;
  late final TextEditingController translatedController;

  static const String _firstColumnWidthKey = 'first_column_width';
  static const String _secondColumnWidthKey = 'second_column_width';

  @override
  void onInit() {
    super.onInit();
    sourceController = TextEditingController();
    translatedController = TextEditingController();
    _loadLayout();
  }

  Future<void> _loadLayout() async {
    final prefs = await SharedPreferences.getInstance();
    // 获取屏幕宽度
    final screenWidth = Get.width;
    final defaultWidth = screenWidth / 3;

    // 加载保存的宽度，如果没有则使用默认值
    firstColumnWidth.value = prefs.getDouble(_firstColumnWidthKey) ?? defaultWidth;
    secondColumnWidth.value = prefs.getDouble(_secondColumnWidthKey) ?? defaultWidth;
  }

  Future<void> _saveLayout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_firstColumnWidthKey, firstColumnWidth.value);
    await prefs.setDouble(_secondColumnWidthKey, secondColumnWidth.value);
  }

  void updateFirstColumnWidth(double width) {
    firstColumnWidth.value = width;
    _saveLayout();
  }

  void updateSecondColumnWidth(double width) {
    secondColumnWidth.value = width;
    _saveLayout();
  }

  void resetLayout() {
    final screenWidth = Get.width;
    final defaultWidth = screenWidth / 3;

    firstColumnWidth.value = defaultWidth;
    secondColumnWidth.value = defaultWidth;
    _saveLayout();
  }

  @override
  void onClose() {
    sourceController.dispose();
    translatedController.dispose();
    super.onClose();
  }

  void toggleTranslationDirection() {
    isChineseToEnglish.value = !isChineseToEnglish.value;
  }

  void copyToClipboard(String text) {
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      Get.snackbar(
        '已复制',
        '文本已复制到剪贴板',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
