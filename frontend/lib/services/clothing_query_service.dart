class ClothingQueryService {
  static List<String> attributes(Map<String, dynamic> item) {
    final raw = item['attributes'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static DateTime? parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  static bool matchesSmartQuery(Map<String, dynamic> item, String query) {
    if (query.trim().isEmpty) return true;

    final tokens = query
        .split(RegExp(r'\s+'))
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

    final fields = [
      (item['category'] ?? '').toString().toLowerCase(),
      (item['subcategory'] ?? '').toString().toLowerCase(),
      (item['occasion'] ?? '').toString().toLowerCase(),
      (item['dominant_color'] ?? '').toString().toLowerCase(),
      (item['secondary_color'] ?? '').toString().toLowerCase(),
      attributes(item).join(' ').toLowerCase(),
      (item['storage_unit']?['name'] ?? '').toString().toLowerCase(),
      (item['storage_unit']?['type'] ?? '').toString().toLowerCase(),
    ];
    final textBlob = fields.join(' ');

    const alias = {
      'winter': ['jacket', 'coat', 'hoodie', 'sweater', 'thermal'],
      'summer': ['shorts', 'linen', 'cotton', 'sleeveless'],
      'rainy': ['raincoat', 'waterproof'],
      'monsoon': ['raincoat', 'waterproof'],
      'formal': ['office', 'business'],
      'party': ['evening', 'festival'],
    };

    for (final token in tokens) {
      if (textBlob.contains(token)) continue;
      final alternatives = alias[token];
      if (alternatives != null && alternatives.any(textBlob.contains)) continue;
      return false;
    }
    return true;
  }

  static List<String> optionsForField(List<Map<String, dynamic>> items, String field) {
    final set = <String>{'All'};
    for (final item in items) {
      final value = (item[field] ?? '').toString().trim();
      if (value.isNotEmpty) set.add(value);
    }
    return set.toList()..sort();
  }

  static List<String> tagOptions(List<Map<String, dynamic>> items) {
    final set = <String>{'All'};
    for (final item in items) {
      for (final tag in attributes(item)) {
        final clean = tag.trim();
        if (clean.isNotEmpty) set.add(clean);
      }
    }
    return set.toList()..sort();
  }

  static List<Map<String, dynamic>> filterAndSort({
    required List<Map<String, dynamic>> items,
    required String query,
    String selectedCategory = 'All',
    String selectedSubcategory = 'All',
    String selectedOccasion = 'All',
    String selectedColor = 'All',
    String selectedTag = 'All',
    bool favoritesOnly = false,
    String sortBy = 'Category (A-Z)',
  }) {
    final filtered = items.where((item) {
      if (favoritesOnly && item['is_favourite'] != true) return false;
      if (selectedCategory != 'All' &&
          (item['category'] ?? '').toString() != selectedCategory) {
        return false;
      }
      if (selectedSubcategory != 'All' &&
          (item['subcategory'] ?? '').toString() != selectedSubcategory) {
        return false;
      }
      if (selectedOccasion != 'All' &&
          (item['occasion'] ?? '').toString() != selectedOccasion) {
        return false;
      }
      if (selectedColor != 'All' &&
          (item['dominant_color'] ?? '').toString() != selectedColor) {
        return false;
      }
      if (selectedTag != 'All') {
        final attrs = attributes(item).map((e) => e.toLowerCase()).toList();
        if (!attrs.contains(selectedTag.toLowerCase())) return false;
      }
      return matchesSmartQuery(item, query);
    }).toList();

    filtered.sort((a, b) {
      if (sortBy == 'Date added (oldest)') {
        return (parseDate(a['created_at']) ?? DateTime(1970))
            .compareTo(parseDate(b['created_at']) ?? DateTime(1970));
      }
      if (sortBy == 'Date added (newest)') {
        return (parseDate(b['created_at']) ?? DateTime(1970))
            .compareTo(parseDate(a['created_at']) ?? DateTime(1970));
      }
      if (sortBy == 'Subcategory (A-Z)') {
        return (a['subcategory'] ?? '')
            .toString()
            .compareTo((b['subcategory'] ?? '').toString());
      }
      if (sortBy == 'Favorites first') {
        final af = a['is_favourite'] == true ? 1 : 0;
        final bf = b['is_favourite'] == true ? 1 : 0;
        if (af != bf) return bf.compareTo(af);
      }
      return (a['category'] ?? '')
          .toString()
          .compareTo((b['category'] ?? '').toString());
    });

    return filtered;
  }

  static Map<String, int> dominantColorCounts(List<Map<String, dynamic>> items) {
    final counts = <String, int>{};
    for (final item in items) {
      final raw = (item['dominant_color'] ?? '').toString().trim();
      if (raw.isEmpty) continue;
      final key = normalizeColor(raw);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  static String normalizeColor(String raw) {
    final clean = raw.toLowerCase();
    if (clean.contains('black')) return 'Black';
    if (clean.contains('white')) return 'White';
    if (clean.contains('blue')) return 'Blue';
    if (clean.contains('grey') || clean.contains('gray')) return 'Gray';
    if (clean.contains('green')) return 'Green';
    if (clean.contains('red')) return 'Red';
    if (clean.contains('brown')) return 'Brown';
    return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
  }
}

