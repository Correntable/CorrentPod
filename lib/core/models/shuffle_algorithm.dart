/// How the songs are mixed when the shuffle mode is "Songs".
enum ShuffleAlgorithm {
  /// Random order in which songs of the same artist and album are kept
  /// evenly apart, without favouring any song.
  balanced,

  /// Plain Fisher-Yates shuffle.
  random;

  ShuffleAlgorithm get next => values[(index + 1) % values.length];

  String get title => switch (this) {
    balanced => 'Balanced',
    random => 'Random',
  };

  /// Short text shown in the split screen preview.
  String get description => switch (this) {
    balanced => 'Random, but the same artist or album is kept spread out.',
    random => 'Completely random order.',
  };
}
