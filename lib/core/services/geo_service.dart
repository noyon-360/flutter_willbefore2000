import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Parsed GeoNames data: state code -> city -> sorted ZIP codes.
typedef _ZipIndex = Map<String, Map<String, List<String>>>;

/// The place a ZIP code belongs to, as listed in the GeoNames data.
class ZipPlace {
  final String city;
  final String stateName;
  final String stateCode;
  const ZipPlace(this.city, this.stateName, this.stateCode);
}

class GeoService {
  GeoService._();
  static final GeoService _instance = GeoService._();
  factory GeoService() => _instance;

  static const String _assetPath = 'assets/address/US.txt';

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

  _ZipIndex? _zipIndex;
  Map<String, String> _codeByStateName = {};
  Map<String, ZipPlace> _placeByZip = {};
  Future<void>? _loading;

  Future<List<String>> getStates(String countryName) async => usStates;

  Future<List<String>> getAllCities(String countryName) async => [];

  Future<List<String>> getCities(String countryName, String stateName) async => [];

  /// Loads and parses the GeoNames postal code file once. Safe to call repeatedly.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final parsed = await compute(_parse, raw);
      _zipIndex = parsed.index;
      _codeByStateName = parsed.codeByName;
      _placeByZip = parsed.placeByZip;
      LicenseRegistry.addLicense(() async* {
        yield const LicenseEntryWithLineBreaks(
          ['GeoNames postal codes'],
          'US postal code data from GeoNames (www.geonames.org), '
          'licensed under Creative Commons Attribution 4.0.',
        );
      });
    } catch (e) {
      _loading = null; // allow a retry on the next call
      debugPrint('GeoService: failed to load $_assetPath: $e');
    }
  }

  /// Returns all cities for a given US state name. Empty until [ensureLoaded] completes.
  List<String> getCitiesForState(String stateName) {
    final code = _codeByStateName[stateName];
    final cities = code == null ? null : _zipIndex?[code];
    return cities == null ? [] : (cities.keys.toList()..sort());
  }

  /// Returns all ZIP codes for a city in a US state (2-letter state code).
  Future<List<String>> getZipsForCity(String city, String stateCode) async {
    await ensureLoaded();
    return _zipIndex?[stateCode.toUpperCase()]?[city.trim()] ?? [];
  }

  /// Finds the city and state for a 5-digit ZIP code, or null if unknown.
  Future<ZipPlace?> lookupZip(String zip) async {
    await ensureLoaded();
    return placeForZip(zip);
  }

  /// Synchronous variant of [lookupZip]; null until [ensureLoaded] completes.
  ZipPlace? placeForZip(String zip) => _placeByZip[zip.trim()];
}

class _ParsedGeo {
  final _ZipIndex index;
  final Map<String, String> codeByName;
  final Map<String, ZipPlace> placeByZip;
  _ParsedGeo(this.index, this.codeByName, this.placeByZip);
}

/// Top-level so it can run in an isolate via [compute].
/// Columns (tab-separated): 0 country, 1 ZIP, 2 city, 3 state name, 4 state code.
_ParsedGeo _parse(String raw) {
  final index = <String, Map<String, Set<String>>>{};
  final codeByName = <String, String>{};
  final placeByZip = <String, ZipPlace>{};

  for (final line in raw.split('\n')) {
    final cols = line.split('\t');
    if (cols.length < 5) continue;
    final zip = cols[1].trim();
    final city = cols[2].trim();
    final stateName = cols[3].trim();
    final stateCode = cols[4].trim();
    if (zip.isEmpty || city.isEmpty || stateCode.isEmpty) continue;

    codeByName[stateName] = stateCode;
    placeByZip[zip] = ZipPlace(city, stateName, stateCode);
    index.putIfAbsent(stateCode, () => {}).putIfAbsent(city, () => {}).add(zip);
  }

  return _ParsedGeo(
    {
      for (final s in index.entries)
        s.key: {
          for (final c in s.value.entries) c.key: (c.value.toList()..sort()),
        },
    },
    codeByName,
    placeByZip,
  );
}
