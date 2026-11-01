/// How the songs are mixed when the shuffle mode is "Songs".
enum ShuffleAlgorithm {
  /// Plain Fisher-Yates shuffle (the original behaviour).
  random,

  /// Random shuffle, then neighbouring songs of the same artist / album are
  /// swapped with songs a little further ahead.
  lessRandom,

  /// Songs of each artist are spread evenly along the whole queue
  /// (see [SmartVariation] for how strict the spacing is).
  smart;

  ShuffleAlgorithm get next => values[(index + 1) % values.length];

  String get title => switch (this) {
    random => 'Random',
    lessRandom => 'Less Random',
    smart => 'Smart',
  };

  /// Short text shown in the split screen preview.
  String get description => switch (this) {
    random => 'Completely random order.',
    lessRandom => 'Random, but the same artist or album is not played in a row.',
    smart => 'Songs of each artist are spread evenly across the queue.',
  };
}

/// How much the smart shuffle is allowed to move a song away from its ideal,
/// perfectly even position. Low = very even spacing, high = closer to random.
enum SmartVariation {
  low(0.1),
  medium(0.3),
  high(0.6);

  const SmartVariation(this.jitter);

  final double jitter;

  SmartVariation get next => values[(index + 1) % values.length];

  String get title => switch (this) {
    low => 'Low',
    medium => 'Medium',
    high => 'High',
  };

  /// Short text shown in the split screen preview.
  String get description => switch (this) {
    low => 'Very even spacing between songs of the same artist.',
    medium => 'Even spacing with some variety.',
    high => 'Looser spacing, closer to random.',
  };
}
