/// Names are no longer split on separators such as "&", ",", ";" or "feat.".
/// The whole string is kept as a single name.
List<String> splitArtistNames(String artistNames) {
  final name = artistNames.trim();
  return name.isEmpty ? <String>[] : <String>[name];
}
