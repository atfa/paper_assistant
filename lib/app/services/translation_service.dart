import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TranslationService extends GetxService {
  static const String _googleKeyKey = 'google_translate_key';
  final _googleKey = ''.obs;
  final _dio = Dio();

  String get googleKey => _googleKey.value;

  @override
  void onInit() {
    super.onInit();
    _loadGoogleKey();
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
        },
      );

      return response.data['data']['translations'][0]['translatedText'];
    } on DioException catch (e) {
      throw Exception('Failed to translate text: ${e.response?.data ?? e.message}');
    }
  }
}
