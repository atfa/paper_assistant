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

  /// 中文文本切分
  /// 按照句号、问号、叹号、分号进行切分
  static List<String> splitChineseText(String text) {
    if (text.isEmpty) return [];

    final RegExp pattern = RegExp(r'[。！？；]');
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
}
