import 'dart:math';

import 'package:classipod/core/models/playback_shuffle_mode.dart';
import 'package:classipod/core/models/shuffle_algorithm.dart';
import 'package:classipod/core/services/playback/shuffle_algorithms.dart';
import 'package:just_audio/just_audio.dart';

/// Every song, including the ones added with "Play next" / "Add to queue",
/// is a plain member of [_order]. Next/previous is always +1 / -1.
class LogicalQueue {
  final Random random;
  List<int> _order = [];
  List<int> _positions = [];
  int _total = 0;
  int index = 0;

  /// Songs explicitly queued by the user (to keep them right after the
  /// current song when the shuffle mode changes).
  final Set<int> _queued = {};

  /// Songs that have entered the explored part of the queue, in their
  /// original playback order. This is a high-water mark: going backwards
  /// never makes a song unexplored again.
  final List<int> _exploredOrder = [];
  final Set<int> _explored = {};

  PlaybackShuffleMode shuffleMode = PlaybackShuffleMode.off;
  List<List<int>> _albums = [];
  LoopMode loopMode = LoopMode.off;

  /// How the songs are mixed when [shuffleMode] is songs.
  ShuffleAlgorithm shuffleAlgorithm = ShuffleAlgorithm.random;

  /// Deviation allowed to the smart shuffle (see [SmartVariation]).
  double smartJitter = SmartVariation.medium.jitter;

  /// Artist key of every song (null = unknown) and album id of every song.
  List<String?> _artists = [];
  List<int> _albumOfSong = [];

  LogicalQueue({Random? random}) : random = random ?? Random();

  int get length => _order.length;

  int get position => _positionOf(index);

  int _positionOf(int song) =>
      song >= 0 && song < _positions.length && _positions[song] >= 0
      ? _positions[song]
      : 0;

  void reset(
    int length, {
    List<List<int>>? albums,
    List<String?>? artists,
    int initialIndex = 0,
  }) {
    index = initialIndex;
    _total = length;
    _queued.clear();
    _exploredOrder.clear();
    _explored.clear();
    _order = List.generate(length, (index) => index);
    _albums =
        albums ??
        [
          for (final index in _order) [index],
        ];
    _artists = artists != null && artists.length == length
        ? List<String?>.of(artists)
        : List<String?>.filled(length, null);
    _indexAlbums();
    _reorder();
  }

  void _indexAlbums() {
    _albumOfSong = List.filled(_total, -1);
    for (var album = 0; album < _albums.length; album++) {
      for (final song in _albums[album]) {
        if (song >= 0 && song < _total) _albumOfSong[song] = album;
      }
    }
  }

  String? _artistOf(int song) =>
      song >= 0 && song < _artists.length ? _artists[song] : null;

  /// Songs without a known album get an id of their own.
  int _albumOf(int song) =>
      song >= 0 && song < _albumOfSong.length && _albumOfSong[song] >= 0
      ? _albumOfSong[song]
      : -(song + 2);

  /// Sets the algorithm used by the songs shuffle. Returns true when the
  /// current order has to be shuffled again to apply the change.
  bool configureShuffle(ShuffleAlgorithm algorithm, double jitter) {
    final reorder =
        algorithm != shuffleAlgorithm ||
        (algorithm == ShuffleAlgorithm.smart && jitter != smartJitter);
    shuffleAlgorithm = algorithm;
    smartJitter = jitter;
    return reorder;
  }

  /// Songs that have been played, skipped, or passed while moving forward.
  /// The returned order is stable even when the current index moves backwards.
  List<int> get explored => List.unmodifiable(_exploredOrder);

  /// Advances the exploration frontier through [song]. Every song before it
  /// in queue order is considered explored too (they were necessarily passed).
  /// Calling this for a song behind the frontier never rewinds it.
  void markExploredThrough(int song) {
    if (song < 0 || song >= _positions.length || _positions[song] < 0) return;
    final target = _positions[song];
    for (var i = _exploredOrder.length; i <= target && i < _order.length; i++) {
      final passed = _order[i];
      if (_explored.add(passed)) _exploredOrder.add(passed);
    }
  }

  /// Songs of the order that have not been played yet.
  List<int> get upcoming {
    if (index < 0 || index >= _positions.length || _positions[index] < 0) {
      return [];
    }
    return _order.sublist(_positions[index] + 1);
  }

  /// Registers a song added after the queue was built and returns its index.
  /// It is not in the order until [queue] places it.
  int addExtra({String? artist}) {
    final song = _total++;
    _albums = [
      ..._albums,
      [song],
    ];
    _albumOfSong = [..._albumOfSong, _albums.length - 1];
    _artists = [..._artists, artist];
    _positions = [..._positions, -1];
    return song;
  }

  /// Places [songs] after the current one.
  void queue(List<int> songs, {required bool playNext}) {
    if (songs.isEmpty) return;
    final moving = songs.toSet();
    _order.removeWhere(moving.contains);
    final current = _order.indexOf(index);
    // Never insert into the explored prefix, even if the user has navigated
    // backwards into it.
    var at = max(current + 1, _exploredOrder.length);
    if (!playNext) {
      while (at < _order.length && _queued.contains(_order[at])) {
        at++;
      }
    }
    _order.insertAll(at, songs);
    _queued.addAll(songs);
    _indexPositions();
  }

  int? get first => _order.isEmpty ? null : _order.first;

  void setShuffle(
    PlaybackShuffleMode mode, {
    bool keepCurrent = true,
    bool force = false,
  }) {
    if (shuffleMode == mode && !force) return;

    // Entering song shuffle from an ordered/album queue starts a fresh mix
    // of the whole playlist. Keep the current song as the anchor, but allow
    // previously explored tracks to participate in the new shuffled tail.
    if (mode == PlaybackShuffleMode.songs &&
        shuffleMode != PlaybackShuffleMode.songs) {
      _exploredOrder.clear();
      _explored.clear();
    }

    shuffleMode = mode;
    _reorder(keepCurrent: keepCurrent);
  }

  void _reorder({bool keepCurrent = true}) {
    if (!keepCurrent) {
      _exploredOrder.clear();
      _explored.clear();
    }
    final current = keepCurrent && _order.contains(index) ? index : null;

    final pending = <int>[];
    if (current != null) {
      final from = _order.indexOf(current) + 1;
      for (var i = from; i < _order.length; i++) {
        if (_queued.contains(_order[i])) pending.add(_order[i]);
      }
    } else {
      _queued.clear();
    }

    switch (shuffleMode) {
      case PlaybackShuffleMode.off:
        _order.sort();
      case PlaybackShuffleMode.songs:
        if (shuffleAlgorithm == ShuffleAlgorithm.random) {
          _order.shuffle(random);
          if (current != null && _order.remove(current)) {
            _order.insert(0, current);
          }
        } else {
          // The current song and the songs queued by the user stay first, the
          // rest is ordered avoiding clashes with them.
          final head = <int>[?current, ...pending];
          final placed = head.toSet();
          final pool = _order.where((song) => !placed.contains(song)).toList();
          _order = [
            ...head,
            ...orderSongs(
              algorithm: shuffleAlgorithm,
              pool: pool,
              recent: head,
              artistOf: _artistOf,
              albumOf: _albumOf,
              random: random,
              jitter: smartJitter,
            ),
          ];
        }
      case PlaybackShuffleMode.albums:
        final albums = _albums.toList()..shuffle(random);
        final currentAlbum = current == null
            ? -1
            : albums.indexWhere((album) => album.contains(current));
        if (currentAlbum >= 0) albums.insert(0, albums.removeAt(currentAlbum));
        _order = albums.expand((album) => album).toList();
    }

    if (pending.isNotEmpty) {
      final moving = pending.toSet();
      _order.removeWhere(moving.contains);
      final insertion = current == null
          ? _exploredOrder.length
          : max(_order.indexOf(current) + 1, _exploredOrder.length);
      _order.insertAll(insertion, pending);
    }

    // Reordering may only affect the unexplored tail. The explored prefix is
    // immutable, including after previous/seek-back and shuffle reconfiguration.
    final exploredSet = _exploredOrder.toSet();
    _order.removeWhere(exploredSet.contains);
    _order.insertAll(0, _exploredOrder);
    _indexPositions();
  }

  void _indexPositions() {
    _positions = List.filled(_total, -1);
    for (var position = 0; position < length; position++) {
      _positions[_order[position]] = position;
    }
  }

  int? next({bool automatic = false}) {
    if (_order.isEmpty) return null;
    if (automatic && loopMode == LoopMode.one) return index;
    final position = _positionOf(index) + 1;
    if (position < length) return _order[position];
    return loopMode == LoopMode.all ? _order.first : null;
  }

  int? previous() {
    if (_order.isEmpty) return null;
    final position = _positionOf(index) - 1;
    if (position >= 0) return _order[position];
    return loopMode == LoopMode.all ? _order.last : null;
  }
}
