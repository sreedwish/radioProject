import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'preferences.dart';
import 'stations.dart';

const _fmCount = 120;
const _amCount = 80;

typedef _Found = ({
  String id,
  String name,
  String url,
  bool local,
  bool kerala,
});

final _namedFrequency = RegExp(
  r'(?:(\d{2,3}(?:\.\d)?)\s*(?:FM|MHz)|FM\s*(\d{2,3}\.\d))',
  caseSensitive: false,
);
Future<List<dynamic>> _search(
  http.Client client,
  Map<String, String> query,
) async {
  final uri = Uri.https('all.api.radio-browser.info', '/json/stations/search', {
    'countrycode': 'IN',
    'hidebroken': 'true',
    'order': 'clickcount',
    'reverse': 'true',
    'limit': '1000',
    ...query,
  });
  final response = await client.get(uri).timeout(const Duration(seconds: 15));
  return jsonDecode(utf8.decode(response.bodyBytes)) as List;
}

/// Stations in [language] from the Radio Browser directory, the language's
/// home cities first, then the rest of its state, then by popularity. A frequency in the
/// station's name (e.g. "98.6 FM") is used as its dial position when it fits;
/// the rest are spread over the free spots on the FM and AM dials.
Future<List<Station>> fetchStations(Language language) async {
  final localName = RegExp(language.localPattern, caseSensitive: false);
  final client = http.Client();
  try {
    final results = await Future.wait([
      _search(client, {'language': language.apiName}),
      _search(client, {'state': language.state}),
      // Plenty of stations are filed without a language, so also look by tag
      // and by name.
      _search(client, {'tag': language.apiName}),
      _search(client, {'name': language.apiName}),
    ]);

    final seenNames = <String>{};
    final seenUrls = <String>{};
    final found = <_Found>[];
    for (final e in results.expand((r) => r).cast<Map<String, dynamic>>()) {
      // A state or name match could be in another language entirely.
      final tagged = ((e['language'] as String?) ?? '').toLowerCase();
      if (tagged.isNotEmpty && !tagged.contains(language.apiName)) continue;
      final url = (e['url_resolved'] as String?) ?? '';
      final name = ((e['name'] as String?) ?? '').trim();
      // iOS blocks plain http streams, so keep https only.
      if (!url.startsWith('https://') || name.isEmpty) continue;
      if (!seenNames.add(name.toLowerCase()) || !seenUrls.add(url)) continue;
      found.add((
        id: e['stationuuid'] as String,
        name: name,
        url: url,
        local: localName.hasMatch(name),
        kerala:
            ((e['state'] as String?) ?? '').toLowerCase() ==
            language.state.toLowerCase(),
      ));
    }
    // Stable sort: local first, then Kerala, otherwise keep popularity order.
    int rank(_Found f) => f.local
        ? 0
        : f.kerala
        ? 1
        : 2;
    final ordered = [
      for (var r = 0; r < 3; r++) ...found.where((f) => rank(f) == r),
    ];

    final taken = <double>{};
    final stationsOut = <Station>[];

    // Pass 1: stations that name their own FM frequency.
    final unplaced = <_Found>[];
    for (final f in ordered) {
      final match = _namedFrequency.firstMatch(f.name);
      final hz = double.tryParse(match?.group(1) ?? match?.group(2) ?? '');
      final snapped = hz == null ? null : Band.fm.snap(hz);
      if (snapped != null &&
          hz! >= Band.fm.min &&
          hz <= Band.fm.max &&
          stationsOut.length < _fmCount &&
          taken.add(snapped)) {
        stationsOut.add(_station(f, Band.fm, snapped));
      } else {
        unplaced.add(f);
      }
    }

    // Pass 2: spread the rest evenly over the free FM spots, then AM, so the
    // whole dial has something on it however many stations there are.
    final fmRoom = _fmCount - stationsOut.length;
    final fmStations = unplaced.take(fmRoom).toList();
    final amStations = unplaced.skip(fmRoom).take(_amCount).toList();
    _spread(fmStations, Band.fm, taken, stationsOut);
    _spread(amStations, Band.am, taken, stationsOut);

    if (stationsOut.isEmpty) throw const FormatException('no stations');
    return stationsOut;
  } finally {
    client.close();
  }
}

/// Puts [stations] on evenly spaced free positions of [band].
void _spread(
  List<_Found> stations,
  Band band,
  Set<double> taken,
  List<Station> out,
) {
  if (stations.isEmpty) return;
  final free = <double>[
    for (var i = 0; i <= band.divisions; i++)
      if (!taken.contains(band.snap(band.min + i * band.step)))
        band.snap(band.min + i * band.step),
  ];
  final count = stations.length < free.length ? stations.length : free.length;
  for (var k = 0; k < count; k++) {
    final frequency = free[k * free.length ~/ count];
    taken.add(frequency);
    out.add(_station(stations[k], band, frequency));
  }
}

Station _station(_Found f, Band band, double frequency) => Station(
  id: f.id,
  name: f.name,
  url: f.url,
  band: band,
  frequency: frequency,
);

class LanguageController extends Notifier<Language> {
  @override
  Language build() {
    final saved = ref
        .read(sharedPreferencesProvider)
        .getString(languagePrefKey);
    return Language.values.where((l) => l.name == saved).firstOrNull ??
        Language.malayalam;
  }

  void set(Language language) {
    state = language;
    ref
        .read(sharedPreferencesProvider)
        .setString(languagePrefKey, language.name);
  }
}

final languageProvider = NotifierProvider<LanguageController, Language>(
  LanguageController.new,
);

final stationsProvider = FutureProvider<List<Station>>((ref) async {
  try {
    return await fetchStations(ref.watch(languageProvider));
  } catch (_) {
    return fallbackStations;
  }
});
