import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smilestreatsapp/core/constants/us_cities.dart';

class GeoService {
  static const List<String> usStates = [
    'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California',
    'Colorado', 'Connecticut', 'Delaware', 'Florida', 'Georgia',
    'Hawaii', 'Idaho', 'Illinois', 'Indiana', 'Iowa',
    'Kansas', 'Kentucky', 'Louisiana', 'Maine', 'Maryland',
    'Massachusetts', 'Michigan', 'Minnesota', 'Mississippi', 'Missouri',
    'Montana', 'Nebraska', 'Nevada', 'New Hampshire', 'New Jersey',
    'New Mexico', 'New York', 'North Carolina', 'North Dakota', 'Ohio',
    'Oklahoma', 'Oregon', 'Pennsylvania', 'Rhode Island', 'South Carolina',
    'South Dakota', 'Tennessee', 'Texas', 'Utah', 'Vermont',
    'Virginia', 'Washington', 'West Virginia', 'Wisconsin', 'Wyoming',
  ];

  Future<List<String>> getStates(String countryName) async => usStates;

  Future<List<String>> getAllCities(String countryName) async => [];

  Future<List<String>> getCities(String countryName, String stateName) async => [];

  /// Returns all cities for a given US state name instantly from local data.
  List<String> getCitiesForState(String stateName) {
    return usCitiesByState[stateName] ?? [];
  }

  /// Returns all ZIP codes for a city in a US state (2-letter state code).
  Future<List<String>> getZipsForCity(String city, String stateCode) async {
    try {
      final encodedCity = Uri.encodeComponent(city.toLowerCase().replaceAll(' ', '+'));
      final response = await http.get(
        Uri.parse('https://api.zippopotam.us/us/${stateCode.toLowerCase()}/$encodedCity'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final places = data['places'] as List?;
        if (places != null && places.isNotEmpty) {
          return places.map((p) => p['post code'] as String).toList();
        }
      }
    } catch (_) {}
    return [];
  }
}
