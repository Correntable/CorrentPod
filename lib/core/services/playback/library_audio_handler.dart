import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:classipod/core/models/music_metadata.dart';
import 'package:classipod/core/models/playback_shuffle_mode.dart';
import 'package:classipod/core/services/playback/logical_queue.dart';
import 'package:classipod/core/utils/album_order.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class LibraryAudioHandler extends BaseAudioHandler {
  final AudioPlayer player;
  final Duration retryDelay;
  Timer? _retryTimer;
  bool _disposed = false;
  bool restoringSession = false;
  VoidCallback? onCheckpoint;
  VoidCallback? onRestoreFailure;
  bool _restoredSongPending = false;
  Duration? _initialPosition;

  List<MusicMetadata> get songs => _songs;
  bool get loading => _loading;
  bool _wantPlayback = false;
  bool _recovering = false;
  int _retryAttempt = 0;
  Duration _lastPosition = Duration.zero;
  Duration _resumePosition = Duration.zero;
  Completer<void>? _pendingSeek;
  Duration? _seekTarget;

  void _interruptSeek() {
    final pending = _pendingSeek;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  bool get recovering => _recovering;
  bool get wantsPlayback => _wantPlayback;
  Duration get displayPosition => _recovering ? _resumePosition : _lastPosition;

  void _cancelRecovery() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _recovering = false;
    _retryAttempt = 0;
  }

  void _scheduleRetry() {
    if (_disposed || !_recovering || !_wantPlayback || _retryTimer != null) {
      return;
    }
    final multiplier = 1 << _retryAttempt.clamp(0, 3);
    _retryAttempt++;
    _retryTimer = Timer(retryDelay * multiplier, () {
      _retryTimer = null;
      unawaited(
        _serialize(() async {
          if (_disposed || !_recovering || !_wantPlayback || _songs.isEmpty) {
            return;
          }
          try {
            await _load(
              logicalQueue.index,
              startPlaying: true,
              recovering: true,
            );
          } catch (_) {}
        }),
      );
    });
  }

  final Future<UriAudioSource> Function(MusicMetadata)? resolveSource;
  bool _sourceLoaded = false;
  int _sourceVersion = 0;
  final LogicalQueue logicalQueue = LogicalQueue();
  final StreamController<int?> _indices = StreamController.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<MusicMetadata> _songs = [];
  Future<void> _pending = Future.value();
  bool _loading = false;
  String? _error;
  int _errorCode = 1;
  static const serverConnectionErrorCode = 2;

  LibraryAudioHandler(
    this.player, {
    this.resolveSource,
    this.retryDelay = const Duration(seconds: 3),
  }) {
    _subscriptions.add(
      player.positionStream.listen((position) {
        if (!_loading &&
            _sourceLoaded &&
            _pendingSeek == null &&
            !_recovering &&
            player.processingState == ProcessingState.ready) {
          if (position > Duration.zero) {
            _lastPosition = position;
            _restoredSongPending = false;
          }
        }
        _broadcast();
      }),
    );
    _subscriptions.add(player.playbackEventStream.listen((_) => _broadcast()));
    _subscriptions.add(player.playingStream.listen((_) => _broadcast()));
    _subscriptions.add(
      player.processingStateStream.distinct().listen((processing) {
        if (processing == ProcessingState.completed &&
            player.playing &&
            !_loading) {
          unawaited(
            _serialize(() async {
              if (!player.playing ||
                  player.processingState != ProcessingState.completed) {
                return;
              }
              final next = _nextIndex(automatic: true);
              if (next == null) {
                await player.pause();
              } else {
                await _load(next, startPlaying: true);
              }
            }).catchError(_reportError),
          );
        }
      }),
    );
    _subscriptions.add(player.errorStream.listen(_reportError));
  }

  Stream<int?> get indexStream => _indices.stream;
  int? get currentIndex => _songs.isEmpty ? null : logicalQueue.index;

  Future<void> _serialize(Future<void> Function() action) {
    final result = _pending.then((_) async {
      try {
        await action();
      } finally {
        onCheckpoint?.call();
      }
    });
    _pending = result.catchError((Object _) {});
    return result;
  }

  void _resetQueue({int initialIndex = 0}) {
    final albums = <Object, List<int>>{};
    for (var index = 0; index < _songs.length; index++) {
      final song = _songs[index];
      final Object key =
          (song.albumName?.trim().isNotEmpty ?? false) ||
              song.remoteAlbumId != null
          ? albumIdentityOf(song)
          : index;
      albums.putIfAbsent(key, () => []).add(index);
    }
    for (final album in albums.values) {
      album.sort((a, b) {
        final comparison = compareAlbumTracks(_songs[a], _songs[b]);
        return comparison == 0 ? a.compareTo(b) : comparison;
      });
    }
    logicalQueue.reset(
      _songs.length,
      albums: albums.values.toList(),
      initialIndex: initialIndex,
    );
  }

  Future<void> setSongs(List<MusicMetadata> songs, {bool preload = true}) {
    _restoredSongPending = false;
    _interruptSeek();
    _wantPlayback = false;
    _cancelRecovery();
    return _serialize(() async {
      final hadSongs = _songs.isNotEmpty;
      if (hadSongs) await player.pause();
      _songs = List.unmodifiable(songs);
      _resetQueue();
      _initialPosition = null;
      _lastPosition = Duration.zero;
      if (songs.isEmpty) {
        _error = null;
        if (hadSongs)
