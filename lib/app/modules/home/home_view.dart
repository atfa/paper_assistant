import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/resizable_column.dart';
import '../../routes/app_pages.dart';
import 'home_controller.dart';
import 'package:flutter/services.dart';

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
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              Get.dialog(
                AlertDialog(
                  title: const Text('确认清空'),
                  content: const Text('确定要清空所有内容吗？此操作不可恢复。'),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        Get.back();
                        controller.clearAllContent();
                      },
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );
            },
            tooltip: '清空所有内容',
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
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 第一列：输入原文
              Obx(() => ResizableColumn(
                    initialWidth: controller.firstColumnWidth.value,
                    minWidth: columnWidth * 0.2,
                    maxWidth: columnWidth * 1.2,
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
                            child: _buildSourceSentencesList(context),
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
                    minWidth: columnWidth * 0.2,
                    maxWidth: columnWidth * 1.2,
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
                            child: _buildTranslatedSentencesList(context),
                          ),
                        ],
                      ),
                    ),
                  )),
              // 第三列：润色结果
              Expanded(
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
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Theme.of(context).dividerColor.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                                child: _buildPolishedSentencesList(context),
                              ),
                            ),
                            // 下半部分：中文翻译
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                child: _buildPolishedTranslationSentencesList(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 完整文本输入区域 - 首次加载时显示
  Widget _buildFullTextInput(BuildContext context) {
    return TextField(
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
    );
  }

  // 原文句子列表
  Widget _buildSourceSentencesList(BuildContext context) {
    return Obx(() => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.sourceSentenceControllers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final text = controller.sourceSentenceControllers[index].text;

            // 处理段落分隔符
            if (text == '###NEW_PARAGRAPH###') {
              return _buildParagraphDivider(context, index: index, isSource: true);
            }

            return _buildSentenceInput(
              context,
              controller.sourceSentenceControllers[index],
              index,
              (value) {
                controller.sourceSentenceControllers[index].text = value;
                controller.updateSourceTextFromSentences();
              },
            );
          },
        ));
  }

  // 翻译句子列表
  Widget _buildTranslatedSentencesList(BuildContext context) {
    return Obx(() => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.translatedSentenceControllers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final text = controller.translatedSentenceControllers[index].text;

            // 处理段落分隔符
            if (text == '###NEW_PARAGRAPH###') {
              return _buildParagraphDivider(context, index: index, isSource: false);
            }

            return _buildSentenceInput(
              context,
              controller.translatedSentenceControllers[index],
              index,
              (value) {
                controller.translatedSentenceControllers[index].text = value;
                controller.updateTranslatedTextFromSentences();
              },
            );
          },
        ));
  }

  // 润色句子列表
  Widget _buildPolishedSentencesList(BuildContext context) {
    return Obx(() => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.polishedSentences.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final text = controller.polishedSentences[index];

            // 处理段落分隔符
            if (text == '###NEW_PARAGRAPH###') {
              return _buildParagraphDivider(context);
            }

            return _buildSentenceDisplay(
              context,
              text,
              index,
            );
          },
        ));
  }

  // 润色翻译句子列表
  Widget _buildPolishedTranslationSentencesList(BuildContext context) {
    return Obx(() => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.polishedTranslationSentences.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final text = controller.polishedTranslationSentences[index];

            // 处理段落分隔符
            if (text == '###NEW_PARAGRAPH###') {
              return _buildParagraphDivider(context);
            }

            return _buildSentenceDisplay(
              context,
              text,
              index,
            );
          },
        ));
  }

  // 段落分隔符部件
  Widget _buildParagraphDivider(BuildContext context, {int index = -1, bool isSource = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        children: [
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Theme.of(context).dividerColor,
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      '新段落',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Theme.of(context).dividerColor,
                      thickness: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // 删除按钮
          if (index >= 0)
            Positioned(
              right: 0,
              top: 0,
              child: InkWell(
                onTap: () {
                  controller.removeParagraphBreak(index, isSource);
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 句子输入组件
  Widget _buildSentenceInput(
    BuildContext context,
    TextEditingController textController,
    int index,
    Function(String) onChanged,
  ) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 恢复句子编号标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Text(
                  '句子 ${index + 1}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: RawKeyboardListener(
                  focusNode: FocusNode(),
                  onKey: (RawKeyEvent event) {
                    // 监听回车键事件
                    if (event is RawKeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                        bool isSource = controller.sourceSentenceControllers.contains(textController);
                        controller.handleEnterKeyPressed(index, isSource);
                      }
                    }
                  },
                  child: TextField(
                    controller: textController,
                    maxLines: null,
                    minLines: 2,
                    decoration: InputDecoration(
                      hintText: '输入文本...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: onChanged,
                    // 设置文本输入动作
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 删除按钮
        Positioned(
          top: 0,
          right: 0,
          child: InkWell(
            onTap: () {
              bool isSource = controller.sourceSentenceControllers.contains(textController);
              controller.clearSentenceInput(index, isSource);
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withOpacity(0.8),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: Icon(
                Icons.close,
                size: 14,
                color: Theme.of(context).colorScheme.onError,
              ),
            ),
          ),
        ),
        // 添加新段落按钮
        Positioned(
          bottom: 0,
          right: 0,
          child: InkWell(
            onTap: () {
              bool isSource = controller.sourceSentenceControllers.contains(textController);
              controller.addParagraphBreak(index, isSource);
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(8),
                  topLeft: Radius.circular(8),
                ),
              ),
              child: Icon(
                Icons.format_line_spacing,
                size: 14,
                color: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 句子显示组件（用于只读内容）
  Widget _buildSentenceDisplay(
    BuildContext context,
    String text,
    int index,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Text(
              '句子 ${index + 1}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
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
                      onPressed: controller.isPolishing.value
                          ? null
                          : () {
                              controller.polishText();
                            },
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
