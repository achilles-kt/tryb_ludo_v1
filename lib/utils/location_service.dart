import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  static const String _apiUrl = 'http://ip-api.com/json';

  /// Fetches the city and country based on the device's IP address.
  /// Returns a Map with 'city' and 'country' keys, or null if failed.
  static Future<Map<String, String>?> fetchCityCountry() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return {
            'city': data['city'] ?? '',
            'country': data['country'] ?? '',
          };
        }
      }
    } catch (e) {
      print('Error fetching location: $e');
    }
    return null;
  }
}
