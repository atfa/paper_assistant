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

    // 修改：优化复制内容的格式
    String formattedText = text;

    // 确定是复制哪一列的内容
    if (text == sourceText.value && sourceSentenceControllers.length > 0) {
      // 复制源文本列，处理段落
      formattedText = _formatCopyText(sourceSentenceControllers.map((controller) => controller.text).toList());
    } else if (text == translatedText.value && translatedSentenceControllers.length > 0) {
      // 复制翻译列，处理段落
      formattedText = _formatCopyText(translatedSentenceControllers.map((controller) => controller.text).toList());
    } else if (text == polishedText.value && polishedSentences.length > 0) {
      // 复制润色列，处理段落
      formattedText = _formatCopyText(polishedSentences.toList());
    } else if (text == polishedTranslation.value && polishedTranslationSentences.length > 0) {
      // 复制润色翻译列，处理段落
      formattedText = _formatCopyText(polishedTranslationSentences.toList());
    }

    await Clipboard.setData(ClipboardData(text: formattedText));
    Get.snackbar(
      '已复制',
      '文本已复制到剪贴板',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  // 格式化文本用于复制，处理段落分隔符
  String _formatCopyText(List<String> sentences) {
    List<String> paragraphs = [];
    String currentParagraph = '';

    for (String sentence in sentences) {
      if (sentence.trim().isEmpty) {
        // 空句子，跳过
        continue;
      } else if (sentence == '###NEW_PARAGRAPH###') {
        // 段落分隔符，保存当前段落并开始新段落
        if (currentParagraph.isNotEmpty) {
          paragraphs.add(currentParagraph);
          currentParagraph = '';
        }
      } else {
        // 普通句子，添加到当前段落
        if (currentParagraph.isEmpty) {
          currentParagraph = sentence;
        } else {
          currentParagraph += ' ' + sentence;
        }
      }
    }

    // 添加最后一个段落
    if (currentParagraph.isNotEmpty) {
      paragraphs.add(currentParagraph);
    }

    // 用换行符连接段落
    return paragraphs.join('\n\n');
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

    // 首先处理换行符，将文本分成段落
    List<String> paragraphs = sourceText.value.split('\n');
    List<String> allItems = [];

    // 遍历段落并添加分隔符
    for (int i = 0; i < paragraphs.length; i++) {
      String paragraph = paragraphs[i].trim();
      if (paragraph.isEmpty) {
        // 忽略空段落，但仍添加分隔符
        if (i > 0 && i < paragraphs.length - 1 && allItems.isNotEmpty) {
          allItems.add('###NEW_PARAGRAPH###');
        }
        continue;
      }

      // 切分段落中的句子
      List<String> sentences = TextSplitter.smartSplitPreservePunctuation(paragraph);
      allItems.addAll(sentences);

      // 在非最后一个段落后添加段落分隔符
      if (i < paragraphs.length - 1) {
        allItems.add('###NEW_PARAGRAPH###');
      }
    }

    // 移除首尾的空分隔符
    while (allItems.isNotEmpty && allItems.first == '###NEW_PARAGRAPH###') {
      allItems.removeAt(0);
    }
    while (allItems.isNotEmpty && allItems.last == '###NEW_PARAGRAPH###') {
      allItems.removeLast();
    }

    // 确保列表不为空
    if (allItems.isEmpty) {
      allItems.add('');
    }

    print('原文切分后的项目数量: ${allItems.length}');

    // 重建控制器
    _rebuildSentenceControllers(allItems, true);
    sourceSentences.value = allItems;

    // 如果翻译句子数量与源文本句子数量不一致，则重新分割翻译文本
    if (translatedSentenceControllers.isNotEmpty &&
        translatedSentenceControllers.length != sourceSentenceControllers.length) {
      _reSplitTranslatedText();
    }

    // 在切分完成后，触发翻译功能
    if (sourceText.value.isNotEmpty) {
      _translateText(sourceText.value);
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

    // 首先处理换行符，将文本分成段落
    List<String> paragraphs = translatedText.value.split('\n');
    List<String> allItems = [];

    // 遍历段落并添加分隔符
    for (int i = 0; i < paragraphs.length; i++) {
      String paragraph = paragraphs[i].trim();
      if (paragraph.isEmpty) {
        // 忽略空段落，但仍添加分隔符
        if (i > 0 && i < paragraphs.length - 1 && allItems.isNotEmpty) {
          allItems.add('###NEW_PARAGRAPH###');
        }
        continue;
      }

      // 切分段落中的句子
      List<String> sentences = TextSplitter.smartSplitPreservePunctuation(paragraph);
      allItems.addAll(sentences);

      // 在非最后一个段落后添加段落分隔符
      if (i < paragraphs.length - 1) {
        allItems.add('###NEW_PARAGRAPH###');
      }
    }

    // 移除首尾的空分隔符
    while (allItems.isNotEmpty && allItems.first == '###NEW_PARAGRAPH###') {
      allItems.removeAt(0);
    }
    while (allItems.isNotEmpty && allItems.last == '###NEW_PARAGRAPH###') {
      allItems.removeLast();
    }

    // 确保列表不为空
    if (allItems.isEmpty) {
      allItems.add('');
    }

    print('翻译切分后的项目数量: ${allItems.length}');

    // 重建控制器
    _rebuildSentenceControllers(allItems, false);
    translatedSentences.value = allItems;
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

    // 首先处理换行符，将文本分成段落
    List<String> paragraphs = polishedText.value.split('\n');
    List<String> allItems = [];

    // 遍历段落并添加分隔符
    for (int i = 0; i < paragraphs.length; i++) {
      String paragraph = paragraphs[i].trim();
      if (paragraph.isEmpty) {
        // 忽略空段落，但仍添加分隔符
        if (i > 0 && i < paragraphs.length - 1 && allItems.isNotEmpty) {
          allItems.add('###NEW_PARAGRAPH###');
        }
        continue;
      }

      // 切分段落中的句子
      List<String> sentences = TextSplitter.smartSplitPreservePunctuation(paragraph);
      allItems.addAll(sentences);

      // 在非最后一个段落后添加段落分隔符
      if (i < paragraphs.length - 1) {
        allItems.add('###NEW_PARAGRAPH###');
      }
    }

    // 移除首尾的空分隔符
    while (allItems.isNotEmpty && allItems.first == '###NEW_PARAGRAPH###') {
      allItems.removeAt(0);
    }
    while (allItems.isNotEmpty && allItems.last == '###NEW_PARAGRAPH###') {
      allItems.removeLast();
    }

    // 确保列表不为空
    if (allItems.isEmpty) {
      allItems.add('');
    }

    polishedSentences.value = allItems;
  }

  void splitPolishedTranslationText() {
    if (polishedTranslation.value.isEmpty) {
      polishedTranslationSentences.clear();
      // 确保至少有一个空句子
      polishedTranslationSentences.add('');
      return;
    }

    // 首先处理换行符，将文本分成段落
    List<String> paragraphs = polishedTranslation.value.split('\n');
    List<String> allItems = [];

    // 遍历段落并添加分隔符
    for (int i = 0; i < paragraphs.length; i++) {
      String paragraph = paragraphs[i].trim();
      if (paragraph.isEmpty) {
        // 忽略空段落，但仍添加分隔符
        if (i > 0 && i < paragraphs.length - 1 && allItems.isNotEmpty) {
          allItems.add('###NEW_PARAGRAPH###');
        }
        continue;
      }

      // 切分段落中的句子
      List<String> sentences = TextSplitter.smartSplitPreservePunctuation(paragraph);
      allItems.addAll(sentences);

      // 在非最后一个段落后添加段落分隔符
      if (i < paragraphs.length - 1) {
        allItems.add('###NEW_PARAGRAPH###');
      }
    }

    // 移除首尾的空分隔符
    while (allItems.isNotEmpty && allItems.first == '###NEW_PARAGRAPH###') {
      allItems.removeAt(0);
    }
    while (allItems.isNotEmpty && allItems.last == '###NEW_PARAGRAPH###') {
      allItems.removeLast();
    }

    // 确保列表不为空
    if (allItems.isEmpty) {
      allItems.add('');
    }

    polishedTranslationSentences.value = allItems;
  }

  void updateSourceTextFromSentences() {
    // 获取每个句子框的内容
    final texts = sourceSentenceControllers.map((controller) => controller.text).toList();

    // 合并相邻的不含有句号的句子（忽略段落分隔符）
    final mergedTexts = _mergeSentencesWithoutPunctuation(texts);

    // 如果合并后句子数量变化，重新创建控制器
    if (mergedTexts.length != texts.length) {
      _rebuildSentenceControllers(mergedTexts, true);
      sourceSentences.value = mergedTexts;
    }

    // 更新完整文本，段落分隔符转换为换行符
    sourceText.value = _convertSentencesToFullText(sourceSentenceControllers.map((c) => c.text).toList());

    // 句子修改后，延迟500毫秒自动重新切分
    _autoSplitTimer?.cancel();
    _autoSplitTimer = Timer(const Duration(milliseconds: 500), () {
      _splitSourceText();
    });
  }

  void updateTranslatedTextFromSentences() {
    // 获取每个句子框的内容
    final texts = translatedSentenceControllers.map((controller) => controller.text).toList();

    // 合并相邻的不含有句号的句子（忽略段落分隔符）
    final mergedTexts = _mergeSentencesWithoutPunctuation(texts);

    // 如果合并后句子数量变化，重新创建控制器
    if (mergedTexts.length != texts.length) {
      _rebuildSentenceControllers(mergedTexts, false);
      translatedSentences.value = mergedTexts;
    }

    // 更新完整文本，段落分隔符转换为换行符
    translatedText.value = _convertSentencesToFullText(translatedSentenceControllers.map((c) => c.text).toList());

    // 句子修改后，延迟500毫秒自动重新切分
    _autoSplitTimer?.cancel();
    _autoSplitTimer = Timer(const Duration(milliseconds: 500), () {
      splitTranslatedText();
    });
  }

  // 将句子列表转换为完整文本，处理段落分隔符
  String _convertSentencesToFullText(List<String> sentences) {
    List<String> paragraphs = [];
    String currentParagraph = '';

    for (String sentence in sentences) {
      if (sentence == '###NEW_PARAGRAPH###') {
        // 段落分隔符，保存当前段落并开始新段落
        if (currentParagraph.isNotEmpty) {
          paragraphs.add(currentParagraph);
          currentParagraph = '';
        } else {
          // 连续的段落分隔符，添加空段落
          paragraphs.add('');
        }
      } else if (sentence.trim().isNotEmpty) {
        // 普通句子，添加到当前段落
        if (currentParagraph.isEmpty) {
          currentParagraph = sentence;
        } else {
          currentParagraph += currentParagraph.endsWith('\n') ? sentence : ' ' + sentence;
        }
      }
    }

    // 添加最后一个段落
    if (currentParagraph.isNotEmpty) {
      paragraphs.add(currentParagraph);
    }

    // 用换行符连接段落
    return paragraphs.join('\n');
  }

  // 修改合并相邻句子的方法，忽略段落分隔符
  List<String> _mergeSentencesWithoutPunctuation(List<String> sentences) {
    if (sentences.length <= 1) {
      return sentences;
    }

    List<String> result = [];
    String current = sentences[0];

    for (int i = 1; i < sentences.length; i++) {
      // 如果是段落分隔符，保留并重置当前句子
      if (sentences[i] == '###NEW_PARAGRAPH###' || current == '###NEW_PARAGRAPH###') {
        result.add(current);
        current = sentences[i];
        continue;
      }

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
    if (current.isNotEmpty || current == '###NEW_PARAGRAPH###') {
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

  /// 处理在输入框中按下回车键创建新段落
  void handleEnterKeyPressed(int index, bool isSource) {
    if (isSource) {
      // 处理源文本输入框中的回车
      if (index >= 0 && index < sourceSentenceControllers.length) {
        // 获取当前文本
        String currentText = sourceSentenceControllers[index].text;

        // 获取光标位置
        TextEditingController controller = sourceSentenceControllers[index];
        int cursorPosition = controller.selection.baseOffset;

        // 如果光标位置无效，则在末尾添加段落分隔符
        if (cursorPosition < 0 || cursorPosition >= currentText.length) {
          // 在当前句子后面添加段落分隔符
          _insertParagraphBreak(index, isSource);
          return;
        }

        // 分割文本
        String beforeCursor = currentText.substring(0, cursorPosition);
        String afterCursor = currentText.substring(cursorPosition);

        // 更新当前句子内容为光标前的文本
        sourceSentenceControllers[index].text = beforeCursor;

        // 在当前位置插入段落分隔符
        List<String> newSentences = List.from(sourceSentences);
        List<TextEditingController> newControllers = List.from(sourceSentenceControllers);

        // 在当前句子后添加段落分隔符
        newSentences.insert(index + 1, '###NEW_PARAGRAPH###');
        newControllers.insert(index + 1, TextEditingController(text: '###NEW_PARAGRAPH###'));

        // 如果光标后还有文本，则在段落分隔符后创建新句子
        if (afterCursor.isNotEmpty) {
          newSentences.insert(index + 2, afterCursor);
          newControllers.insert(index + 2, TextEditingController(text: afterCursor));
        }

        // 更新列表
        sourceSentences.value = newSentences;
        sourceSentenceControllers.value = newControllers;

        // 更新完整文本
        updateSourceTextFromSentences();
      }
    } else {
      // 处理翻译文本输入框中的回车
      if (index >= 0 && index < translatedSentenceControllers.length) {
        // 获取当前文本
        String currentText = translatedSentenceControllers[index].text;

        // 获取光标位置
        TextEditingController controller = translatedSentenceControllers[index];
        int cursorPosition = controller.selection.baseOffset;

        // 如果光标位置无效，则在末尾添加段落分隔符
        if (cursorPosition < 0 || cursorPosition >= currentText.length) {
          // 在当前句子后面添加段落分隔符
          _insertParagraphBreak(index, isSource);
          return;
        }

        // 分割文本
        String beforeCursor = currentText.substring(0, cursorPosition);
        String afterCursor = currentText.substring(cursorPosition);

        // 更新当前句子内容为光标前的文本
        translatedSentenceControllers[index].text = beforeCursor;

        // 在当前位置插入段落分隔符
        List<String> newSentences = List.from(translatedSentences);
        List<TextEditingController> newControllers = List.from(translatedSentenceControllers);

        // 在当前句子后添加段落分隔符
        newSentences.insert(index + 1, '###NEW_PARAGRAPH###');
        newControllers.insert(index + 1, TextEditingController(text: '###NEW_PARAGRAPH###'));

        // 如果光标后还有文本，则在段落分隔符后创建新句子
        if (afterCursor.isNotEmpty) {
          newSentences.insert(index + 2, afterCursor);
          newControllers.insert(index + 2, TextEditingController(text: afterCursor));
        }

        // 更新列表
        translatedSentences.value = newSentences;
        translatedSentenceControllers.value = newControllers;

        // 更新完整文本
        updateTranslatedTextFromSentences();
      }
    }
  }

  /// 在指定位置后插入段落分隔符
  void _insertParagraphBreak(int index, bool isSource) {
    if (isSource) {
      // 在源文本中插入段落分隔符
      if (index >= 0 && index < sourceSentenceControllers.length) {
        // 创建新的句子列表和控制器列表
        List<String> newSentences = List.from(sourceSentences);
        List<TextEditingController> newControllers = List.from(sourceSentenceControllers);

        // 插入段落分隔符
        newSentences.insert(index + 1, '###NEW_PARAGRAPH###');
        newControllers.insert(index + 1, TextEditingController(text: '###NEW_PARAGRAPH###'));

        // 更新列表
        sourceSentences.value = newSentences;
        sourceSentenceControllers.value = newControllers;

        // 更新完整文本
        updateSourceTextFromSentences();
      }
    } else {
      // 在翻译文本中插入段落分隔符
      if (index >= 0 && index < translatedSentenceControllers.length) {
        // 创建新的句子列表和控制器列表
        List<String> newSentences = List.from(translatedSentences);
        List<TextEditingController> newControllers = List.from(translatedSentenceControllers);

        // 插入段落分隔符
        newSentences.insert(index + 1, '###NEW_PARAGRAPH###');
        newControllers.insert(index + 1, TextEditingController(text: '###NEW_PARAGRAPH###'));

        // 更新列表
        translatedSentences.value = newSentences;
        translatedSentenceControllers.value = newControllers;

        // 更新完整文本
        updateTranslatedTextFromSentences();
      }
    }
  }
}
