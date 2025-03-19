import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/resizable_column.dart';
import '../../routes/app_pages.dart';
import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    // 计算屏幕宽度和列宽
    final screenWidth = MediaQuery.of(context).size.width;
    final columnWidth = screenWidth / 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paper Assistant'),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.ruler, size: 20),
            onPressed: controller.resetLayout,
            tooltip: '重置布局',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Get.toNamed(Routes.SETTINGS),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.background,
        ),
        child: Row(
          children: [
            // 第一列：输入原文
            Obx(() => ResizableColumn(
                  initialWidth: controller.firstColumnWidth.value,
                  minWidth: columnWidth * 0.5,
                  maxWidth: columnWidth * 1.5,
                  onResize: (width) => controller.updateFirstColumnWidth(width),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
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
                            style: Theme.of(context).textTheme.bodyLarge,
                            decoration: const InputDecoration(
                              hintText: '请输入原文...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                            onChanged: (value) => controller.sourceText.value = value,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Theme.of(context).dividerColor.withOpacity(0.5),
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Obx(() => Text(
                                    '${controller.sourceText.value.length}/5000',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: controller.sourceText.value.length > 5000
                                              ? Colors.red
                                              : Theme.of(context).colorScheme.onSurface,
                                        ),
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
            // 第二列：翻译
            Obx(() => ResizableColumn(
                  initialWidth: controller.secondColumnWidth.value,
                  minWidth: columnWidth * 0.5,
                  maxWidth: columnWidth * 1.5,
                  onResize: (width) => controller.updateSecondColumnWidth(width),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildColumnHeader(
                          context,
                          Obx(() => TextButton.icon(
                                onPressed: controller.toggleTranslationDirection,
                                icon: Icon(
                                  controller.isChineseToEnglish.value ? Icons.translate : Icons.language,
                                  size: 18,
                                ),
                                label: Text(
                                  controller.isChineseToEnglish.value ? '中->英' : '英->中',
                                ),
                              )),
                          () => controller.copyToClipboard(controller.translatedText.value),
                          isTranslationColumn: true,
                        ),
                        Expanded(
                          child: TextField(
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            controller: controller.translatedController,
                            style: Theme.of(context).textTheme.bodyLarge,
                            decoration: const InputDecoration(
                              hintText: '翻译结果...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                            onChanged: (value) => controller.translatedText.value = value,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
            // 第三列：润色结果
            Obx(() => Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildColumnHeader(
                          context,
                          const Text('润色结果'),
                          () => controller.copyToClipboard(controller.polishedText.value),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              // 上半部分：英文润色结果
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Theme.of(context).dividerColor.withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                  child: SelectableText(
                                    controller.polishedText.value.isEmpty
                                        ? '润色结果将在这里显示...'
                                        : controller.polishedText.value,
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ),
                              ),
                              // 下半部分：中文翻译
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  child: SelectableText(
                                    controller.polishedTranslation.value.isEmpty
                                        ? '中文翻译将在这里显示...'
                                        : controller.polishedTranslation.value,
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnHeader(BuildContext context, Widget title, VoidCallback onCopy,
      {bool isTranslationColumn = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          title,
          Row(
            children: [
              // 润色按钮 - 只在第二列显示
              if (isTranslationColumn)
                Obx(() => IconButton(
                      icon: controller.isPolishing.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_fix_high),
                      onPressed: controller.isPolishing.value ? null : controller.polishText,
                      tooltip: '润色',
                    )),
              // 复制按钮
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: onCopy,
                tooltip: '复制',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
