import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class TranslationService extends GetxService {
  static const String _googleKeyKey = 'google_translate_key';
  final _googleKey = ''.obs;
  final _dio = Dio();

  // 代理服务器设置
  String? _proxyUrl;

  String get googleKey => _googleKey.value;

  @override
  void onInit() {
    super.onInit();
    _loadGoogleKey();
    _configureDio();
  }

  void _configureDio() {
    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status != null && status < 500,
    );

    // 配置 HttpClient
    (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
      // 允许自签名证书
      client.badCertificateCallback = (cert, host, port) => true;

      // 配置代理服务器（优先使用用户配置）
      if (_proxyUrl != null && _proxyUrl!.isNotEmpty) {
        // 提取出干净的代理地址（移除协议前缀）
        final cleanProxyUrl = _proxyUrl!.replaceAll(RegExp(r'^https?://'), '');
        print('Translation Service: Using clean proxy: $cleanProxyUrl');
        client.findProxy = (uri) => 'PROXY $cleanProxyUrl';
      } else if (const bool.fromEnvironment('dart.vm.product') == false) {
        // 开发环境中的代理（仅当未配置用户代理时）
        print('Translation Service: Development environment detected, configuring default dev proxy...');
        client.findProxy = (uri) => 'PROXY 127.0.0.1:7890';
      } else {
        // 在生产环境中使用系统代理（仅当未配置用户代理时）
        final proxy = _getSystemProxy();
        if (proxy != null) {
          print('Translation Service: Using system proxy: $proxy');
          client.findProxy = (uri) => 'PROXY $proxy';
        } else {
          // 没有配置代理
          print('Translation Service: No proxy configured');
          client.findProxy = (uri) => 'DIRECT';
        }
      }

      return client;
    };

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        print('Translation Service: Request URL: ${options.uri}');
        print('Translation Service: Using proxy: ${_proxyUrl ?? "None"}');
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        print('Translation Service: Error: ${e.message}');
        return handler.next(e);
      },
    ));
  }

  // 设置代理服务器
  void setProxy(String? proxyAddress) {
    _proxyUrl = proxyAddress;
    print('Translation Service: Proxy set to: ${proxyAddress ?? "None (disabled)"}');
    // 重新配置Dio
    _configureDio();
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

  Future<void> _loadGoogleKey() async {
    final prefs = await SharedPreferences.getInstance();
    _googleKey.value = prefs.getString(_googleKeyKey) ?? '';
  }

  Future<void> setGoogleKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_googleKeyKey, key);
    _googleKey.value = key;
  }

  Future<String> translate({
    required String text,
    required String source,
    required String target,
  }) async {
    if (_googleKey.value.isEmpty) {
      throw Exception('Google Translate API key not set');
    }

    try {
      final response = await _dio.post(
        'https://translation.googleapis.com/language/translate/v2',
        queryParameters: {'key': _googleKey.value},
        data: {
          'q': text,
          'source': source,
          'target': target,
          'format': 'text',
        },
      );

      return response.data['data']['translations'][0]['translatedText'];
    } on DioException catch (e) {
      throw Exception('Failed to translate text: ${e.response?.data ?? e.message}');
    }
  }
}
