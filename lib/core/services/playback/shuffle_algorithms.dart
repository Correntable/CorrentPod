import 'dart:math';

import 'package:classipod/core/models/shuffle_algorithm.dart';

/// How far a song may drift from its ideal, evenly spaced slot, measured in
/// slots (the distance between two songs of the same artist in a perfectly
/// even queue).
///
/// 0 gives a rigid pattern, about 2.4 makes the spacing as irregular as a
/// plain shuffle. 1.5 keeps the order clearly random while clusters, and long
/// droughts, of the same artist stay rare.
const double defaultLooseness = 1.5;

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
}) {
  switch (algorithm) {
    case ShuffleAlgorithm.random:
      return pool.toList()..shuffle(random);
    case ShuffleAlgorithm.balanced:
      return balancedOrder(
        pool: pool,
        recent: recent,
        artistOf: artistOf,
        albumOf: albumOf,
        random: random,
      );
  }
}

/// Balanced shuffle: a random order in which the songs of an artist, and the
/// songs of an album, are kept evenly apart.
///
/// 1. Every artist places its songs on a circle at evenly spaced slots, from
///    a random starting phase and with each song jittered by up to
///    [looseness] slots. The songs of the artist are first interleaved by
///    album the same way, so albums are spread inside each artist, and the
///    songs of a compilation (one song per artist) are spread by album.
/// 2. Sorting all the songs by their position on the circle gives the order.
///    A song is equally likely to land anywhere, whatever the size of its
///    artist: unlike weighted "pick a group" schedulers, nothing is pushed to
///    the front or to the back, so a new shuffle does not favour the same
///    songs. Dense artists get less jitter, so they stay feasible.
/// 3. A last pass walks the order and, when a song would play too soon after
///    one of its artist or album, takes the best of the next [window] songs
///    instead. The cooldowns scale with the size of the group, so they never
///    ask for something impossible (an artist with half of the library).
///
/// Cost: O(n log n + n * window).
List<int> balancedOrder({
  required List<int> pool,
  required List<int> recent,
  required String? Function(int song) artistOf,
  required int Function(int song) albumOf,
  required Random random,
  double looseness = defaultLooseness,
  int window = 12,
}) {
  final count = pool.length;
  if (count < 2) return pool.toList();

  final artists = [for (final song in pool) artistOf(song)];
  final albums = [for (final song in pool) albumOf(song)];
  final byArtist = <String, List<int>>{};
  final albumSizes = <int, int>{};
  for (var i = 0; i < count; i++) {
    final artist = artists[i];
    // Unknown artists are never grouped together.
    if (artist != null) (byArtist[artist] ??= []).add(i);
    albumSizes[albums[i]] = (albumSizes[albums[i]] ?? 0) + 1;
  }

  // Position of every song on the circle [0, 1).
  final keys = List<double>.generate(count, (_) => random.nextDouble());
  // Songs whose artist has no other song are free to follow their album, which
  // spreads compilations made of many artists.
  final free = <int, List<int>>{};
  for (var i = 0; i < count; i++) {
    if (artists[i] == null) (free[albums[i]] ??= []).add(i);
  }
  for (final songs in byArtist.values) {
    if (songs.length == 1) {
      (free[albums[songs.first]] ??= []).add(songs.first);
      continue;
    }
    final sequence = _interleaveAlbums(songs, albums, looseness, random);
    final slots = _spreadKeys(
      sequence.length,
      _looseFor(looseness, sequence.length, count),
      random,
    );
    for (var j = 0; j < sequence.length; j++) {
      keys[sequence[j]] = slots[j];
    }
  }
  for (final songs in free.values) {
    if (songs.length < 2) continue;
    songs.shuffle(random);
    final slots = _spreadKeys(
      songs.length,
      _looseFor(looseness, songs.length, count),
      random,
    );
    for (var j = 0; j < songs.length; j++) {
      keys[songs[j]] = slots[j];
    }
  }
  final skeleton = List<int>.generate(count, (i) => i)
    ..sort((a, b) => keys[a].compareTo(keys[b]));

  final artistGap = [
    for (final artist in artists)
      _cooldown(artist == null ? 1 : byArtist[artist]!.length, count, 3),
  ];
  final albumGap = [
    for (final album in albums) _cooldown(albumSizes[album]!, count, 8),
  ];

  // When every song of the window clashes the least bad one is taken, so the
  // result is always a permutation of the pool.
  final lastArtist = <String, int>{};
  final lastAlbum = <int, int>{};
  var position = 0;
  for (final song in recent) {
    final artist = artistOf(song);
    if (artist != null) lastArtist[artist] = position;
    lastAlbum[albumOf(song)] = position;
    position++;
  }

  double penalty(int i) {
    var total = 0.0;
    final artist = artists[i];
    final artistAt = artist == null ? null : lastArtist[artist];
    if (artistAt != null) {
      final gap = artistGap[i];
      final distance = position - artistAt;
      if (distance <= gap) total += (gap + 1 - distance) / (gap + 1);
    }
    final albumAt = lastAlbum[albums[i]];
    if (albumAt != null) {
      final gap = albumGap[i];
      final distance = position - albumAt;
      if (distance <= gap) total += (gap + 1 - distance) / (gap + 1);
    }
    return total;
  }

  final result = <int>[];
  final ahead = <int>[];
  var cursor = 0;
  while (result.length < count) {
    while (ahead.length < window && cursor < count) {
      ahead.add(skeleton[cursor++]);
    }
    var best = 0;
    var bestPenalty = double.infinity;
    for (var k = 0; k < ahead.length; k++) {
      final value = penalty(ahead[k]);
      if (value < bestPenalty) {
        best = k;
        bestPenalty = value;
        if (value == 0) break;
      }
    }
    final i = ahead.removeAt(best);
    result.add(pool[i]);
    final artist = artists[i];
    if (artist != null) lastArtist[artist] = position;
    lastAlbum[albums[i]] = position;
    position++;
  }
  return result;
}

/// Jitter allowed to a group of [size] songs among [total]. Dense groups get
/// less, so that two songs of the group are not pushed next to each other.
double _looseFor(double looseness, int size, int total) =>
    looseness * max(0.0, 1 - 2 * size / total);

/// How many songs should be played between two songs of a group of [size]
/// among [total]: at most [cap], and never more than the group can afford
/// (the cooldown fits 80% of the average distance between its songs).
int _cooldown(int size, int total, int cap) =>
    min(cap, max(0, (0.8 * total / size).floor() - 1));

/// Positions of [count] songs spread on the circle [0, 1): evenly spaced from
/// a random phase, each one moved by up to half of [looseness] slots.
List<double> _spreadKeys(int count, double looseness, Random random) {
  final phase = random.nextDouble();
  return [
    for (var j = 0; j < count; j++)
      (phase + (j + (random.nextDouble() - 0.5) * looseness) / count) % 1.0,
  ];
}

/// Orders the [songs] of one artist so that the songs of each album are
/// spread among the others (a random order when there is a single album).
List<int> _interleaveAlbums(
  List<int> songs,
  List<int> albums,
  double looseness,
  Random random,
) {
  final byAlbum = <int, List<int>>{};
  for (final song in songs) {
    (byAlbum[albums[song]] ??= []).add(song);
  }
  if (byAlbum.length < 2) return songs.toList()..shuffle(random);
  final keys = <int, double>{};
  for (final tracks in byAlbum.values) {
    tracks.shuffle(random);
    final slots = _spreadKeys(
      tracks.length,
      _looseFor(looseness, tracks.length, songs.length),
      random,
    );
    for (var j = 0; j < tracks.length; j++) {
      keys[tracks[j]] = slots[j];
    }
  }
  return songs.toList()..sort((a, b) => keys[a]!.compareTo(keys[b]!));
}
