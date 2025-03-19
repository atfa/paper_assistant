import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

enum AIProvider {
  openrouter,
  groq,
  custom,
}

class AIService extends GetxService {
  static const String _providerKey = 'ai_provider';
  static const String _apiKeyKey = 'ai_api_key';
  static const String _baseUrlKey = 'ai_base_url';
  static const String _modelKey = 'ai_model';

  final _provider = AIProvider.openrouter.obs;
  final _apiKey = ''.obs;
  final _baseUrl = ''.obs;
  final _model = ''.obs;
  final _availableModels = <String>[].obs;
  final _dio = Dio();

  AIProvider get provider => _provider.value;
  String get apiKey => _apiKey.value;
  String get baseUrl => _baseUrl.value;
  String get model => _model.value;
  List<String> get availableModels => _availableModels;

  static const Map<AIProvider, String> defaultBaseUrls = {
    AIProvider.openrouter: 'https://openrouter.ai/api/v1',
    AIProvider.groq: 'https://api.groq.com/openai/v1',
  };

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
    _configureDio();
  }

  void _configureDio() {
    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      validateStatus: (status) => status != null && status < 500,
    );

    // 配置 HttpClient
    (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
      // 允许自签名证书
      client.badCertificateCallback = (cert, host, port) => true;

      // 在开发环境中配置代理
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        print('Development environment detected, configuring proxy...');
        client.findProxy = (uri) => 'PROXY 127.0.0.1:7890';
      } else {
        // 在生产环境中使用系统代理
        final proxy = _getSystemProxy();
        if (proxy != null) {
          client.findProxy = (uri) => 'PROXY $proxy';
        }
      }

      return client;
    };

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('Request URL: ${options.uri}');
        print('Request Headers: ${options.headers}');
        print('Request Method: ${options.method}');
        print('Request Data: ${options.data}');

        if (_apiKey.value.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer ${_apiKey.value}';
        }
        options.headers['Content-Type'] = 'application/json';
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        print('DioError Type: ${e.type}');
        print('DioError Message: ${e.message}');
        print('DioError Response: ${e.response?.data}');
        print('DioError Request: ${e.requestOptions.uri}');
        print('DioError Request Headers: ${e.requestOptions.headers}');
        print('DioError Request Method: ${e.requestOptions.method}');
        print('DioError Request Data: ${e.requestOptions.data}');
        return handler.next(e);
      },
    ));
  }

  String? _getSystemProxy() {
    // 检查环境变量中的代理设置
    final httpProxy = Platform.environment['http_proxy'] ?? Platform.environment['HTTP_PROXY'];
    final httpsProxy = Platform.environment['https_proxy'] ?? Platform.environment['HTTPS_PROXY'];

    // 优先使用 HTTPS 代理
    if (httpsProxy != null) {
      return httpsProxy.replaceAll(RegExp(r'^https?://'), '');
    }

    // 其次使用 HTTP 代理
    if (httpProxy != null) {
      return httpProxy.replaceAll(RegExp(r'^https?://'), '');
    }

    return null;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _provider.value = AIProvider.values[prefs.getInt(_providerKey) ?? 0];
    _apiKey.value = prefs.getString(_apiKeyKey) ?? '';
    _baseUrl.value = prefs.getString(_baseUrlKey) ?? defaultBaseUrls[_provider.value] ?? '';
    _model.value = prefs.getString(_modelKey) ?? '';
    if (_apiKey.value.isNotEmpty) {
      await refreshAvailableModels();
    }
  }

  Future<void> setProvider(AIProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_providerKey, provider.index);
    _provider.value = provider;
    _baseUrl.value = defaultBaseUrls[provider] ?? '';
    if (provider != AIProvider.custom) {
      await prefs.setString(_baseUrlKey, _baseUrl.value);
    }
    if (_apiKey.value.isNotEmpty) {
      await refreshAvailableModels();
    }
  }

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, key);
    _apiKey.value = key;
    _configureDio();
    if (key.isNotEmpty) {
      await refreshAvailableModels();
    }
  }

  Future<void> setBaseUrl(String url) async {
    if (_provider.value != AIProvider.custom) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
    _baseUrl.value = url;
    if (_apiKey.value.isNotEmpty) {
      await refreshAvailableModels();
    }
  }

  Future<void> setModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, model);
    _model.value = model;
  }

  Future<void> refreshAvailableModels() async {
    try {
      print('Fetching available models from ${_baseUrl.value}...');
      print('Current API Key: ${_apiKey.value.isNotEmpty ? 'Set' : 'Not Set'}');
      print('Current Base URL: ${_baseUrl.value}');

      // 使用 Options 配置请求
      final options = Options(
        headers: {
          'Authorization': 'Bearer ${_apiKey.value}',
          'Content-Type': 'application/json',
        },
        validateStatus: (status) => status != null && status < 500,
      );

      final response = await _dio.get(
        '${_baseUrl.value}/models',
        options: options,
      );

      print('Response received: ${response.data}');
      final models = (response.data['data'] as List).map((m) => m['id'] as String).toList();
      _availableModels.value = models;
      print('Available models updated: ${models.join(', ')}');
    } on DioException catch (e) {
      print('Error fetching models: ${e.message}');
      print('Error type: ${e.type}');
      print('Error response: ${e.response?.data}');
      print('Request URL: ${e.requestOptions.uri}');
      print('Request Headers: ${e.requestOptions.headers}');

      String errorMessage = '请检查网络连接和API配置是否正确';
      if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = '连接超时，请检查网络设置';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = '连接失败，请检查网络设置和VPN状态';
      }

      _availableModels.value = [];
      Get.snackbar(
        '获取模型列表失败',
        errorMessage,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      print('Unexpected error while fetching models: $e');
      _availableModels.value = [];
      Get.snackbar(
        '获取模型列表失败',
        '发生未知错误，请稍后重试',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<String> generateText(String prompt) async {
    if (_apiKey.value.isEmpty) {
      throw Exception('API key not set');
    }
    if (_model.value.isEmpty) {
      throw Exception('AI model not selected');
    }

    try {
      final response = await _dio.post(
        '${_baseUrl.value}/chat/completions',
        data: {
          'model': _model.value,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        },
      );

      return response.data['choices'][0]['message']['content'];
    } on DioException catch (e) {
      throw Exception('Failed to generate text: ${e.response?.data ?? e.message}');
    }
  }

  Future<bool> testNetworkConnection() async {
    try {
      print('Testing network connection...');
      final response = await _dio.get(
        'https://www.baidu.com/img/PCtm_d9c8750bed0b3c7d089fa7d55720d6cf.png',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      print('Network test response status: ${response.statusCode}');
      return response.statusCode == 200;
    } on DioException catch (e) {
      print('Network test error: ${e.message}');
      print('Network test error type: ${e.type}');
      return false;
    } catch (e) {
      print('Network test unexpected error: $e');
      return false;
    }
  }

  Future<bool> testNetworkConnectionWithHttp() async {
    try {
      print('Testing network connection with http package...');

      // 在开发环境中配置代理
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        print('Development environment detected, configuring proxy...');
        final client = HttpClient();
        client.findProxy = (uri) => 'PROXY 127.0.0.1:7890';

        final request = await client.getUrl(
          Uri.parse('https://www.baidu.com/img/PCtm_d9c8750bed0b3c7d089fa7d55720d6cf.png'),
        );
        final response = await request.close();
        final statusCode = response.statusCode;

        print('HTTP Network test response status: $statusCode');
        return statusCode == 200;
      } else {
        // 在生产环境中使用系统代理
        final proxy = _getSystemProxy();
        if (proxy != null) {
          print('Using system proxy: $proxy');
          final client = HttpClient();
          client.findProxy = (uri) => 'PROXY $proxy';

          final request = await client.getUrl(
            Uri.parse('https://www.baidu.com/img/PCtm_d9c8750bed0b3c7d089fa7d55720d6cf.png'),
          );
          final response = await request.close();
          final statusCode = response.statusCode;

          print('HTTP Network test response status: $statusCode');
          return statusCode == 200;
        } else {
          // 如果没有代理，使用普通的 http 请求
          final response = await http.get(
            Uri.parse('https://www.baidu.com/img/PCtm_d9c8750bed0b3c7d089fa7d55720d6cf.png'),
          );

          print('HTTP Network test response status: ${response.statusCode}');
          return response.statusCode == 200;
        }
      }
    } catch (e) {
      print('HTTP Network test error: $e');
      return false;
    }
  }
}
