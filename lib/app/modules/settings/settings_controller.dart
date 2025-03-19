import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  final isTestingNetwork = false.obs;
  final networkTestResult = ''.obs;
  final isTestingNetworkWithHttp = false.obs;
  final networkTestResultWithHttp = ''.obs;

  String get googleKey => _translationService.googleKey;
  AIProvider get aiProvider => _aiService.provider;
  String get aiKey => _aiService.apiKey;
  String get aiBaseUrl => _aiService.baseUrl;
  String get aiModel => _aiService.model;
  List<String> get availableModels => _aiService.availableModels;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    modelFilter.value = '';
    filteredModels.value = availableModels;
    await validateGoogleKey();
    await validateAIKey();
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
    if (key.isNotEmpty) {
      await validateGoogleKey();
    } else {
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

  Future<void> setAIProvider(AIProvider provider) async {
    await _aiService.setProvider(provider);
    aiKeyStatus.value = null;
    if (aiKey.isNotEmpty) {
      await validateAIKey();
    }
  }

  Future<void> setAIKey(String key) async {
    await _aiService.setApiKey(key);
    if (key.isNotEmpty) {
      await validateAIKey();
    } else {
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
    if (aiKey.isNotEmpty) {
      await validateAIKey();
    }
  }

  Future<void> setAIModel(String model) async {
    await _aiService.setModel(model);
  }

  void setModelFilter(String filter) {
    modelFilter.value = filter;
    updateFilteredModels();
  }

  Future<void> testNetworkConnection() async {
    isTestingNetwork.value = true;
    networkTestResult.value = '';

    try {
      final result = await _aiService.testNetworkConnection();
      if (result) {
        networkTestResult.value = '网络连接正常';
        Get.snackbar(
          '网络测试',
          '网络连接正常',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        networkTestResult.value = '网络连接失败';
        Get.snackbar(
          '网络测试',
          '网络连接失败，请检查网络设置',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      networkTestResult.value = '网络测试出错: $e';
      Get.snackbar(
        '网络测试',
        '网络测试出错: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isTestingNetwork.value = false;
    }
  }

  Future<void> testNetworkConnectionWithHttp() async {
    isTestingNetworkWithHttp.value = true;
    networkTestResultWithHttp.value = '';

    try {
      final result = await _aiService.testNetworkConnectionWithHttp();
      if (result) {
        networkTestResultWithHttp.value = '网络连接正常';
        Get.snackbar(
          '网络测试 (HTTP)',
          '网络连接正常',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        networkTestResultWithHttp.value = '网络连接失败';
        Get.snackbar(
          '网络测试 (HTTP)',
          '网络连接失败，请检查网络设置',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      networkTestResultWithHttp.value = '网络测试出错: $e';
      Get.snackbar(
        '网络测试 (HTTP)',
        '网络测试出错: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isTestingNetworkWithHttp.value = false;
    }
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
