String normalizeCategoryName(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

bool categoryNameExists(Iterable<String> names, String candidate) {
  final normalizedCandidate = normalizeCategoryName(candidate);
  if (normalizedCandidate.isEmpty) return false;
  return names.any(
    (name) => normalizeCategoryName(name) == normalizedCandidate,
  );
}

List<Map<String, dynamic>> deduplicateCategories(
  Iterable<Map<String, dynamic>> categories,
) {
  final seen = <String>{};
  final unique = <Map<String, dynamic>>[];
  for (final category in categories) {
    final name = (category['name'] ?? '').toString();
    final normalized = normalizeCategoryName(name);
    if (normalized.isEmpty || !seen.add(normalized)) continue;
    unique.add(category);
  }
  return unique;
}
