import 'dart:math';

import 'package:classipod/core/models/playback_shuffle_mode.dart';
import 'package:classipod/core/models/shuffle_algorithm.dart';
import 'package:classipod/core/services/playback/logical_queue.dart';
import 'package:classipod/core/services/playback/shuffle_algorithms.dart';
import 'package:flutter_test/flutter_test.dart';

/// A small library: song `i` has `artists[i]` and `albums[i]`.
class Library {
  Library(this.artists, [List<int>? albums])
    : albums = albums ?? List.generate(artists.length, (i) => i);

  final List<String?> artists;
  final List<int> albums;

  int get length => artists.length;

  List<int> order(
    ShuffleAlgorithm algorithm,
    int seed, {
    List<int> recent = const [],
  }) => orderSongs(
    algorithm: algorithm,
    pool: [
      for (var i = 0; i < length; i++)
        if (!recent.contains(i)) i,
    ],
    recent: recent,
    artistOf: (song) => artists[song],
    albumOf: (song) => albums[song],
    random: Random(seed),
  );

  int sameArtistInARow(List<int> order) {
    var count = 0;
    for (var i = 1; i < order.length; i++) {
      if (artists[order[i]] != null &&
          artists[order[i]] == artists[order[i - 1]]) {
        count++;
      }
    }
    return count;
  }
}

/// 10 artists x 10 songs, two albums of 5 songs each.
final tenByTen = Library(
  [for (var i = 0; i < 100; i++) 'artist ${i % 10}'],
  [for (var i = 0; i < 100; i++) (i % 10) * 2 + (i ~/ 10) % 2],
);

/// 200 songs: a few prolific artists and many with one or two songs.
final longTail = () {
  final sizes = [
    60,
    40,
    25,
    15,
    10,
    8,
    6,
    5,
    4,
    3,
    2,
    2,
    ...List.filled(20, 1),
  ];
  return Library([
    for (var a = 0; a < sizes.length; a++)
      for (var k = 0; k < sizes[a]; k++) 'artist $a',
  ]);
}();

/// One artist owns 40 of the 100 songs.
final dominant = Library(
  [
    for (var i = 0; i < 40; i++) 'big',
    for (var a = 0; a < 12; a++)
      for (var k = 0; k < 5; k++) 'artist $a',
  ],
  [
    for (var i = 0; i < 40; i++) i ~/ 10,
    for (var a = 0; a < 12; a++)
      for (var k = 0; k < 5; k++) 10 + a,
  ],
);

/// 25 artists x 10 songs plus a 16 track compilation by 16 different artists.
final compilation = Library(
  [
    for (var a = 0; a < 25; a++)
      for (var k = 0; k < 10; k++) 'artist $a',
    for (var k = 0; k < 16; k++) 'guest $k',
  ],
  [
    for (var a = 0; a < 25; a++)
      for (var k = 0; k < 10; k++) a * 2 + k ~/ 5,
    for (var k = 0; k < 16; k++) 999,
  ],
);

List<int> playingOrder(LogicalQueue queue) {
  final order = <int>[queue.index];
  while (queue.next() != null) {
    queue.index = queue.next()!;
    order.add(queue.index);
  }
  return order;
}

/// Statistics over many independent shuffles of [library].
({double tinyVsBig, double tinyPosition, double bigPosition, double overlap})
fairness(Library library, ShuffleAlgorithm algorithm) {
  const runs = 600;
  const head = 10;
  final n = library.length;
  final size = <String?, int>{};
  for (final artist in library.artists) {
    size[artist] = (size[artist] ?? 0) + 1;
  }
  final inHead = List.filled(n, 0);
  final position = List.filled(n, 0.0);
  var overlap = 0;
  Set<int>? previous;
  for (var seed = 0; seed < runs; seed++) {
    final order = library.order(algorithm, seed);
    final first = order.take(head).toSet();
    for (final song in first) {
      inHead[song]++;
    }
    if (previous != null) overlap += first.intersection(previous).length;
    previous = first;
    for (var i = 0; i < n; i++) {
      position[order[i]] += i / (n - 1);
    }
  }
  var tinyHead = 0.0, bigHead = 0.0, tinyPos = 0.0, bigPos = 0.0;
  var tiny = 0, big = 0;
  for (var song = 0; song < n; song++) {
    final songs = size[library.artists[song]]!;
    if (songs <= 3) {
      tinyHead += inHead[song] / runs;
      tinyPos += position[song] / runs;
      tiny++;
    } else if (songs >= 15) {
      bigHead += inHead[song] / runs;
      bigPos += position[song] / runs;
      big++;
    }
  }
  return (
    tinyVsBig: (tinyHead / tiny) / (bigHead / big),
    tinyPosition: tinyPos / tiny,
    bigPosition: bigPos / big,
    // 1.0 is what independent uniform shuffles give.
    overlap: overlap / (runs - 1) / (head * head / n),
  );
}

void main() {
  group('orderSongs', () {
    test('every algorithm returns a permutation of the songs', () {
      for (final algorithm in ShuffleAlgorithm.values) {
        for (final size in [0, 1, 2, 3, 7, 100]) {
          final library = Library([
            for (var i = 0; i < size; i++) 'artist ${i % 3}',
          ]);
          for (var seed = 0; seed < 5; seed++) {
            final order = library.order(algorithm, seed);
            expect(order, hasLength(size));
            expect(order.toSet(), List.generate(size, (i) => i).toSet());
          }
        }
      }
    });

    test('the same seed gives the same order, another seed another one', () {
      for (final algorithm in ShuffleAlgorithm.values) {
        expect(tenByTen.order(algorithm, 7), tenByTen.order(algorithm, 7));
        expect(
          tenByTen.order(algorithm, 7),
          isNot(tenByTen.order(algorithm, 8)),
        );
      }
    });

    test('the random algorithm is a plain shuffle', () {
      // About 10 songs in a row from the same artist: the baseline that the
      // balanced algorithm has to beat.
      var total = 0;
      for (var seed = 0; seed < 30; seed++) {
        total += tenByTen.sameArtistInARow(
          tenByTen.order(ShuffleAlgorithm.random, seed),
        );
      }
      expect(total / 30, greaterThan(7));
    });
  });

  group('balanced', () {
    test('keeps songs of the same artist apart', () {
      var total = 0;
      for (var seed = 0; seed < 50; seed++) {
        total += tenByTen.sameArtistInARow(
          tenByTen.order(ShuffleAlgorithm.balanced, seed),
        );
      }
      // A plain shuffle gives about 480 in 50 shuffles.
      expect(total, lessThan(6));
    });

    test('spreads every artist along the whole queue', () {
      for (var seed = 0; seed < 50; seed++) {
        final order = tenByTen.order(ShuffleAlgorithm.balanced, seed);
        for (var artist = 0; artist < 10; artist++) {
          final positions = [
            for (var i = 0; i < order.length; i++)
              if (tenByTen.artists[order[i]] == 'artist $artist') i,
          ];
          expect(positions.first, lessThan(30));
          expect(positions.last, greaterThan(69));
        }
      }
    });

    test('keeps the songs of an album apart', () {
      var close = 0;
      for (var seed = 0; seed < 50; seed++) {
        final order = tenByTen.order(ShuffleAlgorithm.balanced, seed);
        for (var i = 0; i < order.length; i++) {
          for (var j = max(0, i - 4); j < i; j++) {
            if (tenByTen.albums[order[i]] == tenByTen.albums[order[j]]) close++;
          }
        }
      }
      expect(close, lessThan(6));
    });

    test('does not clump an artist that owns 40% of the library', () {
      var balanced = 0;
      var random = 0;
      for (var seed = 0; seed < 100; seed++) {
        balanced += dominant.sameArtistInARow(
          dominant.order(ShuffleAlgorithm.balanced, seed),
        );
        random += dominant.sameArtistInARow(
          dominant.order(ShuffleAlgorithm.random, seed),
        );
      }
      expect(balanced / 100, lessThan(1.5));
      expect(random / 100, greaterThan(10));
    });

    test('spreads the songs of a compilation by many artists', () {
      var close = 0;
      for (var seed = 0; seed < 100; seed++) {
        final order = compilation.order(ShuffleAlgorithm.balanced, seed);
        for (var i = 0; i < order.length; i++) {
          if (compilation.albums[order[i]] != 999) continue;
          for (var j = max(0, i - 8); j < i; j++) {
            if (compilation.albums[order[j]] == 999) close++;
          }
        }
      }
      // A plain shuffle puts about 7 pairs of them within 8 songs.
      expect(close / 100, lessThan(0.5));
    });

    test('the first songs do not clash with the songs already placed', () {
      for (var seed = 0; seed < 50; seed++) {
        final order = tenByTen.order(
          ShuffleAlgorithm.balanced,
          seed,
          recent: [0],
        );
        expect(order, hasLength(99));
        expect(tenByTen.artists[order.first], isNot(tenByTen.artists[0]));
        expect(tenByTen.artists[order[1]], isNot(tenByTen.artists[0]));
      }
    });

    test('unknown artists never clash and are shuffled like the others', () {
      final library = Library([
        for (var i = 0; i < 30; i++) null,
        for (var i = 0; i < 30; i++) 'artist ${i % 6}',
      ]);
      for (var seed = 0; seed < 20; seed++) {
        final order = library.order(ShuffleAlgorithm.balanced, seed);
        expect(order.toSet(), hasLength(60));
        expect(library.sameArtistInARow(order), 0);
      }
    });
  });

  group('fairness between songs', () {
    // These guard against the bias that made a new shuffle start with the
    // same songs: a scheduler that picks an artist first, with a weight that
    // does not grow like its number of songs, puts the songs of small artists
    // at the front (about 5 times as often as the others).
    test('the size of the artist does not move its songs', () {
      for (final algorithm in ShuffleAlgorithm.values) {
        final stats = fairness(longTail, algorithm);
        expect(stats.tinyVsBig, inInclusiveRange(0.8, 1.25));
        expect(stats.tinyPosition, inInclusiveRange(0.45, 0.55));
        expect(stats.bigPosition, inInclusiveRange(0.45, 0.55));
      }
    });

    test('consecutive shuffles do not start with the same songs', () {
      for (final algorithm in ShuffleAlgorithm.values) {
        expect(
          fairness(longTail, algorithm).overlap,
          inInclusiveRange(0.7, 1.4),
        );
      }
    });

    test('every song can be the first one', () {
      for (final algorithm in ShuffleAlgorithm.values) {
        final first = <int>{};
        for (var seed = 0; seed < 3000; seed++) {
          first.add(tenByTen.order(algorithm, seed).first);
        }
        expect(first, hasLength(100));
      }
    });
  });

  test('a large library is shuffled as a permutation', () {
    const size = 50000;
    final artist = [
      for (var i = 0; i < size; i++) 'artist ${(i * 7919) % 4000}',
    ];
    final order = orderSongs(
      algorithm: ShuffleAlgorithm.balanced,
      pool: List.generate(size, (i) => i),
      recent: const [],
      artistOf: (song) => artist[song],
      albumOf: (song) => song ~/ 11,
      random: Random(1),
    );
    expect(order, hasLength(size));
    expect(order.toSet(), hasLength(size));
  });

  group('LogicalQueue', () {
    test('balanced is the default algorithm', () {
      expect(LogicalQueue().shuffleAlgorithm, ShuffleAlgorithm.balanced);
    });

    test('keeps the current song and the queued songs first', () {
      final queue = LogicalQueue(random: Random(3))
        ..reset(100, artists: tenByTen.artists, initialIndex: 7)
        ..configureShuffle(ShuffleAlgorithm.balanced);
      queue.setShuffle(PlaybackShuffleMode.songs);
      expect(queue.index, 7);
      expect(queue.position, 0);
      expect(playingOrder(queue).toSet(), hasLength(100));

      queue
        ..index = 7
        ..queue([42], playNext: true);
      expect(queue.configureShuffle(ShuffleAlgorithm.random), isTrue);
      queue.setShuffle(PlaybackShuffleMode.songs, force: true);
      expect(queue.index, 7);
      expect(queue.next(), 42);

      expect(queue.configureShuffle(ShuffleAlgorithm.balanced), isTrue);
      queue.setShuffle(PlaybackShuffleMode.songs, force: true);
      expect(queue.index, 7);
      expect(queue.next(), 42);
      expect(playingOrder(queue).toSet(), hasLength(100));
    });

    test('every new shuffle from the start is a fresh balanced order', () {
      final queue = LogicalQueue(random: Random(11))
        ..reset(100, artists: tenByTen.artists, albums: _albumsOf(tenByTen));
      final heads = <String>{};
      for (var i = 0; i < 20; i++) {
        queue.setShuffle(
          PlaybackShuffleMode.songs,
          keepCurrent: false,
          force: true,
        );
        queue.index = queue.first!;
        final order = playingOrder(queue);
        expect(order.toSet(), hasLength(100));
        expect(tenByTen.sameArtistInARow(order), lessThan(3));
        heads.add(order.take(10).join(','));
      }
      expect(heads, hasLength(20));
    });

    test('songs without metadata can still be shuffled', () {
      for (final algorithm in ShuffleAlgorithm.values) {
        final queue = LogicalQueue(random: Random(1))
          ..reset(12)
          ..configureShuffle(algorithm);
        queue.setShuffle(PlaybackShuffleMode.songs);
        expect(playingOrder(queue).toSet(), hasLength(12));
      }
    });

    test('configureShuffle only asks for a new shuffle when it matters', () {
      final queue = LogicalQueue();
      expect(queue.configureShuffle(ShuffleAlgorithm.balanced), isFalse);
      expect(queue.configureShuffle(ShuffleAlgorithm.random), isTrue);
      expect(queue.configureShuffle(ShuffleAlgorithm.random), isFalse);
      expect(queue.configureShuffle(ShuffleAlgorithm.balanced), isTrue);
    });
  });
}

/// Albums as the lists of song indices that [LogicalQueue.reset] expects.
List<List<int>> _albumsOf(Library library) {
  final byAlbum = <int, List<int>>{};
  for (var i = 0; i < library.length; i++) {
    (byAlbum[library.albums[i]] ??= []).add(i);
  }
  return byAlbum.values.toList();
}
