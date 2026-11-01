import 'dart:math';

import 'package:classipod/core/models/playback_shuffle_mode.dart';
import 'package:classipod/core/models/shuffle_algorithm.dart';
import 'package:classipod/core/services/playback/logical_queue.dart';
import 'package:classipod/core/services/playback/shuffle_algorithms.dart';
import 'package:flutter_test/flutter_test.dart';

/// 10 artists with 10 songs each: song `i` belongs to artist `i % 10`.
final artists = <String?>[for (var i = 0; i < 100; i++) 'artist ${i % 10}'];

List<int> run(
  ShuffleAlgorithm algorithm,
  int seed, {
  double jitter = 0.3,
  List<int> recent = const [],
}) {
  final pool = [
    for (var i = 0; i < artists.length; i++)
      if (!recent.contains(i)) i,
  ];
  return orderSongs(
    algorithm: algorithm,
    pool: pool,
    recent: recent,
    artistOf: (song) => artists[song],
    albumOf: (song) => song,
    random: Random(seed),
    jitter: jitter,
  );
}

int sameArtistNeighbours(List<int> order) {
  var count = 0;
  for (var i = 1; i < order.length; i++) {
    if (artists[order[i]] == artists[order[i - 1]]) count++;
  }
  return count;
}

double averageNeighbours(ShuffleAlgorithm algorithm) {
  var total = 0;
  for (var seed = 0; seed < 30; seed++) {
    total += sameArtistNeighbours(run(algorithm, seed));
  }
  return total / 30;
}

List<int> playingOrder(LogicalQueue queue) {
  final order = <int>[queue.index];
  while (queue.next() != null) {
    queue.index = queue.next()!;
    order.add(queue.index);
  }
  return order;
}

void main() {
  test('every algorithm returns a permutation of the songs', () {
    for (final algorithm in ShuffleAlgorithm.values) {
      for (var seed = 0; seed < 10; seed++) {
        final order = run(algorithm, seed);
        expect(order.length, 100);
        expect(order.toSet().length, 100);
      }
    }
  });

  test('the same seed gives the same order', () {
    for (final algorithm in ShuffleAlgorithm.values) {
      expect(run(algorithm, 7), run(algorithm, 7));
    }
  });

  test('less random and smart avoid songs of the same artist in a row', () {
    // A plain random shuffle of 10 artists x 10 songs has about 9 of them.
    expect(averageNeighbours(ShuffleAlgorithm.random), greaterThan(4));
    expect(averageNeighbours(ShuffleAlgorithm.lessRandom), lessThan(2));
    expect(averageNeighbours(ShuffleAlgorithm.smart), lessThan(2));
  });

  test('smart shuffle spreads every artist along the whole queue', () {
    for (var seed = 0; seed < 10; seed++) {
      final order = run(ShuffleAlgorithm.smart, seed, jitter: 0.1);
      for (var artist = 0; artist < 10; artist++) {
        final positions = [
          for (var i = 0; i < order.length; i++)
            if (artists[order[i]] == 'artist $artist') i,
        ];
        expect(positions.first, lessThan(30));
        expect(positions.last, greaterThan(69));
      }
    }
  });

  test('the first songs do not clash with the songs already placed', () {
    for (final algorithm in [ShuffleAlgorithm.lessRandom, ShuffleAlgorithm.smart]) {
      for (var seed = 0; seed < 10; seed++) {
        final order = run(algorithm, seed, recent: [0]);
        expect(order.length, 99);
        expect(artists[order.first], isNot(artists[0]));
      }
    }
  });

  test('queue keeps the current and the queued songs first', () {
    final queue = LogicalQueue(random: Random(3))
      ..reset(100, artists: artists, initialIndex: 7)
      ..configureShuffle(ShuffleAlgorithm.smart, 0.3);
    queue.setShuffle(PlaybackShuffleMode.songs);
    expect(queue.index, 7);
    expect(queue.position, 0);
    expect(playingOrder(queue).toSet().length, 100);

    queue
      ..index = 7
      ..queue([42], playNext: true);
    expect(queue.configureShuffle(ShuffleAlgorithm.lessRandom, 0.3), isTrue);
    queue.setShuffle(PlaybackShuffleMode.songs, force: true);
    expect(queue.index, 7);
    expect(queue.next(), 42);
  });

  test('songs without metadata can still be shuffled', () {
    for (final algorithm in ShuffleAlgorithm.values) {
      final queue = LogicalQueue(random: Random(1))
        ..reset(12)
        ..configureShuffle(algorithm, 0.3);
      queue.setShuffle(PlaybackShuffleMode.songs);
      expect(playingOrder(queue).toSet().length, 12);
    }
  });

  test('configureShuffle only asks for a new shuffle when it matters', () {
    final queue = LogicalQueue();
    expect(queue.configureShuffle(ShuffleAlgorithm.random, 0.1), isFalse);
    expect(queue.configureShuffle(ShuffleAlgorithm.lessRandom, 0.1), isTrue);
    expect(queue.configureShuffle(ShuffleAlgorithm.lessRandom, 0.6), isFalse);
    expect(queue.configureShuffle(ShuffleAlgorithm.smart, 0.6), isTrue);
    expect(queue.configureShuffle(ShuffleAlgorithm.smart, 0.1), isTrue);
  });
}
