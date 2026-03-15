import 'package:flutter/material.dart';
import '../services/clothing_service.dart';
import '../services/api_client.dart';

class ClothingDetailScreen extends StatefulWidget {
  final int clothingId;

  const ClothingDetailScreen({super.key, required this.clothingId});

  @override
  State<ClothingDetailScreen> createState() => _ClothingDetailScreenState();
}

class _ClothingDetailScreenState extends State<ClothingDetailScreen> {
  final ClothingService clothingService = ClothingService();

  Map<String, dynamic>? item;
  bool loading = true;
  bool hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  Future<void> _loadItem() async {
    final data = await clothingService.getById(widget.clothingId);
    if (mounted) {
      setState(() {
        item = data;
        loading = false;
      });
    }
  }

  String _img(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    if (s.startsWith('http')) return s;
    return '${ApiClient.host}$s';
  }

  // ---------------- FAVORITE ----------------

  Future<void> _toggleFavourite() async {
    final old = item!['is_favourite'] ?? false;

    setState(() => item!['is_favourite'] = !old);

    final ok = await clothingService.toggleFavourite(item!['id']);

    if (!ok && mounted) {
      setState(() => item!['is_favourite'] = old);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Failed to update favourite"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    hasChanges = true;
  }

  // ---------------- DELETE ----------------

  Future<void> _delete() async {
    final confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Clothing?"),
        content: const Text(
          "This action cannot be undone. Are you sure you want to delete this item?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await clothingService.deleteClothing(item!['id']);

    if (ok && mounted) {
      Navigator.pop(context, true);
    }
  }

  // ---------------- EDIT ----------------

  Future<void> _edit() async {
    final c = TextEditingController(text: item!['category']);
    final sc = TextEditingController(text: item!['subcategory']);
    final dc = TextEditingController(text: item!['dominant_color']);
    final sec = TextEditingController(text: item!['secondary_color']);
    final occ = TextEditingController(text: item!['occasion']);
    final attrs = TextEditingController(
      text: _attributesFromItem().join(', '),
    );

    final save = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Edit Details",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _field("Category", c, Icons.category),
            _field("Subcategory", sc, Icons.style),
            _field("Primary Color", dc, Icons.palette),
            _field("Secondary Color", sec, Icons.color_lens),
            _field("Occasion", occ, Icons.event),
            _field(
              "Attributes (comma separated)",
              attrs,
              Icons.tune,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Save Changes",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (save != true) return;

    final payload = {
      "category": c.text,
      "subcategory": sc.text,
      "dominant_color": dc.text,
      "secondary_color": sec.text,
      "occasion": occ.text,
      "attributes": _splitAttributes(attrs.text),
    };

    final ok = await clothingService.updateClothing(item!['id'], payload);

    if (ok && mounted) {
      setState(() => item!.addAll(payload));
      hasChanges = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Changes saved successfully"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _field(String label, TextEditingController c, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, hasChanges);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: CustomScrollView(
          slivers: [
            // Modern App Bar with Image Header
            SliverAppBar(
              expandedHeight: 400,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.pop(context, hasChanges),
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      item!['is_favourite'] == true
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: Colors.red,
                    ),
                    onPressed: _toggleFavourite,
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: Colors.white,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Hero(
                        tag: 'clothing_${item!['id']}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            _img(item!['image']),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Content
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Details Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Details",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _detailRow(
                              Icons.category,
                              "Category",
                              item!['category'],
                            ),
                            _detailRow(
                              Icons.style,
                              "Subcategory",
                              item!['subcategory'],
                            ),
                            _detailRow(
                              Icons.palette,
                              "Primary Color",
                              item!['dominant_color'],
                              showColorDot: true,
                            ),
                            _detailRow(
                              Icons.color_lens,
                              "Secondary Color",
                              item!['secondary_color'],
                              showColorDot: true,
                            ),
                            _detailRow(
                              Icons.event,
                              "Occasion",
                              item!['occasion'],
                            ),
                            _detailRow(
                              Icons.calendar_today_outlined,
                              "Date Added",
                              _formatDate(item!['created_at']),
                            ),
                            _attributesSection(),
                            const SizedBox(height: 8),
                            _descriptionSection(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _edit,
                              icon: const Icon(Icons.edit),
                              label: const Text("Edit"),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _delete,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text("Delete"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    dynamic val, {
    bool showColorDot = false,
    bool isLast = false,
  }) {
    final value = val?.toString() ?? "-";

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (showColorDot && value != "-") ...[
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _getColorFromName(value),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorFromName(String colorName) {
    final name = colorName.toLowerCase();
    final colorMap = {
      'red': Colors.red,
      'blue': Colors.blue,
      'green': Colors.green,
      'yellow': Colors.yellow,
      'orange': Colors.orange,
      'purple': Colors.purple,
      'pink': Colors.pink,
      'brown': Colors.brown,
      'black': Colors.black,
      'white': Colors.white,
      'grey': Colors.grey,
      'gray': Colors.grey,
      'beige': const Color(0xFFF5F5DC),
      'navy': const Color(0xFF000080),
      'maroon': const Color(0xFF800000),
      'olive': const Color(0xFF808000),
      'teal': Colors.teal,
      'cyan': Colors.cyan,
      'lime': Colors.lime,
      'indigo': Colors.indigo,
    };

    for (var entry in colorMap.entries) {
      if (name.contains(entry.key)) {
        return entry.value;
      }
    }

    return Colors.grey.shade400;
  }

  List<String> _attributesFromItem() {
    final raw = item?['attributes'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  List<String> _splitAttributes(String value) {
    return value
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return "-";
    final dt = DateTime.tryParse(raw.toString())?.toLocal();
    if (dt == null) return "-";
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _generatedDescription() {
    final category = (item?['category'] ?? '').toString();
    final subcategory = (item?['subcategory'] ?? '').toString();
    final dominant = (item?['dominant_color'] ?? '').toString();
    final secondary = (item?['secondary_color'] ?? '').toString();
    final occasion = (item?['occasion'] ?? '').toString();
    final attrs = _attributesFromItem();

    final parts = <String>[];
    if (category.isNotEmpty || subcategory.isNotEmpty) {
      parts.add([category, subcategory].where((e) => e.isNotEmpty).join(' - '));
    }
    if (dominant.isNotEmpty) {
      parts.add('Primary color: $dominant');
    }
    if (secondary.isNotEmpty) {
      parts.add('Secondary color: $secondary');
    }
    if (occasion.isNotEmpty) {
      parts.add('Occasion: $occasion');
    }
    if (attrs.isNotEmpty) {
      parts.add('Attributes: ${attrs.join(', ')}');
    }

    if (parts.isEmpty) return 'No description available.';
    return parts.join('. ');
  }

  Widget _attributesSection() {
    final attrs = _attributesFromItem();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.tune, size: 20, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attributes',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                if (attrs.isEmpty)
                  const Text(
                    '-',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: attrs
                        .map(
                          (a) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              a,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _descriptionSection() {
    return Container(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.description_outlined, size: 20, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _generatedDescription(),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

