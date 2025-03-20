/// 文本切分工具类
class TextSplitter {
  /// 常见的英文缩写词列表，这些词中包含句点但不代表句子结束
  static final List<String> _commonAbbreviations = [
    'Mr.',
    'Mrs.',
    'Ms.',
    'Dr.',
    'Prof.',
    'U.S.',
    'U.S.A.',
    'U.K.',
    'P.R.C.',
    'I.R.S.',
    'e.g.',
    'i.e.',
    'etc.',
    'vs.',
    'p.m.',
    'a.m.',
    'Ph.D.',
    'M.D.',
    'B.A.',
    'M.A.',
    'B.S.',
    'M.S.',
    'Inc.',
    'Ltd.',
    'Co.',
    'Corp.',
    'Jan.',
    'Feb.',
    'Aug.',
    'Sept.',
    'Oct.',
    'Nov.',
    'Dec.',
    'St.',
    'Ave.',
    'Rd.',
    'Blvd.',
  ];

  /// 常见英文序号格式的正则表达式模式
  static final RegExp _numberingPattern = RegExp(r'(?:^|\s)(?:'
      r'[0-9]+\.|' // 数字序号 1. 2. 3.
      r'[a-z]\.|' // 小写字母序号 a. b. c.
      r'[A-Z]\.|' // 大写字母序号 A. B. C.
      r'[ivxlcdmIVXLCDM]+\.' // 罗马数字序号 i. ii. iii. IV. V.
      r')\s+');

  /// 中文文本切分
  /// 按照句号、问号、叹号、分号进行切分
  static List<String> splitChineseText(String text) {
    if (text.isEmpty) return [];

    final RegExp pattern = RegExp(r'[。！？]');
    final List<String> sentences = text.split(pattern).where((s) => s.trim().isNotEmpty).map((s) => s.trim()).toList();

    return sentences;
  }

  /// 英文文本切分
  /// 考虑缩写词中的句点，避免错误切分
  static List<String> splitEnglishText(String text) {
    if (text.isEmpty) return [];

    // 先处理常见的缩写词，将其中的句点替换为特殊标记
    String processedText = text;
    for (String abbr in _commonAbbreviations) {
      processedText = processedText.replaceAll(abbr, abbr.replaceAll('.', '@DOT@'));
    }

    // 使用正则表达式匹配句子结尾
    // 句点、问号或感叹号后跟空格和大写字母的模式
    final RegExp sentenceEndPattern = RegExp(r'[.!?]\s+(?=[A-Z])');

    // 切分文本
    final List<String> sentences =
        processedText.split(sentenceEndPattern).where((s) => s.trim().isNotEmpty).map((s) => s.trim()).toList();

    // 将特殊标记还原为句点
    return sentences.map((s) => s.replaceAll('@DOT@', '.')).toList();
  }

  /// 智能切分文本
  /// 自动检测文本主要语言并使用相应的切分方法
  static List<String> smartSplit(String text) {
    if (text.isEmpty) return [];

    // 简单判断文本主要语言
    bool isMainlyChinese = _isMainlyChinese(text);

    if (isMainlyChinese) {
      return splitChineseText(text);
    } else {
      return splitEnglishText(text);
    }
  }

  /// 判断文本是否主要为中文
  static bool _isMainlyChinese(String text) {
    if (text.isEmpty) return false;

    // 计算中文字符的数量
    int chineseCharCount = 0;
    for (int i = 0; i < text.length; i++) {
      // 中文字符的Unicode范围大致为：\u4e00-\u9fff
      if (text.codeUnitAt(i) >= 0x4e00 && text.codeUnitAt(i) <= 0x9fff) {
        chineseCharCount++;
      }
    }

    // 如果中文字符占比超过30%，则认为是主要为中文的文本
    return chineseCharCount / text.length > 0.3;
  }

  /// 中文文本切分（保留标点符号）
  /// 按照句号、问号、叹号、分号进行切分，保留标点符号
  static List<String> splitChineseTextPreservePunctuation(String text) {
    if (text.isEmpty) return [];

    final List<String> sentences = [];

    // 改进正则表达式，更精确匹配中文句子结尾的标点符号
    // 句号(。)、问号(？)、叹号(！)作为句子结束标记
    // 不以顿号(、)、逗号(，)、冒号(:)、省略号(…)等作为句子分隔
    final RegExp pattern = RegExp(r'([^。！？]*[。！？])');

    // 处理带引号的情况
    String processedText = text
        .replaceAll('"', '')
        .replaceAll('"', '')
        .replaceAll('「', '')
        .replaceAll('」', '')
        .replaceAll('"', '')
        .replaceAll('"', '');

    // 查找所有以标点结尾的句子
    final Iterable<Match> matches = pattern.allMatches(processedText);
    for (final Match match in matches) {
      final String sentence = match.group(1)!.trim();
      if (sentence.isNotEmpty) {
        sentences.add(sentence);
      }
    }

    // 处理最后一段没有标点的文本
    final String lastPart = processedText.split(pattern).where((s) => s.isNotEmpty).join('').trim();
    if (lastPart.isNotEmpty) {
      sentences.add(lastPart);
    }

    // 如果切分结果为空，则返回原文本作为一个句子
    if (sentences.isEmpty && text.trim().isNotEmpty) {
      return [text.trim()];
    }

    return sentences;
  }

  /// 英文文本切分（保留标点符号）
  /// 考虑缩写词中的句点，避免错误切分，同时保留句尾标点
  static List<String> splitEnglishTextPreservePunctuation(String text) {
    if (text.isEmpty) return [];

    // 先处理常见的缩写词，将其中的句点替换为特殊标记
    String processedText = text;
    for (String abbr in _commonAbbreviations) {
      processedText = processedText.replaceAll(abbr, abbr.replaceAll('.', '@DOT@'));
    }

    // 处理序号格式（如 "1. ", "a. ", "IV. " 等），避免被错误分割
    processedText = processedText.replaceAllMapped(_numberingPattern, (match) {
      return match.group(0)!.replaceAll('.', '@DOT@');
    });

    // 使用改进的正则表达式匹配完整句子（包括结尾标点）
    // 匹配模式：
    // 1. 以句点/问号/感叹号结尾，后接空格和大写字母的句子
    // 2. 或者文本末尾的任何内容
    final RegExp sentencePattern = RegExp(r'(.*?[.!?])\s+(?=[A-Z])|(.+$)');
    final List<String> sentences = [];

    // 查找所有匹配
    final Iterable<Match> matches = sentencePattern.allMatches(processedText);
    for (final Match match in matches) {
      final String? sentence = match.group(1) ?? match.group(2);
      if (sentence != null && sentence.trim().isNotEmpty) {
        sentences.add(sentence.trim());
      }
    }

    // 如果没有找到任何句子，将整个文本作为一个句子返回
    if (sentences.isEmpty && text.trim().isNotEmpty) {
      return [text.trim()];
    }

    // 将特殊标记还原为句点
    return sentences.map((s) => s.replaceAll('@DOT@', '.')).toList();
  }

  /// 智能切分文本（保留标点符号）
  /// 自动检测文本主要语言并使用相应的切分方法，保留标点符号
  static List<String> smartSplitPreservePunctuation(String text) {
    if (text.isEmpty) return [];

    // 简单判断文本主要语言
    bool isMainlyChinese = _isMainlyChinese(text);

    // 处理内容含有换行符的情况
    if (text.contains('\n')) {
      // 先按换行符分割
      List<String> lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
      List<String> result = [];

      // 对每一行按语言再次切分
      for (String line in lines) {
        if (isMainlyChinese) {
          result.addAll(splitChineseTextPreservePunctuation(line));
        } else {
          result.addAll(splitEnglishTextPreservePunctuation(line));
        }
      }

      return result;
    }

    // 无换行符情况下的处理
    if (isMainlyChinese) {
      return splitChineseTextPreservePunctuation(text);
    } else {
      return splitEnglishTextPreservePunctuation(text);
    }
  }
}
