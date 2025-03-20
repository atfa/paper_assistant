import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/ai_service.dart';
import 'settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Google Translate API 设置
            _buildSection(
              context,
              title: 'Google Translate API',
              children: [
                Obx(() => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          label: 'API Key',
                          hint: '请输入 Google Translate API Key',
                          value: controller.googleKey,
                          onChanged: controller.setGoogleKey,
                          suffix: controller.isTestingGoogleKey.value
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                        ),
                        if (controller.googleKeyStatus.value != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              controller.googleKeyStatus.value!.message,
                              style: TextStyle(
                                color: controller.googleKeyStatus.value!.isValid ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                      ],
                    )),
              ],
            ),
            const SizedBox(height: 32),
            // AI 服务设置
            _buildSection(
              context,
              title: 'AI 服务设置',
              children: [
                Obx(() => _buildDropdownButton(
                      label: 'AI 服务提供商',
                      value: controller.aiProvider,
                      items: AIProvider.values.map((provider) {
                        return DropdownMenuItem(
                          value: provider,
                          child: Text(provider.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) controller.setAIProvider(value);
                      },
                    )),
                const SizedBox(height: 16),
                // 显示当前选择的AI模型
                Obx(() => controller.aiModel.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '当前模型: ',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Expanded(
                              child: Text(
                                controller.aiModel,
                                style: Theme.of(context).textTheme.titleSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox()),
                const SizedBox(height: 16),
                Obx(() => controller.aiProvider == AIProvider.custom
                    ? Column(
                        children: [
                          _buildTextField(
                            label: 'Base URL',
                            hint: '请输入自定义 API 地址',
                            value: controller.aiBaseUrl,
                            onChanged: controller.setAIBaseUrl,
                          ),
                          const SizedBox(height: 16),
                        ],
                      )
                    : const SizedBox()),
                Obx(() => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          label: 'API Key',
                          hint: '请输入 API Key',
                          value: controller.aiKey,
                          onChanged: controller.setAIKey,
                          suffix: controller.isTestingAIKey.value
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                        ),
                        if (controller.aiKeyStatus.value != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              controller.aiKeyStatus.value!.message,
                              style: TextStyle(
                                color: controller.aiKeyStatus.value!.isValid ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                      ],
                    )),
                const SizedBox(height: 24),
                _buildTextField(
                  label: '模型搜索',
                  hint: '输入关键字过滤模型',
                  onChanged: controller.setModelFilter,
                ),
                const SizedBox(height: 16),
                Obx(() => controller.filteredModels.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text('无可用模型'),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: controller.filteredModels.length,
                            itemBuilder: (context, index) {
                              final model = controller.filteredModels[index];
                              return Obx(() => RadioListTile<String>(
                                    title: Text(model),
                                    value: model,
                                    groupValue: controller.aiModel,
                                    onChanged: (value) {
                                      if (value != null) {
                                        controller.setAIModel(value);
                                      }
                                    },
                                  ));
                            },
                          ),
                        ),
                      )),
              ],
            ),
            const SizedBox(height: 32),
            // 网络测试部分
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '网络测试',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Dio 测试
                    Row(
                      children: [
                        Expanded(
                          child: Obx(() => Text(
                                controller.networkTestResult.value.isEmpty
                                    ? '点击按钮测试网络连接 (Dio)'
                                    : controller.networkTestResult.value,
                                style: TextStyle(
                                  color: controller.networkTestResult.value.contains('正常')
                                      ? Colors.green
                                      : controller.networkTestResult.value.contains('失败')
                                          ? Colors.red
                                          : Colors.orange,
                                ),
                              )),
                        ),
                        const SizedBox(width: 16),
                        Obx(() => ElevatedButton(
                              onPressed: controller.isTestingNetwork.value ? null : controller.testNetworkConnection,
                              child: controller.isTestingNetwork.value
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('测试网络 (Dio)'),
                            )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // HTTP 测试
                    Row(
                      children: [
                        Expanded(
                          child: Obx(() => Text(
                                controller.networkTestResultWithHttp.value.isEmpty
                                    ? '点击按钮测试网络连接 (HTTP)'
                                    : controller.networkTestResultWithHttp.value,
                                style: TextStyle(
                                  color: controller.networkTestResultWithHttp.value.contains('正常')
                                      ? Colors.green
                                      : controller.networkTestResultWithHttp.value.contains('失败')
                                          ? Colors.red
                                          : Colors.orange,
                                ),
                              )),
                        ),
                        const SizedBox(width: 16),
                        Obx(() => ElevatedButton(
                              onPressed: controller.isTestingNetworkWithHttp.value
                                  ? null
                                  : controller.testNetworkConnectionWithHttp,
                              child: controller.isTestingNetworkWithHttp.value
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('测试网络 (HTTP)'),
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    String? value,
    required ValueChanged<String> onChanged,
    Widget? suffix,
  }) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixIcon: suffix,
      ),
      controller: value != null ? TextEditingController(text: value) : null,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownButton<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}
