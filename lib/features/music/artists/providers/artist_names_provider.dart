import 'package:classipod/core/providers/filtered_audio_files_provider.dart';
import 'package:classipod/core/utils/name_order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final artistNamesProvider = Provider<List<String>>((ref) {
  final artistNamesSet = <String>{};
  for (final audioFile in ref.watch(filteredAudioFilesProvider).value ?? []) {
    artistNamesSet.addAll(audioFile.albumArtistList);
  }

  final artistNames = artistNamesSet.toList();
  artistNames.sort(compareNames);

  return artistNames;
});
