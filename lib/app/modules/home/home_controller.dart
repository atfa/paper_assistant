import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../../services/translation_service.dart';
import '../../services/ai_service.dart';
import '../../utils/text_splitter.dart';

class HomeController extends GetxController {
  final TranslationService _translationService = Get.find<TranslationService>();
  final AIService _aiService = Get.find<AIService>();

  final isChineseToEnglish = true.obs;
  final sourceText = ''.obs;
  final translatedText = ''.obs;
  final polishedText = ''.obs;
  final polishedTranslation = ''.obs;
  final firstColumnWidth = 0.0.obs;
  final secondColumnWidth = 0.0.obs;
  final isPolishing = false.obs;

  final sourceSentences = <String>[].obs;
  final translatedSentences = <String>[].obs;
  final polishedSentences = <String>[].obs;
  final polishedTranslationSentences = <String>[].obs;

  final sourceSentenceControllers = <TextEditingController>[].obs;
  final translatedSentenceControllers = <TextEditingController>[].obs;

  late final TextEditingController sourceController;
  late final TextEditingController translatedController;

  static const String _firstColumnWidthKey = 'first_column_width';
  static const String _secondColumnWidthKey = 'second_column_width';

  Timer? _debounceTimer;
  Timer? _autoSplitTimer;

  @override
  void onInit() {
    super.onInit();
    sourceController = TextEditingController();
    translatedController = TextEditingController();

    // 设置一个合理的默认列宽
    final screenWidth = Get.width;
    final defaultWidth = screenWidth / 3;
    firstColumnWidth.value = defaultWidth;
    secondColumnWidth.value = defaultWidth;

    // 加载已保存的布局配置
    _loadLayout();
    sourceController.addListener(_onSourceTextChanged);

    ever(sourceText, (_) {
      _autoSplitTimer?.cancel();
      _autoSplitTimer = Timer(const Duration(milliseconds: 500), () {
        _splitSourceText();
      });
    });
  }

  Future<void> _loadLayout() async {
    final prefs = await SharedPreferences.getInstance();
    // 获取屏幕宽度
    final screenWidth = Get.width;
    final defaultWidth = screenWidth / 3;
    final minWidth = screenWidth * 0.1; // 最小宽度
    final maxWidth = screenWidth * 0.6; // 最大宽度

    // 加载保存的宽度，如果没有或超出合理范围则使用默认值
    double firstWidth = prefs.getDouble(_firstColumnWidthKey) ?? defaultWidth;
    double secondWidth = prefs.getDouble(_secondColumnWidthKey) ?? defaultWidth;

    // 安全检查，确保宽度在合理范围内
    if (firstWidth < minWidth || firstWidth > maxWidth || firstWidth.isNaN) {
      firstWidth = defaultWidth;
    }

    if (secondWidth < minWidth || secondWidth > maxWidth || secondWidth.isNaN) {
      secondWidth = defaultWidth;
    }

    // 确保两列的总宽度不超过屏幕宽度的80%
    if (firstWidth + secondWidth > screenWidth * 0.8) {
      firstWidth = defaultWidth;
      secondWidth = defaultWidth;
    }

    firstColumnWidth.value = firstWidth;
    secondColumnWidth.value = secondWidth;
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
    firstColumnWidth.value = Get.width / 3;
    secondColumnWidth.value = Get.width / 3;
    _saveLayout();
  }

  @override
  void onClose() {
    sourceController.removeListener(_onSourceTextChanged);
    _debounceTimer?.cancel();
    sourceController.dispose();
    translatedController.dispose();
    for (var controller in sourceSentenceControllers) {
      controller.dispose();
    }
    for (var controller in translatedSentenceControllers) {
      controller.dispose();
    }
    _autoSplitTimer?.cancel();
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

      // 翻译完成后自动切分句子
      splitTranslatedText();
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

  Future<void> polishText() async {
    if (isPolishing.value) return;

    try {
      isPolishing.value = true;

      // 根据翻译方向选择要润色的文本
      final textToPolish = isChineseToEnglish.value
          ? translatedText.value // 中译英时润色第二列
          : sourceText.value; // 英译中时润色第一列

      if (textToPolish.isEmpty) {
        Get.snackbar(
          '提示',
          '请先输入或翻译需要润色的文本',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      print('开始润色文本...');
      print('润色文本长度: ${textToPolish.length}');

      // 构建提示词
      final prompt = '''
Please polish the following English text to meet doctoral-level academic writing standards. 
Make it more formal, precise, and suitable for academic papers. 
Maintain the original meaning while improving the language quality.
Do not output your thinking process, analysis process, please only output polished sentences:

$textToPolish
''';

      // 调用AI服务进行润色
      print('调用AI服务进行润色...');
      final response = await _aiService.generateText(prompt);
      print('收到润色结果，长度: ${response.length}');

      // 更新润色结果并确保UI刷新
      polishedText.value = response;
      print('润色完成，已更新UI');

      // 切分润色文本为句子
      splitPolishedText();

      // 自动将润色后的文本翻译成中文
      try {
        final translated = await _translationService.translate(
          text: response,
          source: 'en',
          target: 'zh',
        );
        polishedTranslation.value = translated;
        print('润色文本翻译完成');

        // 切分润色翻译文本为句子
        splitPolishedTranslationText();
      } catch (e) {
        print('Polish translation error: $e');
        polishedTranslation.value = '翻译失败，请重试';
      }
    } catch (e) {
      print('Polish error: $e');
      Get.snackbar(
        '润色失败',
        '请检查网络连接和AI服务配置: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
    } finally {
      isPolishing.value = false;
    }
  }

  void _splitSourceText() {
    if (sourceText.value.isEmpty) {
      sourceSentences.clear();
      sourceSentenceControllers.clear();
      return;
    }

    final sentences = TextSplitter.smartSplit(sourceText.value);

    for (var controller in sourceSentenceControllers) {
      controller.dispose();
    }

    final controllers = sentences.map((sentence) {
      final controller = TextEditingController(text: sentence);
      return controller;
    }).toList();

    sourceSentences.value = sentences;
    sourceSentenceControllers.value = controllers;

    if (translatedSentences.isNotEmpty && translatedSentences.length != sourceSentences.length) {
      translatedSentences.clear();
      translatedSentenceControllers.clear();
      for (var controller in translatedSentenceControllers) {
        controller.dispose();
      }
    }
  }

  void splitTranslatedText() {
    if (translatedText.value.isEmpty) {
      translatedSentences.clear();
      translatedSentenceControllers.clear();
      return;
    }

    final sentences = TextSplitter.smartSplit(translatedText.value);

    for (var controller in translatedSentenceControllers) {
      controller.dispose();
    }

    final controllers = sentences.map((sentence) {
      final controller = TextEditingController(text: sentence);
      return controller;
    }).toList();

    translatedSentences.value = sentences;
    translatedSentenceControllers.value = controllers;
  }

  void splitPolishedText() {
    if (polishedText.value.isEmpty) {
      polishedSentences.clear();
      return;
    }

    polishedSentences.value = TextSplitter.smartSplit(polishedText.value);
  }

  void splitPolishedTranslationText() {
    if (polishedTranslation.value.isEmpty) {
      polishedTranslationSentences.clear();
      return;
    }

    polishedTranslationSentences.value = TextSplitter.smartSplit(polishedTranslation.value);
  }

  void updateSourceTextFromSentences() {
    final sentences = sourceSentenceControllers.map((controller) => controller.text).toList();
    sourceText.value = sentences.join('\n');
  }

  void updateTranslatedTextFromSentences() {
    final sentences = translatedSentenceControllers.map((controller) => controller.text).toList();
    translatedText.value = sentences.join('\n');
  }
}
