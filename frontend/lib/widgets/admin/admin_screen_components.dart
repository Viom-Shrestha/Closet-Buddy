part of admin_screen;


class _AdminTopBar extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback onRefresh;
  final TabController tabCtrl;
  final List<AdminTabMeta> tabs;

  const _AdminTopBar({
    this.onBack,
    required this.onRefresh,
    required this.tabCtrl,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kAdminSurface,
        border: Border(bottom: BorderSide(color: kAdminBorder)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: kAdminTextMuted,
                      tooltip: 'Back',
                    )
                  else
                    const SizedBox(width: 40, height: 40),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: kAdminAccentDim,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: kAdminAccent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Admin Console',
                        style: TextStyle(
                          color: kAdminText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Manage platform health',
                        style: TextStyle(
                          color: kAdminTextDim,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _ActionChip(
                    label: 'Refresh',
                    icon: Icons.refresh_rounded,
                    onTap: onRefresh,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TabBar(
                  controller: tabCtrl,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicator: BoxDecoration(
                    color: kAdminAccentDim,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: kAdminAccent.withOpacity(0.4)),
                  ),
                  indicatorPadding: const EdgeInsets.symmetric(vertical: 6),
                  labelColor: kAdminAccent,
                  unselectedLabelColor: kAdminTextMuted,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(fontSize: 12),
                  dividerColor: Colors.transparent,
                  tabs: tabs
                      .map(
                        (t) => Tab(
                          height: 38,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(t.icon, size: 15),
                                const SizedBox(width: 6),
                                Text(t.label),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final List<Widget> children;

  const _MetricGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final cols = c.maxWidth > 500 ? 3 : 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map(
                (w) => SizedBox(
                  width: (c.maxWidth - (cols - 1) * 10) / cols,
                  child: w,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _BigMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _BigMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 24,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: kAdminText,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(color: kAdminTextMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool delta;

  const _SmallMetric({
    required this.label,
    required this.value,
    this.delta = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: delta ? kAdminGreenDim : kAdminSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: delta ? kAdminGreen.withOpacity(0.25) : kAdminBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: delta ? kAdminGreen : kAdminText,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(color: kAdminTextMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (delta)
            const Icon(Icons.trending_up_rounded, color: kAdminGreen, size: 18),
        ],
      ),
    );
  }
}

class _EngagementCard extends StatelessWidget {
  final String label;
  final String value;
  final String subLabel;
  final IconData icon;
  final Color color;

  const _EngagementCard({
    required this.label,
    required this.value,
    required this.subLabel,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value.trim().isEmpty ? '-' : value;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            displayValue,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subLabel,
            style: const TextStyle(color: kAdminTextDim, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatBlock({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: kAdminTextMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(color: color.withOpacity(0.6), fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String labelKey;
  final Color color;

  const _BarChart({
    required this.rows,
    required this.labelKey,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kAdminSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kAdminBorder),
        ),
        child: const Text(
          'No data yet',
          style: TextStyle(color: kAdminTextDim),
        ),
      );
    }

    final maxVal = rows
        .map((r) => (r['total'] as num?)?.toDouble() ?? 0)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        children: rows.map((row) {
          final label = (row[labelKey] ?? 'Unknown').toString();
          final val = (row['total'] as num?)?.toDouble() ?? 0;
          final frac = val / maxVal;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(color: kAdminText, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${val.toInt()}',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: kAdminSurface2,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: frac.clamp(0.0, 1.0),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ColorBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> rows;

  const _ColorBarChart({required this.rows});

  static const _colorMap = <String, Color>{
    'black': Color(0xFF555555),
    'white': Color(0xFFDDDDDD),
    'grey': Color(0xFF888888),
    'gray': Color(0xFF888888),
    'navy': Color(0xFF2C3E6B),
    'blue': Color(0xFF3B8BD4),
    'red': Color(0xFFE05252),
    'green': Color(0xFF4CAF7D),
    'olive': Color(0xFF7A8C5A),
    'brown': Color(0xFF8B6347),
    'tan': Color(0xFFC9A96E),
    'beige': Color(0xFFD4B896),
    'pink': Color(0xFFE8A0B0),
    'purple': Color(0xFF7B5EA7),
    'yellow': Color(0xFFE8C547),
    'orange': Color(0xFFE8843C),
  };

  Color _resolve(String name) {
    for (final entry in _colorMap.entries) {
      if (name.toLowerCase().contains(entry.key)) return entry.value;
    }
    return kAdminTextDim;
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kAdminSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kAdminBorder),
        ),
        child: const Text(
          'No data yet',
          style: TextStyle(color: kAdminTextDim),
        ),
      );
    }

    final maxVal = rows
        .map((r) => (r['total'] as num?)?.toDouble() ?? 0)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        children: rows.map((row) {
          final colorName = (row['dominant_color'] ?? 'unknown').toString();
          final val = (row['total'] as num?)?.toDouble() ?? 0;
          final frac = val / maxVal;
          final barColor = _resolve(colorName);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: barColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: kAdminBorder, width: 0.5),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: Text(
                    colorName,
                    style: const TextStyle(color: kAdminText, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: kAdminSurface2,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: frac.clamp(0.0, 1.0),
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${val.toInt()}',
                  style: const TextStyle(
                    color: kAdminTextMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RecentUserRow extends StatelessWidget {
  final Map<String, dynamic> user;

  const _RecentUserRow({required this.user});

  @override
  Widget build(BuildContext context) {
    final username = (user['username'] ?? 'User').toString();
    final email = (user['email'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAdminBorder),
      ),
      child: Row(
        children: [
          _Avatar(name: username),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    color: kAdminText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  email,
                  style: const TextStyle(color: kAdminTextMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          _SmallBadge('C ${user['clothing_count'] ?? 0}'),
          const SizedBox(width: 6),
          _SmallBadge('O ${user['outfit_count'] ?? 0}'),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final void Function(Map<String, dynamic>) onDetail;
  final void Function(Map<String, dynamic>) onActivate;
  final void Function(Map<String, dynamic>) onStaff;
  final void Function(Map<String, dynamic>) onReset;

  const _UserCard({
    required this.user,
    required this.onDetail,
    required this.onActivate,
    required this.onStaff,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final username = (user['username'] ?? 'User').toString();
    final email = (user['email'] ?? '').toString();
    final isStaff = user['is_staff'] == true;
    final isActive = user['is_active'] == true;
    final canEdit = user['can_edit'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _Avatar(name: username, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              color: kAdminText,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isStaff)
                            _SmallBadge(
                              'Admin',
                              bg: kAdminAccentDim,
                              fg: kAdminAccent,
                            ),
                          const SizedBox(width: 4),
                          _SmallBadge(
                            isActive ? 'Active' : 'Inactive',
                            bg: isActive ? kAdminGreenDim : kAdminRedDim,
                            fg: isActive ? kAdminGreen : kAdminRed,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: const TextStyle(
                          color: kAdminTextMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Joined ${_shortDate((user['date_joined'] ?? '').toString())}'
                        ' - Active ${_shortDate((user['last_active_at'] ?? '').toString())}',
                        style: const TextStyle(
                          color: kAdminTextDim,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: kAdminBorder),
                bottom: BorderSide(color: kAdminBorder),
              ),
            ),
            child: Row(
              children: [
                _CountChip(
                  label: 'Clothing',
                  value: '${user['clothing_count'] ?? 0}',
                ),
                _CountChip(
                  label: 'Accessories',
                  value: '${user['accessory_count'] ?? 0}',
                ),
                _CountChip(
                  label: 'Outfits',
                  value: '${user['outfit_count'] ?? 0}',
                ),
                _CountChip(
                  label: 'Storages',
                  value: '${user['storage_count'] ?? 0}',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionChip(
                  label: 'Details',
                  icon: Icons.open_in_new_rounded,
                  onTap: () => onDetail(user),
                ),
                if (canEdit) ...[
                  _ActionChip(
                    label: isActive ? 'Deactivate' : 'Activate',
                    icon: isActive
                        ? Icons.block_rounded
                        : Icons.check_circle_outline_rounded,
                    onTap: () => onActivate(user),
                    color: isActive ? kAdminRed : kAdminGreen,
                  ),
                  _ActionChip(
                    label: isStaff ? 'Remove admin' : 'Make admin',
                    icon: isStaff
                        ? Icons.person_remove_rounded
                        : Icons.admin_panel_settings_rounded,
                    onTap: () => onStaff(user),
                    color: kAdminAccent,
                  ),
                  _ActionChip(
                    label: 'Reset password',
                    icon: Icons.lock_reset_rounded,
                    onTap: () => onReset(user),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _shortDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '-';
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _CatalogItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool selected;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  const _CatalogItemCard({
    required this.item,
    required this.selected,
    this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final image = (item['image'] ?? '').toString();
    final user = item['user'] is Map
        ? Map<String, dynamic>.from(item['user'] as Map)
        : <String, dynamic>{};

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? kAdminAccentDim : kAdminSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kAdminAccent.withOpacity(0.5) : kAdminBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kAdminSurface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kAdminBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: image.isEmpty
                  ? const Icon(
                      Icons.checkroom_rounded,
                      color: kAdminTextDim,
                      size: 22,
                    )
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: kAdminTextDim,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item['subcategory'] ?? item['category'] ?? 'Item')
                        .toString(),
                    style: const TextStyle(
                      color: kAdminText,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item['category'] ?? ''} - @${user['username'] ?? '?'}',
                    style: const TextStyle(
                      color: kAdminTextMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: kAdminAccent,
                size: 18,
              ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: kAdminTextDim,
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutfitRow extends StatelessWidget {
  final Map<String, dynamic> outfit;

  const _OutfitRow({required this.outfit});

  @override
  Widget build(BuildContext context) {
    final user = outfit['user'] is Map
        ? Map<String, dynamic>.from(outfit['user'] as Map)
        : <String, dynamic>{};
    final isFav = outfit['is_favourite'] == true;
    final outerwear = outfit['outerwear_item'] is Map
        ? Map<String, dynamic>.from(outfit['outerwear_item'] as Map)
        : null;
    final topwear = outfit['topwear_item'] is Map
        ? Map<String, dynamic>.from(outfit['topwear_item'] as Map)
        : null;
    final bottomwear = outfit['bottomwear_item'] is Map
        ? Map<String, dynamic>.from(outfit['bottomwear_item'] as Map)
        : null;
    final shoes = outfit['shoes_item'] is Map
        ? Map<String, dynamic>.from(outfit['shoes_item'] as Map)
        : null;
    final accessories = outfit['accessory_items'] is List
        ? (outfit['accessory_items'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAdminBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: OutfitCanvas(
              outerwear: outerwear,
              topwear: topwear,
              bottomwear: bottomwear,
              shoes: shoes,
              accessories: accessories,
              compact: true,
              slotScale: 0.95,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (outfit['name'] ?? 'Outfit').toString(),
                  style: const TextStyle(
                    color: kAdminText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'by @${user['username'] ?? '?'}',
                  style: const TextStyle(color: kAdminTextMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (isFav)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.favorite_rounded, color: kAdminRed, size: 14),
            ),
          if (outfit['rating'] != null)
            Row(
              children: [
                const Icon(Icons.star_rounded, color: kAdminAccent, size: 13),
                const SizedBox(width: 2),
                Text(
                  outfit['rating'].toString(),
                  style: const TextStyle(
                    color: kAdminAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final void Function(bool)? onToggleRead;

  const _FeedbackCard({required this.item, this.onToggleRead});

  @override
  Widget build(BuildContext context) {
    final user = item['user'] is Map
        ? Map<String, dynamic>.from(item['user'] as Map)
        : <String, dynamic>{};
    final isRead = item['is_read'] == true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead ? kAdminSurface : kAdminSurface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead ? kAdminBorder : kAdminAccent.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(name: (user['username'] ?? 'U').toString(), size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (user['username'] ?? 'User').toString(),
                      style: const TextStyle(
                        color: kAdminText,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _shortDate((item['created_at'] ?? '').toString()),
                      style: const TextStyle(
                        color: kAdminTextDim,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    isRead ? 'Read' : 'Unread',
                    style: TextStyle(
                      fontSize: 11,
                      color: isRead ? kAdminTextDim : kAdminAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: isRead,
                    onChanged: onToggleRead,
                    activeColor: kAdminAccent,
                    inactiveThumbColor: kAdminTextDim,
                    inactiveTrackColor: kAdminSurface2,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            (item['message'] ?? '').toString(),
            style: const TextStyle(
              color: kAdminText,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _shortDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '-';
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _InviteRow extends StatelessWidget {
  final Map<String, dynamic> invite;
  final VoidCallback? onDelete;

  const _InviteRow({required this.invite, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAdminBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kAdminBlueDim,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.alternate_email_rounded,
              color: kAdminBlue,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (invite['email'] ?? '').toString(),
                  style: const TextStyle(
                    color: kAdminText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Added ${_shortDate((invite['created_at'] ?? '').toString())}',
                  style: const TextStyle(color: kAdminTextDim, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            color: kAdminTextDim,
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  String _shortDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '-';
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final double size;

  const _Avatar({required this.name, this.size = 36});

  static const _palette = [
    Color(0xFF2C3E6B),
    Color(0xFF4CAF7D),
    Color(0xFFC9A96E),
    Color(0xFF5B8FD4),
    Color(0xFFE05252),
    Color(0xFF7B5EA7),
  ];

  @override
  Widget build(BuildContext context) {
    final safeName = name.isEmpty ? '?' : name;
    final initial = safeName[0].toUpperCase();
    final color = _palette[safeName.codeUnitAt(0) % _palette.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: color,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _SmallBadge(
    this.text, {
    this.bg = const Color(0xFF242424),
    this.fg = const Color(0xFF8A8580),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final String value;

  const _CountChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: kAdminText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(color: kAdminTextDim, fontSize: 9),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const _ActionChip({
    required this.label,
    required this.icon,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fg = color ?? kAdminTextMuted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color != null ? color!.withOpacity(0.1) : kAdminSurface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color != null ? color!.withOpacity(0.3) : kAdminBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? badge;

  const _SectionLabel({required this.label, this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: kAdminTextDim,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: kAdminGreenDim,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                color: kAdminGreen,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onSearch;
  final Widget? trailing;

  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onSearch,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              style: const TextStyle(color: kAdminText, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: kAdminTextDim,
                  size: 18,
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
              ).copyWith(hintText: hint),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          const SizedBox(width: 8),
          _DarkButton(label: 'Search', onTap: onSearch, compact: true),
        ],
      ),
    );
  }
}

class _DarkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool compact;

  const _DarkButton({
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 20,
          vertical: compact ? 10 : 14,
        ),
        decoration: BoxDecoration(
          color: kAdminAccent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0F0F0F),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DarkChipButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;

  const _DarkChipButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: highlight ? kAdminAccentDim : kAdminSurface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlight ? kAdminAccent.withOpacity(0.4) : kAdminBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: highlight ? kAdminAccent : kAdminTextMuted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: highlight ? kAdminAccent : kAdminTextMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;

  const _DarkTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: kAdminText, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 12,
        ),
      ),
    );
  }
}

class AdminTabMeta {
  final IconData icon;
  final String label;

  const AdminTabMeta(this.icon, this.label);
}
