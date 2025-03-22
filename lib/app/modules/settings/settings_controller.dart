import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/translation_service.dart';
import '../../services/ai_service.dart';

class SettingsController extends GetxController {
  final TranslationService _translationService = Get.find();
  final AIService _aiService = Get.find();

  final modelFilter = ''.obs;
  final filteredModels = <String>[].obs;
  final isTestingGoogleKey = false.obs;
  final isTestingAIKey = false.obs;
  final googleKeyStatus = Rx<ValidationStatus?>(null);
  final aiKeyStatus = Rx<ValidationStatus?>(null);

  // 代理服务器设置
  final proxyEnabled = false.obs;
  final proxyServer = ''.obs;
  final proxyPort = ''.obs;

  // 代理相关的常量
  static const String _proxyEnabledKey = 'proxy_enabled';
  static const String _proxyServerKey = 'proxy_server';
  static const String _proxyPortKey = 'proxy_port';

  String get googleKey => _translationService.googleKey;
  AIProvider get aiProvider => _aiService.provider;
  String get aiKey => _aiService.apiKey;
  String get aiBaseUrl => _aiService.baseUrl;
  String get aiModel => _aiService.model;
  List<String> get availableModels => _aiService.availableModels;

  // 返回完整的代理地址
  String get proxyAddress {
    if (!proxyEnabled.value || proxyServer.value.isEmpty) {
      return '';
    }

    final port = proxyPort.value.isNotEmpty ? ':${proxyPort.value}' : '';
    return 'http://${proxyServer.value}$port';
  }

  // 返回没有协议的代理地址 (用于HttpClient)
  String get proxyAddressWithoutProtocol {
    if (!proxyEnabled.value || proxyServer.value.isEmpty) {
      return '';
    }

    final port = proxyPort.value.isNotEmpty ? ':${proxyPort.value}' : '';
    return '${proxyServer.value}$port';
  }

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    modelFilter.value = '';
    filteredModels.value = availableModels;

    // 加载代理服务器设置
    await _loadProxySettings();

    // 应用代理设置
    _applyProxySettings();
  }

  // 加载代理服务器设置
  Future<void> _loadProxySettings() async {
    final prefs = await SharedPreferences.getInstance();
    proxyEnabled.value = prefs.getBool(_proxyEnabledKey) ?? false;
    proxyServer.value = prefs.getString(_proxyServerKey) ?? '';

    // 修复类型不匹配问题：端口可能以整数或字符串形式存储
    try {
      // 尝试作为字符串读取
      final portStr = prefs.getString(_proxyPortKey);
      if (portStr != null) {
        proxyPort.value = portStr;
      } else {
        // 尝试作为整数读取并转换为字符串
        final portInt = prefs.getInt(_proxyPortKey);
        proxyPort.value = portInt?.toString() ?? '';
      }
    } catch (e) {
      print('Error loading proxy port: $e');
      proxyPort.value = '';
    }
  }

  // 应用代理服务器设置到全局
  void _applyProxySettings() {
    if (proxyEnabled.value && proxyServer.value.isNotEmpty) {
      // 应用代理设置到 Dio (所有使用 Dio 的服务)
      _aiService.setProxy(proxyAddress);
      _translationService.setProxy(proxyAddress);

      print('应用代理设置: $proxyAddress');
    } else {
      // 清除代理设置
      _aiService.setProxy(null);
      _translationService.setProxy(null);

      print('清除代理设置');
    }
  }

  // 设置代理服务器状态
  Future<void> setProxyEnabled(bool enabled) async {
    proxyEnabled.value = enabled;

    // 直接保存启用状态
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proxyEnabledKey, enabled);

    _applyProxySettings();
  }

  // 设置代理服务器地址
  Future<void> setProxyServer(String server) async {
    proxyServer.value = server.trim();

    // 直接保存服务器地址
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_proxyServerKey, proxyServer.value);

    if (proxyEnabled.value) {
      _applyProxySettings();
    }
  }

  // 设置代理服务器端口
  Future<void> setProxyPort(String port) async {
    // 确保端口是有效的数字
    if (port.isNotEmpty) {
      try {
        final portNum = int.parse(port);
        if (portNum < 0 || portNum > 65535) {
          Get.snackbar(
            '无效端口',
            '端口号必须在 0-65535 范围内',
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }
      } catch (e) {
        Get.snackbar(
          '无效端口',
          '请输入有效的数字',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
    }

    proxyPort.value = port;

    // 始终将端口作为字符串保存
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_proxyPortKey, port);

    if (proxyEnabled.value) {
      _applyProxySettings();
    }
  }

  void updateFilteredModels() {
    if (modelFilter.value.isEmpty) {
      filteredModels.value = availableModels;
    } else {
      filteredModels.value =
          availableModels.where((model) => model.toLowerCase().contains(modelFilter.value.toLowerCase())).toList();
    }
  }

  Future<void> setGoogleKey(String key) async {
    await _translationService.setGoogleKey(key);
    if (key.isEmpty) {
      googleKeyStatus.value = null;
    }
  }

  Future<void> validateGoogleKey() async {
    if (googleKey.isEmpty) return;

    isTestingGoogleKey.value = true;
    googleKeyStatus.value = null;

    try {
      await _translationService.translate(
        text: 'Hello',
        source: 'en',
        target: 'zh',
      );
      googleKeyStatus.value = ValidationStatus(
        isValid: true,
        message: 'Google Translate API Key 验证成功',
      );
    } catch (e) {
      googleKeyStatus.value = ValidationStatus(
        isValid: false,
        message: 'Google Translate API Key 无效: ${e.toString()}',
      );
    } finally {
      isTestingGoogleKey.value = false;
    }
  }

  Future<List<String>> validateGoogleKeyWithSteps() async {
    List<String> steps = [];

    steps.add('开始验证 Google Translate API Key...');

    if (googleKey.isEmpty) {
      steps.add('❌ API Key 为空，请先设置 API Key');
      return steps;
    }

    isTestingGoogleKey.value = true;
    googleKeyStatus.value = null;

    steps.add('正在初始化翻译服务...');

    try {
      steps.add('尝试翻译测试文本 "Hello" 从英文到中文...');

      await _translationService.translate(
        text: 'Hello',
        source: 'en',
        target: 'zh',
      );

      steps.add('✅ 翻译成功，API Key 有效');

      googleKeyStatus.value = ValidationStatus(
        isValid: true,
        message: 'Google Translate API Key 验证成功',
      );
    } catch (e) {
      steps.add('❌ 翻译失败: ${e.toString()}');

      googleKeyStatus.value = ValidationStatus(
        isValid: false,
        message: 'Google Translate API Key 无效: ${e.toString()}',
      );
    } finally {
      steps.add('验证过程结束');
      isTestingGoogleKey.value = false;
    }

    return steps;
  }

  Future<void> setAIProvider(AIProvider provider) async {
    await _aiService.setProvider(provider);
    aiKeyStatus.value = null;
  }

  Future<void> setAIKey(String key) async {
    await _aiService.setApiKey(key);
    if (key.isEmpty) {
      aiKeyStatus.value = null;
    }
  }

  Future<void> validateAIKey() async {
    if (aiKey.isEmpty) return;

    isTestingAIKey.value = true;
    aiKeyStatus.value = null;

    try {
      await _aiService.refreshAvailableModels();
      if (availableModels.isEmpty) {
        aiKeyStatus.value = ValidationStatus(
          isValid: false,
          message: '无法获取可用模型列表，请检查 API Key 是否正确',
        );
      } else {
        aiKeyStatus.value = ValidationStatus(
          isValid: true,
          message: '已成功获取 ${availableModels.length} 个可用模型',
        );
      }
    } catch (e) {
      aiKeyStatus.value = ValidationStatus(
        isValid: false,
        message: 'API Key 无效: ${e.toString()}',
      );
    } finally {
      isTestingAIKey.value = false;
    }
  }

  Future<void> setAIBaseUrl(String url) async {
    await _aiService.setBaseUrl(url);
    aiKeyStatus.value = null;
  }

  Future<void> setAIModel(String model) async {
    await _aiService.setModel(model);
  }

  void setModelFilter(String filter) {
    modelFilter.value = filter;
    updateFilteredModels();
  }

  // 添加一个刷新模型列表的方法，供用户手动触发
  Future<void> refreshModels() async {
    if (aiKey.isEmpty) {
      Get.snackbar(
        '提示',
        'API Key 为空，请先设置 API Key',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // 验证 API Key 并刷新模型列表
    await validateAIKey();
  }
}

class ValidationStatus {
  final bool isValid;
  final String message;

  ValidationStatus({
    required this.isValid,
    required this.message,
  });
}

class KeyStatus {
  final bool isValid;
  final String message;

  KeyStatus({required this.isValid, required this.message});
}
