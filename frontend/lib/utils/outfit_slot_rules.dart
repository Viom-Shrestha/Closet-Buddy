/// Classifies clothing items into outfit slots:
/// `outerwear | topwear | bottomwear | shoes | accessories`
///
/// Classification is keyword-based on `category + subcategory`.
/// More specific checks run before generic topwear fallback.
class OutfitSlotRules {
  static bool isShoe(Map<String, dynamic> item) => _matches(item, _shoeKeys);

  static bool isBottom(Map<String, dynamic> item) =>
      _matches(item, _bottomKeys);

  static bool isOuterwear(Map<String, dynamic> item) =>
      _matches(item, _outerwearKeys);

  static bool isAccessory(Map<String, dynamic> item) =>
      _matches(item, _accessoryKeys);

  static bool isTop(Map<String, dynamic> item) =>
      !isShoe(item) &&
      !isBottom(item) &&
      !isOuterwear(item) &&
      !isAccessory(item);

  /// Canonical slot names used by outfit UI.
  static String slotFor(Map<String, dynamic> item) {
    if (isShoe(item)) return 'shoes';
    if (isBottom(item)) return 'bottomwear';
    if (isOuterwear(item)) return 'outerwear';
    if (isAccessory(item)) return 'accessories';
    return 'topwear';
  }

  static const List<String> _shoeKeys = [
    'shoe',
    'sneaker',
    'boot',
    'heel',
    'footwear',
    'slipper',
    'sandal',
    'loafer',
    'moccasin',
    'oxford',
    'derby',
    'stiletto',
    'wedge',
    'flat shoe',
    'pump',
    'espadrille',
    'clog',
    'mule',
  ];

  static const List<String> _bottomKeys = [
    'pant',
    'trouser',
    'jean',
    'denim',
    'short',
    'skirt',
    'bottom',
    'jogger',
    'legging',
    'cargo',
    'chino',
    'slack',
    'culottes',
    'palazzo',
    'capri',
    'bermuda',
    'trackpant',
    'sweatpant',
  ];

  static const List<String> _outerwearKeys = [
    'jacket',
    'coat',
    'blazer',
    'cardigan',
    'overcoat',
    'trench',
    'windbreaker',
    'parka',
    'anorak',
    'raincoat',
    'puffer',
    'bomber',
    'fleece',
    'peacoat',
    'cape',
    'shawl',
    'poncho',
    'gilet',
    'vest outer',
    'denim jacket',
    'leather jacket',
    'sport coat',
    'suit jacket',
  ];

  static const List<String> _accessoryKeys = [
    'watch',
    'belt',
    'bag',
    'handbag',
    'purse',
    'clutch',
    'tote',
    'backpack',
    'hat',
    'cap',
    'beanie',
    'scarf',
    'glove',
    'tie',
    'bow tie',
    'pocket square',
    'sunglasses',
    'glasses',
    'jewellery',
    'jewelry',
    'necklace',
    'bracelet',
    'ring',
    'earring',
    'cufflink',
    'brooch',
    'headband',
    'hair clip',
    'sock',
    'stocking',
    'suspender',
    'lanyard',
    'accessory',
    'accessories',
  ];

  static bool _matches(Map<String, dynamic> item, List<String> keys) {
    final text = _normalized(item);
    return keys.any(text.contains);
  }

  static String _normalized(Map<String, dynamic> item) {
    final category = (item['category'] ?? '').toString().toLowerCase();
    final subcategory = (item['subcategory'] ?? '').toString().toLowerCase();
    return '$category $subcategory';
  }
}
