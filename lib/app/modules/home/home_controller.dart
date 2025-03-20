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

    // 确保一启动就有至少一个空句子框
    _ensureAtLeastOneSourceSentence();

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
      // 确保清空后至少有一个空句子框
      _ensureAtLeastOneSourceSentence();
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

  // 确保至少有一个源文本句子编辑框
  void _ensureAtLeastOneSourceSentence() {
    if (sourceSentenceControllers.isEmpty) {
      final controller = TextEditingController();
      sourceSentenceControllers.add(controller);
      sourceSentences.add('');
    }
  }

  void _splitSourceText() {
    if (sourceText.value.isEmpty) {
      // 即使是空文本，也确保有一个空句子框
      for (var controller in sourceSentenceControllers) {
        controller.dispose();
      }
      final controller = TextEditingController();
      sourceSentences.value = [''];
      sourceSentenceControllers.value = [controller];
      return;
    }

    // 使用保留标点的方式切分文本
    final sentences = TextSplitter.smartSplitPreservePunctuation(sourceText.value);
    print('原文切分后的句子数量: ${sentences.length}');

    // 如果句子数量与当前控制器数量相同，检查每个句子是否需要更新
    if (sentences.length == sourceSentenceControllers.length) {
      bool hasChanged = false;
      for (int i = 0; i < sentences.length; i++) {
        if (sourceSentenceControllers[i].text != sentences[i]) {
          sourceSentenceControllers[i].text = sentences[i];
          hasChanged = true;
        }
      }

      // 如果没有变化，不需要进一步处理
      if (!hasChanged) {
        return;
      }
    } else {
      // 如果句子数量不同，完全重建控制器
      _rebuildSentenceControllers(sentences, true);
    }

    sourceSentences.value = sentences;

    // 如果翻译句子数量与源文本句子数量不一致，则重新分割翻译文本
    if (translatedSentenceControllers.isNotEmpty &&
        translatedSentenceControllers.length != sourceSentenceControllers.length) {
      _reSplitTranslatedText();
    }
  }

  void splitTranslatedText() {
    if (translatedText.value.isEmpty) {
      translatedSentences.clear();
      translatedSentenceControllers.clear();

      // 确保译文至少有一个空句子框
      translatedSentences.add('');
      translatedSentenceControllers.add(TextEditingController());
      return;
    }

    // 使用保留标点的方式切分文本
    final sentences = TextSplitter.smartSplitPreservePunctuation(translatedText.value);
    print('翻译切分后的句子数量: ${sentences.length}');

    // 如果句子数量与当前控制器数量相同，检查每个句子是否需要更新
    if (sentences.length == translatedSentenceControllers.length) {
      bool hasChanged = false;
      for (int i = 0; i < sentences.length; i++) {
        if (translatedSentenceControllers[i].text != sentences[i]) {
          translatedSentenceControllers[i].text = sentences[i];
          hasChanged = true;
        }
      }

      // 如果没有变化，不需要进一步处理
      if (!hasChanged) {
        return;
      }
    } else {
      // 如果句子数量不同，完全重建控制器
      _rebuildSentenceControllers(sentences, false);
    }

    translatedSentences.value = sentences;
  }

  // 重建句子控制器
  void _rebuildSentenceControllers(List<String> sentences, bool isSource) {
    List<TextEditingController> oldControllers =
        isSource ? List.from(sourceSentenceControllers) : List.from(translatedSentenceControllers);

    // 清理旧控制器
    for (var controller in oldControllers) {
      controller.dispose();
    }

    // 创建新控制器
    final newControllers = sentences.map((sentence) {
      return TextEditingController(text: sentence);
    }).toList();

    // 更新控制器列表
    if (isSource) {
      sourceSentenceControllers.value = newControllers;
    } else {
      translatedSentenceControllers.value = newControllers;
    }
  }

  // 根据源文本分割情况重新分割翻译文本
  void _reSplitTranslatedText() {
    if (translatedText.value.isEmpty) {
      // 清空并创建与源文本数量相同的空句子框
      for (var controller in translatedSentenceControllers) {
        controller.dispose();
      }

      final emptyControllers = List.generate(sourceSentenceControllers.length, (_) => TextEditingController());

      translatedSentences.value = List.filled(sourceSentenceControllers.length, '');
      translatedSentenceControllers.value = emptyControllers;
    } else {
      // 尝试根据当前文本重新切分
      splitTranslatedText();

      // 如果切分后数量仍不一致，则调整为与源文本相同数量
      if (translatedSentenceControllers.length != sourceSentenceControllers.length) {
        // 合并所有翻译文本
        final fullText = translatedSentenceControllers.map((c) => c.text).join('\n');

        // 清理旧控制器
        for (var controller in translatedSentenceControllers) {
          controller.dispose();
        }

        // 创建与源文本数量相同的控制器
        final int sourceCount = sourceSentenceControllers.length;
        List<TextEditingController> newControllers = [];
        List<String> newSentences = [];

        // 如果只有一个句子，直接使用完整文本
        if (sourceCount == 1) {
          newControllers.add(TextEditingController(text: fullText));
          newSentences.add(fullText);
        } else {
          // 尝试平均分配文本到每个句子框
          final List<String> parts = fullText.split('\n');
          if (parts.length >= sourceCount) {
            // 如果有足够的行，分配到每个控制器
            for (int i = 0; i < sourceCount; i++) {
              if (i < parts.length) {
                newControllers.add(TextEditingController(text: parts[i]));
                newSentences.add(parts[i]);
              } else {
                newControllers.add(TextEditingController());
                newSentences.add('');
              }
            }
          } else {
            // 如果行数不够，创建空控制器
            for (int i = 0; i < sourceCount; i++) {
              if (i == 0 && fullText.isNotEmpty) {
                newControllers.add(TextEditingController(text: fullText));
                newSentences.add(fullText);
              } else {
                newControllers.add(TextEditingController());
                newSentences.add('');
              }
            }
          }
        }

        translatedSentences.value = newSentences;
        translatedSentenceControllers.value = newControllers;
      }
    }
  }

  void splitPolishedText() {
    if (polishedText.value.isEmpty) {
      polishedSentences.clear();
      // 确保至少有一个空句子
      polishedSentences.add('');
      return;
    }

    // 使用保留标点的方式切分文本
    polishedSentences.value = TextSplitter.smartSplitPreservePunctuation(polishedText.value);
  }

  void splitPolishedTranslationText() {
    if (polishedTranslation.value.isEmpty) {
      polishedTranslationSentences.clear();
      // 确保至少有一个空句子
      polishedTranslationSentences.add('');
      return;
    }

    // 使用保留标点的方式切分文本
    polishedTranslationSentences.value = TextSplitter.smartSplitPreservePunctuation(polishedTranslation.value);
  }

  void updateSourceTextFromSentences() {
    // 获取每个句子框的内容
    final texts = sourceSentenceControllers.map((controller) => controller.text).toList();

    // 合并相邻的不含有句号的句子
    final mergedTexts = _mergeSentencesWithoutPunctuation(texts);

    // 如果合并后句子数量变化，重新创建控制器
    if (mergedTexts.length != texts.length) {
      _rebuildSentenceControllers(mergedTexts, true);
      sourceSentences.value = mergedTexts;
    }

    // 更新完整文本
    sourceText.value = sourceSentenceControllers.map((c) => c.text).join('\n');

    // 句子修改后，延迟500毫秒自动重新切分
    _autoSplitTimer?.cancel();
    _autoSplitTimer = Timer(const Duration(milliseconds: 500), () {
      _splitSourceText();
    });
  }

  void updateTranslatedTextFromSentences() {
    // 获取每个句子框的内容
    final texts = translatedSentenceControllers.map((controller) => controller.text).toList();

    // 合并相邻的不含有句号的句子
    final mergedTexts = _mergeSentencesWithoutPunctuation(texts);

    // 如果合并后句子数量变化，重新创建控制器
    if (mergedTexts.length != texts.length) {
      _rebuildSentenceControllers(mergedTexts, false);
      translatedSentences.value = mergedTexts;
    }

    // 更新完整文本
    translatedText.value = translatedSentenceControllers.map((c) => c.text).join('\n');

    // 句子修改后，延迟500毫秒自动重新切分
    _autoSplitTimer?.cancel();
    _autoSplitTimer = Timer(const Duration(milliseconds: 500), () {
      splitTranslatedText();
    });
  }

  // 合并相邻的不含有句号的句子
  List<String> _mergeSentencesWithoutPunctuation(List<String> sentences) {
    if (sentences.length <= 1) {
      return sentences;
    }

    List<String> result = [];
    String current = sentences[0];

    for (int i = 1; i < sentences.length; i++) {
      // 检查当前句子是否以标点符号结束
      bool endsWithPunctuation = _endsWithPunctuation(current);

      if (endsWithPunctuation) {
        // 如果以标点符号结束，保留为单独句子
        result.add(current);
        current = sentences[i];
      } else {
        // 如果不以标点符号结束，与下一句合并
        current = current.isEmpty ? sentences[i] : '$current ${sentences[i]}';
      }
    }

    // 添加最后一个句子
    if (current.isNotEmpty) {
      result.add(current);
    }

    return result;
  }

  // 检查字符串是否以中英文标点符号结束
  bool _endsWithPunctuation(String text) {
    if (text.isEmpty) return false;

    // 中文标点：。！？；
    // 英文标点：.!?;
    final punctuationRegex = RegExp(r'[。！？；.!?;]$');
    return punctuationRegex.hasMatch(text);
  }

  /// 清空所有内容
  void clearAllContent() {
    // 清空文本内容
    sourceText.value = '';
    translatedText.value = '';
    polishedText.value = '';
    polishedTranslation.value = '';

    // 清空控制器内容
    sourceController.clear();
    translatedController.clear();

    // 清空句子列表和控制器列表，并确保每列至少有一个空句子框
    _clearSentences();

    // 显示提示
    Get.snackbar(
      '已清空',
      '所有内容已清空',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  /// 清空句子列表和控制器
  void _clearSentences() {
    // 清空原文句子
    for (var controller in sourceSentenceControllers) {
      controller.dispose();
    }
    sourceSentences.clear();
    sourceSentenceControllers.clear();

    // 清空翻译句子
    for (var controller in translatedSentenceControllers) {
      controller.dispose();
    }
    translatedSentences.clear();
    translatedSentenceControllers.clear();

    // 清空润色句子
    polishedSentences.clear();
    polishedTranslationSentences.clear();

    // 确保每列至少有一个空句子框
    _ensureAtLeastOneSourceSentence();
    if (translatedSentenceControllers.isEmpty) {
      translatedSentences.add('');
      translatedSentenceControllers.add(TextEditingController());
    }
    if (polishedSentences.isEmpty) {
      polishedSentences.add('');
    }
    if (polishedTranslationSentences.isEmpty) {
      polishedTranslationSentences.add('');
    }
  }

  /// 清空特定的句子输入框
  void clearSentenceInput(int index, bool isSource) {
    if (isSource) {
      // 清空源文本的特定句子
      if (index >= 0 && index < sourceSentenceControllers.length) {
        sourceSentenceControllers[index].clear();
        // 更新源文本
        updateSourceTextFromSentences();
      }
    } else {
      // 清空翻译文本的特定句子
      if (index >= 0 && index < translatedSentenceControllers.length) {
        translatedSentenceControllers[index].clear();
        // 更新翻译文本
        updateTranslatedTextFromSentences();
      }
    }
  }
}
