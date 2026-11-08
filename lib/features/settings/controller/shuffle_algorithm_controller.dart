import 'package:classipod/core/models/shuffle_algorithm.dart';
import 'package:classipod/core/providers/shared_preferences_with_cache_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Setting: how the songs are mixed when the shuffle mode is "Songs".
final shuffleAlgorithmProvider =
    NotifierProvider<ShuffleAlgorithmNotifier, ShuffleAlgorithm>(
      ShuffleAlgorithmNotifier.new,
    );

class ShuffleAlgorithmNotifier extends Notifier<ShuffleAlgorithm> {
  static const _key = 'shuffleAlgorithm';

  @override
  ShuffleAlgorithm build() {
    final prefs = ref.watch(sharedPreferencesWithCacheProvider).value;
    final name = prefs?.getString(_key);
    // Values saved by older versions ("lessRandom", "smart") do not exist any
    // more and fall back to the balanced default.
    return ShuffleAlgorithm.values.asNameMap()[name] ??
        ShuffleAlgorithm.balanced;
  }

  Future<void> toggle() async {
    final next = state.next;
    state = next;
    final prefs = ref.read(sharedPreferencesWithCacheProvider).value;
    await prefs?.setString(_key, next.name);
  }
}
