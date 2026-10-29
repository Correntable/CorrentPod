import 'dart:math';

import 'package:classipod/core/models/playback_shuffle_mode.dart';
import 'package:just_audio/just_audio.dart';

class LogicalQueue {
  final Random random;
  List<int> _order = [];
  List<int> _positions = [];
  int _total = 0;
  int index = 0;

  /// Song of the regular order we left to play queued songs. While a queued
  /// song is playing, the queue position shown is the one of this song.
  int? anchor;

  /// Slots (positions in the regular order) after which a queued song has
  /// been played. They shift the numbering of everything that follows.
  final List<int> _insertedAt = [];

  /// Songs taken out of the regular order because they were queued.
  final Set<int> _removed = {};
  PlaybackShuffleMode shuffleMode = PlaybackShuffleMode.off;
  List<List<int>> _albums = [];
  LoopMode loopMode = LoopMode.off;

  LogicalQueue({Random? random}) : random = random ?? Random();

  int get length => _order.length;

  /// Songs added on the fly, which live outside the regular order.
  int get extraCount => _total - _order.length;

  /// Position shown to the user: counts the queued songs already played.
  int get position {
    final a = anchor;
    final slot = _slot(a ?? index);
    var shift = 0;
    for (final at in _insertedAt) {
      if (at < slot || (a != null && at == slot)) shift++;
    }
    return slot + shift;
  }

  int _slot(int song) =>
      song >= 0 && song < _positions.length && _positions[song] >= 0
      ? _positions[song]
      : 0;

  /// Call when a queued song starts playing.
  void recordExtra() {
    final a = anchor;
    if (a != null) _insertedAt.add(_slot(a));
  }

  int _positionOf(int song) {
    if (song >= 0 && song < _positions.length && _positions[song] >= 0) {
      return _positions[song];
    }
    final a = anchor;
    if (a != null && a >= 0 && a < _positions.length && _positions[a] >= 0) {
      return _positions[a];
    }
    return 0;
  }

  void reset(int length, {List<List<int>>? albums, int initialIndex = 0}) {
    index = initialIndex;
    anchor = null;
    _total = length;
    _removed.clear();
    _order = List.generate(length, (index) => index);
    _albums =
        albums ??
        [
          for (final index in _order) [index],
        ];
    _reorder();
  }

  /// Registers a song added after the queue was built. It is not part of the
  /// regular order: it can only be played through the "up next" list.
  int addExtra() {
    _positions = [..._positions, -1];
    return _total++;
  }

  /// Songs of the regular order that have not been played yet.
  List<int> get upcoming {
    final from = anchor ?? index;
    if (from < 0 || from >= _positions.length || _positions[from] < 0) {
      return [];
    }
    return _order.sublist(_positions[from] + 1);
  }

  /// Takes a song out of the regular order (it is queued instead).
  bool removeFromOrder(int song) {
    if (!_order.remove(song)) return false;
    _removed.add(song);
    _indexPositions();
    return true;
  }

  void setShuffle(PlaybackShuffleMode mode) {
    if (shuffleMode == mode) return;
    shuffleMode = mode;
    _reorder();
  }

  int? get _contextCurrent => _order.contains(index) ? index : anchor;

  void _reorder() {
    _insertedAt.clear();
    switch (shuffleMode) {
      case PlaybackShuffleMode.off:
        _order.sort();
      case PlaybackShuffleMode.songs:
        _order.shuffle(random);
        final current = _contextCurrent;
        if (current != null && _order.remove(current)) {
          _order.insert(0, current);
        }
      case PlaybackShuffleMode.albums:
        final albums = _albums.toList()..shuffle(random);
        final current = _contextCurrent;
        final currentAlbum = current == null
            ? -1
            : albums.indexWhere((album) => album.contains(current));
        if (currentAlbum >= 0) albums.insert(0, albums.removeAt(currentAlbum));
        _order = albums
            .expand((album) => album)
            .where((song) => !_removed.contains(song))
            .toList();
    }
    _indexPositions();
  }

  void _indexPositions() {
    _positions = List.filled(_total, -1);
    for (var position = 0; position < length; position++) {
      _positions[_order[position]] = position;
    }
  }

  int? next({bool automatic = false, int? from}) {
    if (_order.isEmpty) return null;
    final current = from ?? index;
    if (automatic && loopMode == LoopMode.one) return current;
    final position = _positionOf(current) + 1;
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
