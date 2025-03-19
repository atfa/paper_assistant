import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import '../../services/translation_service.dart';

class HomeController extends GetxController {
  final TranslationService _translationService = Get.find<TranslationService>();

  final isChineseToEnglish = true.obs;
  final sourceText = ''.obs;
  final translatedText = ''.obs;
  final polishedText = ''.obs;
  final firstColumnWidth = 300.0.obs;
  final secondColumnWidth = 300.0.obs;

  late final TextEditingController sourceController;
  late final TextEditingController translatedController;

  static const String _firstColumnWidthKey = 'first_column_width';
  static const String _secondColumnWidthKey = 'second_column_width';

  Timer? _debounceTimer;

  @override
  void onInit() {
    super.onInit();
    sourceController = TextEditingController();
    translatedController = TextEditingController();
    _loadLayout();
    sourceController.addListener(_onSourceTextChanged);
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
    firstColumnWidth.value = 300.0;
    secondColumnWidth.value = 300.0;
    _saveLayout();
  }

  @override
  void onClose() {
    sourceController.removeListener(_onSourceTextChanged);
    _debounceTimer?.cancel();
    sourceController.dispose();
    translatedController.dispose();
    super.onClose();
  }

  void toggleTranslationDirection() {
    isChineseToEnglish.value = !isChineseToEnglish.value;
    if (sourceText.value.isNotEmpty) {
      _translateText(sourceText.value);
    }
  }

  void _onSourceTextChanged() {
    final text = sourceController.text;
    sourceText.value = text;

    _debounceTimer?.cancel();

    if (text.isEmpty) {
      translatedText.value = '';
      translatedController.text = '';
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _translateText(text);
    });
  }

  Future<void> _translateText(String text) async {
    try {
      final source = isChineseToEnglish.value ? 'zh' : 'en';
      final target = isChineseToEnglish.value ? 'en' : 'zh';

      final translated = await _translationService.translate(
        text: text,
        source: source,
        target: target,
      );

      translatedText.value = translated;
      translatedController.text = translated;
    } catch (e) {
      print('Translation error: $e');
      Get.snackbar(
        '翻译失败',
        '请检查网络连接和API配置',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> copyToClipboard(String text) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      '已复制',
      '文本已复制到剪贴板',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
