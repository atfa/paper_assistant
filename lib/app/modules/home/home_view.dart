import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../widgets/resizable_column.dart';
import '../../routes/app_pages.dart';
import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paper Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Get.toNamed(Routes.SETTINGS),
          ),
        ],
      ),
      body: Row(
        children: [
          // 第一列：输入原文
          ResizableColumn(
            initialWidth: 300,
            minWidth: 200,
            maxWidth: 600,
            onResize: () {},
            child: Column(
              children: [
                _buildColumnHeader(
                  context,
                  const Text('输入原文'),
                  () => controller.copyToClipboard(controller.sourceText.value),
                ),
                Expanded(
                  child: TextField(
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    controller: controller.sourceController,
                    decoration: const InputDecoration(
                      hintText: '请输入原文...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                    ),
                    onChanged: (value) => controller.sourceText.value = value,
                  ),
                ),
              ],
            ),
          ),
          // 第二列：翻译
          ResizableColumn(
            initialWidth: 300,
            minWidth: 200,
            maxWidth: 600,
            onResize: () {},
            child: Column(
              children: [
                _buildColumnHeader(
                  context,
                  Obx(() => TextButton(
                        onPressed: controller.toggleTranslationDirection,
                        child: Text(
                          controller.isChineseToEnglish.value ? '中->英' : '英->中',
                        ),
                      )),
                  () => controller.copyToClipboard(controller.translatedText.value),
                ),
                Expanded(
                  child: TextField(
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    controller: controller.translatedController,
                    decoration: const InputDecoration(
                      hintText: '翻译结果...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                    ),
                    onChanged: (value) => controller.translatedText.value = value,
                  ),
                ),
              ],
            ),
          ),
          // 第三列：润色结果
          Expanded(
            child: Column(
              children: [
                _buildColumnHeader(
                  context,
                  const Text('润色结果'),
                  () => controller.copyToClipboard(controller.polishedText.value),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: SelectableText(
                      controller.polishedText.value.isEmpty ? '润色结果将在这里显示...' : controller.polishedText.value,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeader(BuildContext context, Widget title, VoidCallback onCopy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          title,
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: onCopy,
            tooltip: '复制',
          ),
        ],
      ),
    );
  }
}
