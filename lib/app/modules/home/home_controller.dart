import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomeController extends GetxController {
  final isChineseToEnglish = true.obs;
  final sourceText = ''.obs;
  final translatedText = ''.obs;
  final polishedText = ''.obs;

  late final TextEditingController sourceController;
  late final TextEditingController translatedController;

  @override
  void onInit() {
    super.onInit();
    sourceController = TextEditingController();
    translatedController = TextEditingController();
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
      Get.snackbar(
        '已复制',
        '文本已复制到剪贴板',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
