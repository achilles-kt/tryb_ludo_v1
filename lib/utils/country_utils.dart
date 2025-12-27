import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class CountryUtils {
  // Map of ISO 3166-1 alpha-2 codes to Dial Codes
  static final Map<String, String> _dialCodes = {
    'US': '+1',
    'CA': '+1',
    'IN': '+91',
    'GB': '+44',
    'AU': '+61',
    'DE': '+49',
    'FR': '+33',
    'IT': '+39',
    'ES': '+34',
    'BR': '+55',
    'MX': '+52',
    'JP': '+81',
    'CN': '+86',
    'RU': '+7',
    'SA': '+966',
    'AE': '+971',
    'ZA': '+27',
    'NG': '+234',
    'KE': '+254',
    'AR': '+54',
    'CO': '+57',
    'TR': '+90',
    'KR': '+82',
    'ID': '+62',
    'PH': '+63',
    'VN': '+84',
    'TH': '+66',
    'MY': '+60',
    'SG': '+65',
    'PK': '+92',
    'BD': '+880',
    'EG': '+20',
    'MA': '+212',
    'CH': '+41',
    'SE': '+46',
    'NL': '+31',
    'BE': '+32',
    'AT': '+43',
    'PL': '+48',
    'UA': '+380',
    'GR': '+30',
    'PT': '+351',
    'IL': '+972',
    'IE': '+353',
    'NO': '+47',
    'DK': '+45',
    'FI': '+358',
    'NZ': '+64',
  };

  static Future<String?> fetchCountryDialCode() async {
    try {
      final response = await http
          .get(Uri.parse('http://ip-api.com/json'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final countryCode = data['countryCode'] as String?;
        if (countryCode != null && _dialCodes.containsKey(countryCode)) {
          return _dialCodes[countryCode];
        }
      }
    } catch (e) {
      debugPrint("CountryUtils: Failed to fetch country code: $e");
    }
    return null;
  }
}
