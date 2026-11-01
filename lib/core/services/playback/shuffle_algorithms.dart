import 'dart:math';

import 'package:classipod/core/models/shuffle_algorithm.dart';

/// Orders [pool] (song indices) with the chosen [algorithm].
///
/// [recent] are the songs that are already placed right before the pool (the
/// current song and the songs queued by the user, in playing order). They are
/// not part of the result, but the first songs of the result avoid clashing
/// with them.
///
/// [artistOf] returns a normalized artist key (or null when unknown: unknown
/// artists never clash). [albumOf] returns an album id; songs without album
/// must have a unique id.
List<int> orderSongs({
  required ShuffleAlgorithm algorithm,
  required List<int> pool,
  required List<int> recent,
  required String? Function(int song) artistOf,
  required int Function(int song) albumOf,
  required Random random,
  double jitter = 0.3,
}) {
  switch (algorithm) {
    case ShuffleAlgorithm.random:
      return pool.toList()..shuffle(random);
    case ShuffleAlgorithm.lessRandom:
      return separateNeighbours(
        pool.toList()..shuffle(random),
        recent: recent,
        artistOf: artistOf,
        albumOf: albumOf,
        lookahead: 25,
      );
    case ShuffleAlgorithm.smart:
      return separateNeighbours(
        spreadOrder(
          pool,
          artistOf: artistOf,
          albumOf: albumOf,
          random: random,
          jitter: jitter,
        ),
        recent: recent,
        artistOf: artistOf,
        albumOf: albumOf,
        lookahead: 10,
      );
  }
}

/// Repair pass. Walks [songs] once and, when the next song has the same artist
/// as one of the last [artistCooldown] placed songs (or the same album as one
/// of the last [albumCooldown]), takes the first non clashing song among the
/// next [lookahead] ones instead. The skipped song stays in the window and is
/// placed as soon as it no longer clashes.
///
/// If every song of the window clashes the first one is used, so the result is
/// always a permutation of [songs]. Cost: O(n * lookahead).
List<int> separateNeighbours(
  List<int> songs, {
  required List<int> recent,
  required String? Function(int song) artistOf,
  required int Function(int song) albumOf,
  int artistCooldown = 3,
  int albumCooldown = 8,
  int lookahead = 25,
}) {
  final history = <int>[...recent];
  final depth = max(artistCooldown, albumCooldown);

  bool clashes(int song) {
    final artist = artistOf(song);
    final album = albumOf(song);
    final stop = max(0, history.length - depth);
    for (var i = history.length - 1; i >= stop; i--) {
      final distance = history.length - i;
      final other = history[i];
      if (distance <= artistCooldown &&
          artist != null &&
          artistOf(other) == artist) {
        return true;
      }
      if (albumOf(other) == album) return true;
    }
    return false;
  }

  final result = <int>[];
  final window = <int>[];
  var cursor = 0;
  while (result.length < songs.length) {
    while (window.length < lookahead && cursor < songs.length) {
      window.add(songs[cursor++]);
    }
    var pick = window.indexWhere((song) => !clashes(song));
    if (pick < 0) pick = 0;
    final song = window.removeAt(pick);
    result.add(song);
    history.add(song);
  }
  return result;
}

/// Spread shuffle: every artist gets its songs placed at evenly spaced ideal
/// positions along the queue, with a random starting offset per artist and a
/// random deviation of at most [jitter] (relative to the spacing) per song.
/// Inside an artist the albums are spread the same way.
///
/// jitter 0 gives an almost perfectly even spacing, bigger values get closer
/// to a plain random shuffle. Cost: O(n log n).
List<int> spreadOrder(
  List<int> pool, {
  required String? Function(int song) artistOf,
  required int Function(int song) albumOf,
  required Random random,
  required double jitter,
}) {
  final byArtist = <Object, List<int>>{};
  for (final song in pool) {
    // Unknown artists are never grouped together.
    final Object key = artistOf(song) ?? song;
    byArtist.putIfAbsent(key, () => []).add(song);
  }
  final artistTracks = <List<int>>[
    for (final songs in byArtist.values)
      _interleaveAlbums(songs, albumOf, random, jitter),
  ];
  return _spreadGroups(artistTracks, random, jitter);
}

List<int> _interleaveAlbums(
  List<int> songs,
  int Function(int song) albumOf,
  Random random,
  double jitter,
) {
  final byAlbum = <int, List<int>>{};
  for (final song in songs) {
    byAlbum.putIfAbsent(albumOf(song), () => []).add(song);
  }
  if (byAlbum.length < 2) return songs..shuffle(random);
  final albums = <List<int>>[];
  for (final tracks in byAlbum.values) {
    albums.add(tracks..shuffle(random));
  }
  return _spreadGroups(albums, random, jitter);
}

/// Merges [groups] so that the songs of each group end up evenly spaced.
List<int> _spreadGroups(List<List<int>> groups, Random random, double jitter) {
  final keyed = <(int, double)>[];
  for (final group in groups) {
    final size = group.length;
    final offset = random.nextDouble();
    for (var i = 0; i < size; i++) {
      final noise = (random.nextDouble() - 0.5) * 2 * jitter / size;
      keyed.add((group[i], (i + offset) / size + noise));
    }
  }
  keyed.sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final entry in keyed) entry.$1];
}
