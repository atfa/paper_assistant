import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/ai_service.dart';
import 'settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return _SettingsViewContent();
  }
}

class _SettingsViewContent extends StatefulWidget {
  @override
  _SettingsViewContentState createState() => _SettingsViewContentState();
}

class _SettingsViewContentState extends State<_SettingsViewContent> {
  final SettingsController controller = Get.find<SettingsController>();

  // Store TextEditingControllers for each field
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize controllers with initial values
    _initControllers();
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initControllers() {
    // Initialize controllers for API keys and other fields
    _getOrCreateController('Google API Key', controller.googleKey);
    _getOrCreateController('AI API Key', controller.aiKey);
    _getOrCreateController('Base URL', controller.aiBaseUrl);
    _getOrCreateController('Model Filter', '');
  }

  TextEditingController _getOrCreateController(String key, String initialValue) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = TextEditingController(text: initialValue);
    } else if (_controllers[key]!.text != initialValue) {
      // If value changed from outside, update controller but preserve selection
      final selection = _controllers[key]!.selection;
      _controllers[key]!.text = initialValue;

      // Try to restore cursor position if possible
      if (selection.baseOffset >= 0 && selection.baseOffset <= initialValue.length) {
        _controllers[key]!.selection = selection;
      }
    }
    return _controllers[key]!;
  }

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
                          controllerKey: 'Google API Key',
                          initialValue: controller.googleKey,
                          onChanged: controller.setGoogleKey,
                          suffix: controller.isTestingGoogleKey.value
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.check_circle_outline),
                                  tooltip: '验证 API Key',
                                  onPressed: () => _showValidationDialog(context),
                                ),
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
                            controllerKey: 'Base URL',
                            initialValue: controller.aiBaseUrl,
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
                          controllerKey: 'AI API Key',
                          initialValue: controller.aiKey,
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
                  controllerKey: 'Model Filter',
                  initialValue: controller.modelFilter.value,
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
            // Network testing section
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
                    // Dio test
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
                    // HTTP test
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
    required String controllerKey,
    required String initialValue,
    required ValueChanged<String> onChanged,
    Widget? suffix,
  }) {
    // Get or create controller with initial value
    final controller = _getOrCreateController(controllerKey, initialValue);

    return TextField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixIcon: suffix,
      ),
      controller: controller,
      onChanged: (text) {
        // Save the current selection before calling onChanged
        final currentSelection = controller.selection;

        // Call the original callback
        onChanged(text);

        // Restore cursor position after state has been updated
        Future.microtask(() {
          if (controller.text == text && currentSelection.start <= text.length) {
            controller.selection = currentSelection;
          }
        });
      },
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

  // Add this method to show the validation dialog
  Future<void> _showValidationDialog(BuildContext context) async {
    // Show dialog with loading state first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('验证 Google API Key'),
        content: const SizedBox(
          height: 100,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [CircularProgressIndicator(), SizedBox(height: 16), Text('正在验证...')],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    // Perform validation and get steps
    List<String> steps = await controller.validateGoogleKeyWithSteps();

    // Close the loading dialog
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    // Show result dialog with steps
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('验证结果'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var step in steps)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(step),
                  ),
                const SizedBox(height: 8),
                if (controller.googleKeyStatus.value != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: controller.googleKeyStatus.value!.isValid
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: controller.googleKeyStatus.value!.isValid ? Colors.green : Colors.red,
                      ),
                    ),
                    child: Text(
                      controller.googleKeyStatus.value!.message,
                      style: TextStyle(
                        color: controller.googleKeyStatus.value!.isValid ? Colors.green.shade800 : Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }
  }
}
