import 'dart:math';

import 'package:classipod/core/models/playback_shuffle_mode.dart';
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

  PlaybackShuffleMode shuffleMode = PlaybackShuffleMode.off;
  List<List<int>> _albums = [];
  LoopMode loopMode = LoopMode.off;

  LogicalQueue({Random? random}) : random = random ?? Random();

  int get length => _order.length;

  int get position => _positionOf(index);

  int _positionOf(int song) =>
      song >= 0 && song < _positions.length && _positions[song] >= 0
      ? _positions[song]
      : 0;

  void reset(int length, {List<List<int>>? albums, int initialIndex = 0}) {
    index = initialIndex;
    _total = length;
    _queued.clear();
    _order = List.generate(length, (index) => index);
    _albums =
        albums ??
        [
          for (final index in _order) [index],
        ];
    _reorder();
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
  int addExtra() {
    final song = _total++;
    _albums = [
      ..._albums,
      [song],
    ];
    _positions = [..._positions, -1];
    return song;
  }

  /// Places [songs] after the current one.
  void queue(List<int> songs, {required bool playNext}) {
    if (songs.isEmpty) return;
    final moving = songs.toSet();
    _order.removeWhere(moving.contains);
    final current = _order.indexOf(index);
    var at = current + 1;
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
    shuffleMode = mode;
    _reorder(keepCurrent: keepCurrent);
  }

  void _reorder({bool keepCurrent = true}) {
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
        _order.shuffle(random);
        if (current != null && _order.remove(current)) {
          _order.insert(0, current);
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
      _order.insertAll(_order.indexOf(current!) + 1, pending);
    }
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
