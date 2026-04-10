part of '../../features/admin/screens/admin_screen.dart';

class _AdminTabMeta {
  final IconData icon;
  final String label;
  const _AdminTabMeta(this.icon, this.label);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section label
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
    final pctStr = '${(pct * 100).toStringAsFixed(0)}%';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: kAdminTextMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: CustomPaint(
                  painter: _ArcPainter(progress: pct, color: color),
                  child: Center(
                    child: Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pctStr,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Text(
                    'of active',
                    style: TextStyle(fontSize: 9, color: kAdminTextDim),
                  ),
                ],
              ),
            ],
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
        ..color = color.withValues(alpha: 0.12)
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
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: kAdminSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: kAdminBorder),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: kAdminText,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: kAdminTextMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Slot coverage chart (individual gauges — each value is % of users)
// ─────────────────────────────────────────────────────────────────────────────

class _SlotDatum {
  final String label;
  final double value; // 0–100 percentage of users who have this slot filled
  final Color color;
  const _SlotDatum(this.label, this.value, this.color);
}

class _SlotRingChart extends StatelessWidget {
  final List<_SlotDatum> data;
  const _SlotRingChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 2),
          const Text(
            '% of users with items in each slot',
            style: TextStyle(fontSize: 9, color: kAdminTextDim),
          ),
          const SizedBox(height: 14),
          ...data.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: d.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        d.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kAdminText,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${d.value.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: d.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (d.value / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: kAdminSurface2,
                      valueColor: AlwaysStoppedAnimation(d.color),
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

// ─────────────────────────────────────────────────────────────────────────────
//  _RatingMeter (unused — kept for potential future use)
// ─────────────────────────────────────────────────────────────────────────────

// ignore: unused_element
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
//  _StatBlock2 (unused — kept for potential future use)
// ─────────────────────────────────────────────────────────────────────────────

// ignore: unused_element
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
            color: color.withValues(alpha: 0.12),
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
                    color: color.withValues(alpha: alpha),
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
//  Color pie chart
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
    'burgundy': Color(0xFF9B1C1C),
    'olive': Color(0xFF84894A),
    'turquoise': Color(0xFF06B6D4),
    'lavender': Color(0xFFA78BFA),
    'mustard': Color(0xFFEAB308),
    'blush': Color(0xFFFCA5A5),
    'coral': Color(0xFFF97316),
    'sage': Color(0xFF86EFAC),
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

    final labels = rows
        .map((r) => (r['dominant_color'] ?? '—').toString())
        .toList();
    final nums = rows.map((r) {
      final v = r['total'] ?? r['count'];
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }).toList();
    final total = nums.fold(0.0, (a, b) => a + b);
    final colors = labels.map(_resolve).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        children: [
          // Pie chart
          SizedBox(
            width: 160,
            height: 160,
            child: CustomPaint(
              painter: _PiePainter(values: nums, colors: colors, total: total),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(labels.length, (i) {
              final pct = total == 0 ? 0.0 : nums[i] / total * 100;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[i],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${labels[i]} ${pct.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: kAdminTextMuted,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double total;
  const _PiePainter({
    required this.values,
    required this.colors,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    var startAngle = -3.14159 / 2;
    const gap = 0.03;

    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < values.length; i++) {
      if (total == 0 || values[i] == 0) continue;
      final sweep = (values[i] / total) * 2 * 3.14159 - gap;
      paint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        true,
        paint,
      );
      startAngle += sweep + gap;
    }

    // Centre hole
    canvas.drawCircle(center, radius * 0.42, Paint()..color = kAdminSurface);
  }

  @override
  bool shouldRepaint(_PiePainter old) =>
      old.values != values || old.total != total;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Outfits-per-day line chart (7 days)
// ─────────────────────────────────────────────────────────────────────────────

class _OutfitsPerDayChart extends StatelessWidget {
  final List<Map<String, dynamic>> rows; // [{date, count}]
  const _OutfitsPerDayChart({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final counts = rows.map((r) {
      final v = r['count'];
      return (v is num)
          ? v.toDouble()
          : double.tryParse(v?.toString() ?? '') ?? 0.0;
    }).toList();

    final labels = rows.map((r) {
      final raw = r['date']?.toString() ?? '';
      final dt = DateTime.tryParse(raw);
      if (dt == null) return raw;
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    }).toList();

    final total = counts.fold(0.0, (a, b) => a + b).toInt();
    final peak = counts.fold(0.0, (a, b) => a > b ? a : b).toInt();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OUTFITS CREATED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: kAdminTextMuted,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Last 7 days',
                      style: TextStyle(fontSize: 10, color: kAdminTextDim),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$total',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: kAdminText,
                      letterSpacing: -0.5,
                      height: 1,
                    ),
                  ),
                  Text(
                    'peak $peak/day',
                    style: const TextStyle(fontSize: 9, color: kAdminTextDim),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: CustomPaint(
              size: Size.infinite,
              painter: _LineChartPainter(
                values: counts,
                lineColor: kAdminAccent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Day labels
          Row(
            children: List.generate(labels.length, (i) {
              final isToday = i == labels.length - 1;
              return Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                    color: isToday ? kAdminAccent : kAdminTextDim,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  const _LineChartPainter({required this.values, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final maxVal = values.fold(0.0, (a, b) => a > b ? a : b);
    final effectiveMax = maxVal == 0 ? 1.0 : maxVal;

    // ── grid lines ──────────────────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (int g = 0; g <= 3; g++) {
      final y = size.height * (1 - g / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // ── compute points ───────────────────────────────────────────────────────
    final n = values.length;
    final points = List.generate(n, (i) {
      final x = i / (n - 1) * size.width;
      final y = size.height * (1 - (values[i] / effectiveMax).clamp(0, 1));
      return Offset(x, y);
    });

    // ── filled area ──────────────────────────────────────────────────────────
    final fillPath = Path()..moveTo(0, size.height);
    for (final pt in points) {
      fillPath.lineTo(pt.dx, pt.dy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.18),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // ── line ─────────────────────────────────────────────────────────────────
    final linePath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      // cubic bezier for smooth curve
      final prev = points[i - 1];
      final curr = points[i];
      final cpX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(cpX, prev.dy, cpX, curr.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // ── dots ─────────────────────────────────────────────────────────────────
    for (int i = 0; i < points.length; i++) {
      final isToday = i == points.length - 1;
      // white fill
      canvas.drawCircle(
        points[i],
        isToday ? 5.0 : 3.5,
        Paint()..color = const Color(0xFF1A1A2E),
      );
      // colored ring
      canvas.drawCircle(
        points[i],
        isToday ? 5.0 : 3.5,
        Paint()
          ..color = lineColor.withValues(alpha: isToday ? 1.0 : 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isToday ? 2.5 : 1.8,
      );
      if (isToday) {
        canvas.drawCircle(points[i], 2.0, Paint()..color = lineColor);
      }
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => old.values != values;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Storage types breakdown
// ─────────────────────────────────────────────────────────────────────────────

class _StorageTypesChart extends StatelessWidget {
  final List<Map<String, dynamic>> rows; // [{type, total}]
  const _StorageTypesChart({required this.rows});

  static const _iconMap = <String, IconData>{
    'closet': Icons.door_sliding_outlined,
    'wardrobe': Icons.door_back_door_outlined,
    'cupboard': Icons.shelves,
    'shelf': Icons.shelves,
    'drawer': Icons.table_rows_outlined,
    'box': Icons.inbox_outlined,
    'other': Icons.inventory_2_outlined,
  };

  static const _colorList = [
    kAdminBlue,
    kAdminAccent,
    kAdminGreen,
    kAdminYellow,
    kAdminRed,
    kAdminTextMuted,
    kAdminTextDim,
  ];

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final nums = rows.map((r) {
      final v = r['total'];
      return (v is num)
          ? v.toDouble()
          : double.tryParse(v?.toString() ?? '') ?? 0.0;
    }).toList();
    final maxVal = nums.fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STORAGE TYPES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: kAdminTextMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(rows.length, (i) {
            final label = (rows[i]['type'] ?? '—').toString();
            final normalizedLabel = label.trim();
            final titleLabel = normalizedLabel.isEmpty
                ? '—'
                : normalizedLabel[0].toUpperCase() +
                      normalizedLabel.substring(1);
            final icon =
                _iconMap[normalizedLabel.toLowerCase()] ??
                Icons.inventory_2_outlined;
            final color = _colorList[i % _colorList.length];
            final frac = maxVal == 0 ? 0.0 : (nums[i] / maxVal).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 62,
                    child: Text(
                      titleLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kAdminText,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 6,
                        backgroundColor: kAdminSurface2,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    nums[i].toInt().toString(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
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

  String _avatarUrl(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('/')) return '${ApiClient.host}$s';
    return '${ApiClient.host}/$s';
  }

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

  @override
  Widget build(BuildContext context) {
    final isActive = user['is_active'] == true;
    final clothing = user['clothing_count'] ?? 0;
    final outfits = user['outfit_count'] ?? 0;
    final avatarInitial = _initial(user['username']?.toString());
    final avatarUrl = _avatarUrl(user['avatar']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminBorder),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kAdminAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: Text(
                          avatarInitial,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: kAdminAccent,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        avatarInitial,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kAdminAccent,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user['username']?.toString() ?? '—',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kAdminText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? kAdminGreen.withValues(alpha: 0.12)
                            : kAdminTextDim.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isActive ? kAdminGreen : kAdminTextDim,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      user['email']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 10,
                        color: kAdminTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Counts + date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (user['date_joined'] != null)
                Text(
                  _fmt(user['date_joined'].toString()),
                  style: const TextStyle(fontSize: 10, color: kAdminTextDim),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.checkroom_outlined,
                    size: 10,
                    color: kAdminTextDim,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$clothing',
                    style: const TextStyle(
                      fontSize: 10,
                      color: kAdminTextMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.style_outlined,
                    size: 10,
                    color: kAdminTextDim,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$outfits',
                    style: const TextStyle(
                      fontSize: 10,
                      color: kAdminTextMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
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
              color: kAdminAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAdminAccent.withValues(alpha: 0.3)),
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

  String _avatarUrl(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('/')) return '${ApiClient.host}$s';
    return '${ApiClient.host}/$s';
  }

  @override
  Widget build(BuildContext context) {
    final isActive = user['is_active'] == true;
    final isStaff = user['is_staff'] == true;
    final avatarInitial = _initial(user['username']?.toString());
    final avatarUrl = _avatarUrl(user['avatar']);

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
                        ? kAdminAccent.withValues(alpha: 0.15)
                        : kAdminSurface2,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive
                          ? kAdminAccent.withValues(alpha: 0.3)
                          : kAdminBorder,
                    ),
                  ),
                  child: ClipOval(
                    child: avatarUrl.isNotEmpty
                        ? Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: Text(
                                avatarInitial,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isActive
                                      ? kAdminAccent
                                      : kAdminTextDim,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              avatarInitial,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isActive ? kAdminAccent : kAdminTextDim,
                              ),
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
                                color: kAdminAccent.withValues(alpha: 0.12),
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
                              color: kAdminGreen.withValues(alpha: 0.5),
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
                  label: 'Reset password',
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
          color: color.withValues(alpha: 0.08),
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
          color: selected
              ? kAdminAccent.withValues(alpha: 0.08)
              : kAdminSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? kAdminAccent.withValues(alpha: 0.4)
                : kAdminBorder,
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
                      color: kAdminBlack,
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
  final VoidCallback? onDelete;
  const _OutfitGridCard({required this.outfit, this.onDelete});

  String _img(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http')) return s;
    if (s.startsWith('/')) return '${ApiClient.host}$s';
    return '${ApiClient.host}/$s';
  }

  @override
  Widget build(BuildContext context) {
    final name = (outfit['name'] ?? 'Outfit').toString();
    final rating = outfit['rating']?.toString() ?? '—';
    final wears = (outfit['wear_count'] ?? 0);
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

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kAdminSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slot images — 2×2 grid fills most of the card
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _SlotThumb(
                            item: outerwear,
                            icon: Icons.layers_outlined,
                            color: kAdminYellow,
                            label: 'Outer',
                            imgFn: _img,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: _SlotThumb(
                            item: topwear,
                            icon: Icons.checkroom_outlined,
                            color: kAdminAccent,
                            label: 'Top',
                            imgFn: _img,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _SlotThumb(
                            item: bottomwear,
                            icon: Icons.straighten_rounded,
                            color: kAdminBlue,
                            label: 'Bottom',
                            imgFn: _img,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: _SlotThumb(
                            item: shoes,
                            icon: Icons.directions_walk_outlined,
                            color: kAdminGreen,
                            label: 'Shoes',
                            imgFn: _img,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Name + fav + delete
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kAdminText,
                  ),
                ),
              ),
              if (isFav) ...[
                const SizedBox(width: 4),
                const Icon(Icons.favorite_rounded, color: kAdminRed, size: 12),
              ],
              if (onDelete != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: kAdminRedDim,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 12,
                      color: kAdminRed,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          // User + occasion + rating
          Row(
            children: [
              Text(
                '@$username',
                style: const TextStyle(fontSize: 9, color: kAdminTextMuted),
              ),
              const Spacer(),
              if (occasion.isNotEmpty) ...[
                _SmallBadge(occasion, bg: kAdminAccentDim, fg: kAdminAccent),
                const SizedBox(width: 4),
              ],
              _SmallBadge('${wears}x', bg: kAdminSurface2, fg: kAdminTextDim),
              const SizedBox(width: 4),
              const Icon(Icons.star_rounded, size: 10, color: kAdminYellow),
              const SizedBox(width: 2),
              Text(
                rating,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: kAdminYellow,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotThumb extends StatelessWidget {
  final Map<String, dynamic>? item;
  final IconData icon;
  final Color color;
  final String label;
  final String Function(dynamic) imgFn;

  const _SlotThumb({
    required this.item,
    required this.icon,
    required this.color,
    required this.label,
    required this.imgFn,
  });

  @override
  Widget build(BuildContext context) {
    final imgUrl = imgFn(item?['image']);
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: color.withValues(alpha: 0.08),
          child: imgUrl.isNotEmpty
              ? Image.network(
                  imgUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      Center(child: Icon(icon, size: 18, color: color)),
                )
              : Center(child: Icon(icon, size: 18, color: color)),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black45,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
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
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600),
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
          color: isRead ? kAdminBorder : kAdminAccent.withValues(alpha: 0.3),
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
                          : kAdminAccent.withValues(alpha: 0.12),
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
// ─────────────────────────────────────────────────────────────────────────────

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
        color: kAdminAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        border: Border.all(color: kAdminAccent.withValues(alpha: 0.3)),
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
        color: highlight
            ? kAdminAccent.withValues(alpha: 0.15)
            : kAdminSurface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? kAdminAccent.withValues(alpha: 0.35)
              : kAdminBorder,
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

  const _DarkTextField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    style: const TextStyle(fontSize: 14, color: kAdminText),
    decoration: InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Dropdown with predefined options (category / subcategory)
// ─────────────────────────────────────────────────────────────────────────────

class _DarkDropdown extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final List<String> options;

  const _DarkDropdown({
    required this.controller,
    required this.label,
    required this.options,
  });

  @override
  State<_DarkDropdown> createState() => _DarkDropdownState();
}

class _DarkDropdownState extends State<_DarkDropdown> {
  String? _selected;

  static const _kAny = 'Any';

  @override
  void initState() {
    super.initState();
    final v = widget.controller.text.trim();
    _selected = v.isEmpty ? null : v;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: _selected,
      isExpanded: true,
      style: const TextStyle(fontSize: 14, color: kAdminText),
      dropdownColor: kAdminSurface,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(fontSize: 13, color: kAdminTextMuted),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kAdminBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kAdminAccent),
        ),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text(
            _kAny,
            style: TextStyle(fontSize: 13, color: kAdminTextDim),
          ),
        ),
        ...widget.options.map(
          (opt) => DropdownMenuItem<String?>(
            value: opt,
            child: Text(opt, style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
      onChanged: (v) {
        setState(() => _selected = v);
        widget.controller.text = v ?? '';
      },
    );
  }
}
