part of admin_screen;

class _AdminTabMeta {
  final IconData icon;
  final String label;
  const _AdminTabMeta(this.icon, this.label);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section label
// ─────────────────────────────────────────────────────────────────────────────

class _AdminSectionLabel extends StatelessWidget {
  final String text;
  const _AdminSectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 3,
        height: 12,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: kAdminAccent,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: kAdminTextMuted,
          letterSpacing: 1.8,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  KPI ticker card (horizontal scroll row)
// ─────────────────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    this.delta,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 110,
    margin: const EdgeInsets.only(right: 10),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: kAdminSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: color.withOpacity(0.8),
            letterSpacing: 1.2,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: -1.0,
            height: 1,
          ),
        ),
        if (delta != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: kAdminGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              delta!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: kAdminGreen,
              ),
            ),
          )
        else
          const SizedBox(height: 16),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Engagement gauge (arc progress)
// ─────────────────────────────────────────────────────────────────────────────

class _EngagementGauge extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final Color color;

  const _EngagementGauge({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (value / max).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CustomPaint(
              painter: _ArcPainter(progress: pct, color: color),
              child: Center(
                child: Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: kAdminTextMuted,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _ArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const startAngle = 3.14159 * 0.75;
    const sweepFull = 3.14159 * 1.5;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepFull,
      false,
      Paint()
        ..color = color.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Fill
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepFull * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Stat pill (sessions / avg session)
// ─────────────────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
    decoration: BoxDecoration(
      color: kAdminSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kAdminBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: kAdminTextMuted,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Slot ring chart (donut using CustomPaint)
// ─────────────────────────────────────────────────────────────────────────────

class _SlotDatum {
  final String label;
  final double value;
  final Color color;
  const _SlotDatum(this.label, this.value, this.color);
}

class _SlotRingChart extends StatelessWidget {
  final List<_SlotDatum> data;
  const _SlotRingChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.fold<double>(0, (s, d) => s + d.value);
    final avg = data.isEmpty ? 0.0 : total / data.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        children: [
          const Text(
            'SLOT COVERAGE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: kAdminTextMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: CustomPaint(
              painter: _DonutPainter(data: data, total: total),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'AVG',
                      style: TextStyle(
                        fontSize: 9,
                        color: kAdminTextDim,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      avg == 0 ? '—' : '${avg.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: kAdminText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Legend
          ...data.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: d.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    d.label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: kAdminTextMuted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${d.value.toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: d.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<_SlotDatum> data;
  final double total;
  const _DonutPainter({required this.data, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 6;
    var start = -3.14159 / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    // Background ring
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * 3.14159,
      false,
      paint..color = kAdminSurface2,
    );

    for (final d in data) {
      final sweep = total == 0 ? 0.0 : (d.value / total) * 2 * 3.14159;
      if (sweep <= 0) continue;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep - 0.06,
        false,
        paint..color = d.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Rating meter (horizontal fill bar)
// ─────────────────────────────────────────────────────────────────────────────

class _RatingMeter extends StatelessWidget {
  final double rating;
  final double max;

  const _RatingMeter({required this.rating, required this.max});

  @override
  Widget build(BuildContext context) {
    final pct = max == 0 ? 0.0 : (rating / max).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AVG RATING',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: kAdminTextMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                rating == 0 ? '—' : rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: kAdminYellow,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                ' / 5',
                style: TextStyle(fontSize: 12, color: kAdminTextDim),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: kAdminSurface2,
              valueColor: const AlwaysStoppedAnimation(kAdminYellow),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('0', style: TextStyle(fontSize: 9, color: kAdminTextDim)),
              Text('5', style: TextStyle(fontSize: 9, color: kAdminTextDim)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Stat block 2 (icon + value)
// ─────────────────────────────────────────────────────────────────────────────

class _StatBlock2 extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBlock2({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: kAdminSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kAdminBorder),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: kAdminTextMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Horizontal bar chart (categories)
// ─────────────────────────────────────────────────────────────────────────────

class _HorizontalBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String labelKey;
  final String valueKey;
  final Color color;

  const _HorizontalBarChart({
    required this.rows,
    required this.labelKey,
    required this.valueKey,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox(
        height: 60,
        child: Center(
          child: Text('No data', style: TextStyle(color: kAdminTextDim)),
        ),
      );
    }

    final nums = rows.map((r) {
      final v = r[valueKey];
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }).toList();
    final maxVal = nums.isEmpty ? 1.0 : nums.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _HBarRow(
              label: rows[i][labelKey]?.toString() ?? '—',
              value: nums[i],
              maxValue: maxVal,
              color: color,
              rank: i,
            ),
            if (i < rows.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _HBarRow extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final int rank;

  const _HBarRow({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final pct = maxValue == 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    final alpha = (1.0 - rank * 0.12).clamp(0.4, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kAdminText,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Stack(
            children: [
              // Track
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: kAdminSurface2,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Fill
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color.withOpacity(alpha),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 32,
          child: Text(
            value.toInt().toString(),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Color swatch chart
// ─────────────────────────────────────────────────────────────────────────────

class _ColorSwatchChart extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _ColorSwatchChart({required this.rows});

  static const _colorMap = <String, Color>{
    'red': Color(0xFFEF4444),
    'blue': Color(0xFF3B82F6),
    'green': Color(0xFF22C55E),
    'yellow': Color(0xFFFACC15),
    'orange': Color(0xFFF97316),
    'purple': Color(0xFFA855F7),
    'pink': Color(0xFFEC4899),
    'brown': Color(0xFF92400E),
    'black': Color(0xFF6B7280),
    'white': Color(0xFFD1D5DB),
    'grey': Color(0xFF9CA3AF),
    'gray': Color(0xFF9CA3AF),
    'beige': Color(0xFFD4B896),
    'navy': Color(0xFF1E3A8A),
    'teal': Color(0xFF14B8A6),
    'maroon': Color(0xFF9B1C1C),
    'cream': Color(0xFFD4C5A9),
    'khaki': Color(0xFFC2B280),
    'indigo': Color(0xFF6366F1),
  };

  Color _resolve(String name) {
    final n = name.toLowerCase();
    for (final e in _colorMap.entries) {
      if (n.contains(e.key)) return e.value;
    }
    return const Color(0xFF68687A);
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final nums = rows.map((r) {
      final v = r['total'] ?? r['count'];
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }).toList();
    final maxVal = nums.isEmpty ? 1.0 : nums.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _ColorBarRow(
              label: rows[i]['dominant_color']?.toString() ?? '—',
              value: nums[i],
              maxValue: maxVal,
              swatch: _resolve(rows[i]['dominant_color']?.toString() ?? ''),
            ),
            if (i < rows.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ColorBarRow extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color swatch;

  const _ColorBarRow({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.swatch,
  });

  @override
  Widget build(BuildContext context) {
    final pct = maxValue == 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: swatch,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: swatch.withOpacity(0.5),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kAdminText,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: kAdminSurface2,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: swatch.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 28,
          child: Text(
            value.toInt().toString(),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: swatch,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Recent user row
// ─────────────────────────────────────────────────────────────────────────────

class _RecentUserRow extends StatelessWidget {
  final Map<String, dynamic> user;
  const _RecentUserRow({required this.user});

  String _initial(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty ? '?' : s[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Container(
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
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: kAdminAccent.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _initial(user['username']?.toString()),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: kAdminAccent,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user['username']?.toString() ?? '—',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kAdminText,
                ),
              ),
              Text(
                user['email']?.toString() ?? '',
                style: const TextStyle(fontSize: 11, color: kAdminTextMuted),
              ),
            ],
          ),
        ),
        if (user['date_joined'] != null)
          Text(
            _fmt(user['date_joined'].toString()),
            style: const TextStyle(fontSize: 10, color: kAdminTextDim),
          ),
      ],
    ),
  );

  String _fmt(String raw) {
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    const mo = [
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
    return '${mo[dt.month - 1]} ${dt.day}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Search bar
// ─────────────────────────────────────────────────────────────────────────────

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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: kAdminSurface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAdminBorder),
            ),
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 13, color: kAdminText),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 13, color: kAdminTextDim),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: kAdminTextDim,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
              onSubmitted: (_) => onSearch(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onSearch,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kAdminAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAdminAccent.withOpacity(0.3)),
            ),
            child: const Text(
              'Search',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kAdminAccent,
              ),
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  User card
// ─────────────────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final Function(Map<String, dynamic>) onDetail;
  final Function(Map<String, dynamic>) onActivate;
  final Function(Map<String, dynamic>) onStaff;
  final Function(Map<String, dynamic>) onReset;

  const _UserCard({
    required this.user,
    required this.onDetail,
    required this.onActivate,
    required this.onStaff,
    required this.onReset,
  });

  String _initial(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty ? '?' : s[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = user['is_active'] == true;
    final isStaff = user['is_staff'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
                // Avatar
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isActive
                        ? kAdminAccent.withOpacity(0.15)
                        : kAdminSurface2,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive
                          ? kAdminAccent.withOpacity(0.3)
                          : kAdminBorder,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _initial(user['username']?.toString()),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isActive ? kAdminAccent : kAdminTextDim,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            user['username']?.toString() ?? '—',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: kAdminText,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (isStaff)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: kAdminAccent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'admin',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: kAdminAccent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user['email']?.toString() ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          color: kAdminTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? kAdminGreen : kAdminRedDim,
                    shape: BoxShape.circle,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: kAdminGreen.withOpacity(0.5),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: kAdminBorder,
            margin: const EdgeInsets.symmetric(horizontal: 14),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
              children: [
                _UserAction(
                  label: 'View',
                  icon: Icons.open_in_new_rounded,
                  onTap: () => onDetail(user),
                ),
                _UserAction(
                  label: isActive ? 'Deactivate' : 'Activate',
                  icon: isActive
                      ? Icons.block_rounded
                      : Icons.check_circle_outline_rounded,
                  color: isActive ? kAdminRed : kAdminGreen,
                  onTap: () => onActivate(user),
                ),
                _UserAction(
                  label: isStaff ? 'Remove admin' : 'Make admin',
                  icon: Icons.admin_panel_settings_outlined,
                  color: isStaff ? kAdminTextMuted : kAdminAccent,
                  onTap: () => onStaff(user),
                ),
                _UserAction(
                  label: 'Reset pwd',
                  icon: Icons.lock_reset_rounded,
                  onTap: () => onReset(user),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _UserAction({
    required this.label,
    required this.icon,
    this.color = kAdminTextMuted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Catalog item card
// ─────────────────────────────────────────────────────────────────────────────

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

  String _img(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http')) return s;
    return '${ApiClient.host}$s';
  }

  @override
  Widget build(BuildContext context) {
    final imgUrl = _img(item['image']);
    final cat = item['category']?.toString() ?? '—';
    final sub = item['subcategory']?.toString() ?? '';
    final user = item['user']?.toString() ?? '—';
    final color = item['dominant_color']?.toString() ?? '';

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? kAdminAccent.withOpacity(0.08) : kAdminSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kAdminAccent.withOpacity(0.4) : kAdminBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: selected ? kAdminAccent : kAdminSurface2,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? kAdminAccent : kAdminBorder,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 10,
                      color: Colors.black,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            // Thumbnail
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: kAdminSurface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imgUrl.isEmpty
                    ? const Icon(
                        Icons.broken_image_outlined,
                        size: 20,
                        color: kAdminTextDim,
                      )
                    : Image.network(imgUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [cat, if (sub.isNotEmpty) sub].join(' · '),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kAdminText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [if (color.isNotEmpty) color, 'User: $user'].join(' · '),
                    style: const TextStyle(
                      fontSize: 11,
                      color: kAdminTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: kAdminRedDim,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 15,
                    color: kAdminRed,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Outfit grid card (dense layout)
// ─────────────────────────────────────────────────────────────────────────────

class _OutfitGridCard extends StatelessWidget {
  final Map<String, dynamic> outfit;
  const _OutfitGridCard({required this.outfit});

  String _img(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http')) return s;
    if (s.startsWith('/')) return '${ApiClient.host}$s';
    return '${ApiClient.host}/$s';
  }

  String _itemLabel(Map<String, dynamic>? item) {
    if (item == null) return '—';
    final sub = (item['subcategory'] ?? '').toString();
    final cat = (item['category'] ?? '').toString();
    final label = sub.isNotEmpty ? sub : cat;
    return label.isEmpty ? '—' : label;
  }

  @override
  Widget build(BuildContext context) {
    final name = (outfit['name'] ?? 'Outfit').toString();
    final rating = outfit['rating']?.toString() ?? '—';
    final wears = (outfit['wear_count'] ?? 0).toString();
    final occasion = (outfit['occasion'] ?? '').toString();
    final isFav = outfit['is_favourite'] == true;
    final userMap = outfit['user'] is Map
        ? Map<String, dynamic>.from(outfit['user'] as Map)
        : null;
    final username = (userMap?['username'] ?? outfit['user'] ?? '—').toString();

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

    final slotPreview = [
      _SlotPreviewRow(
        icon: Icons.layers_outlined,
        label: 'Outer',
        value: _itemLabel(outerwear),
        color: kAdminYellow,
        imageUrl: _img(outerwear?['image']),
      ),
      _SlotPreviewRow(
        icon: Icons.checkroom_outlined,
        label: 'Top',
        value: _itemLabel(topwear),
        color: kAdminAccent,
        imageUrl: _img(topwear?['image']),
      ),
      _SlotPreviewRow(
        icon: Icons.straighten_rounded,
        label: 'Bottom',
        value: _itemLabel(bottomwear),
        color: kAdminBlue,
        imageUrl: _img(bottomwear?['image']),
      ),
      _SlotPreviewRow(
        icon: Icons.directions_walk_outlined,
        label: 'Shoes',
        value: _itemLabel(shoes),
        color: kAdminGreen,
        imageUrl: _img(shoes?['image']),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kAdminText,
                  ),
                ),
              ),
              if (isFav)
                const Icon(Icons.favorite_rounded, color: kAdminRed, size: 14),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '@$username',
                style: const TextStyle(fontSize: 10, color: kAdminTextMuted),
              ),
              const Spacer(),
              const Icon(Icons.star_rounded, size: 11, color: kAdminYellow),
              const SizedBox(width: 2),
              Text(
                rating,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kAdminYellow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (occasion.isNotEmpty)
                _SmallBadge(occasion, bg: kAdminAccentDim, fg: kAdminAccent),
              if (occasion.isNotEmpty) const SizedBox(width: 6),
              _SmallBadge(
                '$wears wears',
                bg: kAdminSurface2,
                fg: kAdminTextDim,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: slotPreview[0]),
              const SizedBox(width: 8),
              Expanded(child: slotPreview[1]),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: slotPreview[2]),
              const SizedBox(width: 8),
              Expanded(child: slotPreview[3]),
            ],
          ),
        ],
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
    this.bg = kAdminSurface2,
    this.fg = kAdminTextDim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SlotPreviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String imageUrl;

  const _SlotPreviewRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(icon, size: 14, color: color),
                  )
                : Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: kAdminText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Feedback card
// ─────────────────────────────────────────────────────────────────────────────

class _FeedbackCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Function(bool)? onToggleRead;

  const _FeedbackCard({required this.item, this.onToggleRead});

  @override
  Widget build(BuildContext context) {
    final isRead = item['is_read'] == true;
    final message = item['message']?.toString() ?? '';
    final user = item['user']?.toString() ?? '—';
    final rating = item['rating'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead ? kAdminBorder : kAdminAccent.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                if (!isRead)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: kAdminAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  'User: $user',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kAdminText,
                  ),
                ),
                const Spacer(),
                if (rating != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 12,
                        color: kAdminYellow,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$rating',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kAdminYellow,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onToggleRead == null
                      ? null
                      : () => onToggleRead!(!isRead),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isRead
                          ? kAdminSurface2
                          : kAdminAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isRead ? 'Read' : 'Unread',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isRead ? kAdminTextDim : kAdminAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Container(
            height: 1,
            color: kAdminBorder,
            margin: const EdgeInsets.symmetric(horizontal: 14),
          ),
          // Message
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: isRead ? kAdminTextMuted : kAdminText,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Invite row
// ─────────────────────────────────────────────────────────────────────────────

class _InviteRow extends StatelessWidget {
  final Map<String, dynamic> invite;
  final VoidCallback? onDelete;
  const _InviteRow({required this.invite, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final email = invite['email']?.toString() ?? '—';
    final isUsed = invite['is_used'] == true;

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
          const Icon(
            Icons.alternate_email_rounded,
            size: 16,
            color: kAdminTextDim,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              email,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kAdminText,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isUsed ? kAdminGreen.withOpacity(0.1) : kAdminSurface2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isUsed ? 'Used' : 'Pending',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isUsed ? kAdminGreen : kAdminTextDim,
              ),
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: kAdminRedDim,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 14,
                  color: kAdminRed,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared buttons / inputs
// ─────────────────────────────────────────────────────────────────────────────

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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: compact ? 40 : 48,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 18)
          : const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kAdminAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        border: Border.all(color: kAdminAccent.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: kAdminAccent,
        ),
      ),
    ),
  );
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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: highlight ? kAdminAccent.withOpacity(0.15) : kAdminSurface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? kAdminAccent.withOpacity(0.35) : kAdminBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: highlight ? kAdminAccent : kAdminTextMuted,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: highlight ? kAdminAccent : kAdminTextMuted,
            ),
          ),
        ],
      ),
    ),
  );
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType keyboardType;

  const _DarkTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    style: const TextStyle(fontSize: 14, color: kAdminText),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}
