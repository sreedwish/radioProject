enum Band {
  fm('FM', 'MHz', 87.5, 108.0, 0.1, 1),
  am('AM', 'kHz', 530, 1700, 10, 0);

  const Band(
    this.label,
    this.unit,
    this.min,
    this.max,
    this.step,
    this.decimals,
  );
  final String label;
  final String unit;
  final double min;
  final double max;
  final double step;
  final int decimals;

  int get divisions => ((max - min) / step).round();

  double snap(double f) =>
      (min + ((f.clamp(min, max) - min) / step).round() * step);

  String format(double f) => f.toStringAsFixed(decimals);
}

enum Language {
  malayalam('മലയാളം', 'malayalam', 'Kerala', r'kozhikode|calicut|malabar'),
  tamil('தமிழ்', 'tamil', 'Tamil Nadu', r'chennai|madras|coimbatore|madurai');

  const Language(this.label, this.apiName, this.state, this.localPattern);
  final String label;

  /// Value of Radio Browser's `language` filter.
  final String apiName;

  /// Value of Radio Browser's `state` filter.
  final String state;

  /// Station names matching this are listed first.
  final String localPattern;
}

class Station {
  const Station({
    required this.id,
    required this.name,
    required this.url,
    required this.band,
    required this.frequency,
  });
  final String id;
  final String name;
  final String url;
  final Band band;
  final double frequency;
}

// Phones have no accessible FM/AM tuner hardware, so stations are internet
// streams assigned to dial positions.

/// Used only when the Radio Browser lookup fails (e.g. offline).
const fallbackStations = <Station>[
  Station(
    id: 'groove',
    name: 'SomaFM Groove Salad',
    url: 'https://ice1.somafm.com/groovesalad-128-mp3',
    band: Band.fm,
    frequency: 88.1,
  ),
  Station(
    id: 'drone',
    name: 'SomaFM Drone Zone',
    url: 'https://ice1.somafm.com/dronezone-128-mp3',
    band: Band.fm,
    frequency: 90.3,
  ),
  Station(
    id: 'secret',
    name: 'SomaFM Secret Agent',
    url: 'https://ice1.somafm.com/secretagent-128-mp3',
    band: Band.fm,
    frequency: 93.7,
  ),
  Station(
    id: 'bbcws',
    name: 'BBC World Service',
    url: 'https://stream.live.vc.bbcmedia.co.uk/bbc_world_service',
    band: Band.am,
    frequency: 630,
  ),
];

Station? stationAt(List<Station> list, Band band, double frequency) {
  for (final s in list) {
    if (s.band == band && (s.frequency - frequency).abs() < band.step / 2)
      return s;
  }
  return null;
}
