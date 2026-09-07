import 'package:flutter/material.dart';

class JenisDokumenStat {
  const JenisDokumenStat({
    required this.jenis,
    required this.icon,
    required this.count,
    required this.color,
  });

  final String jenis;
  final IconData icon;
  final int count;
  final Color color;
}

class JenisDokumenBreakdown extends StatelessWidget {
  const JenisDokumenBreakdown({
    super.key,
    required this.stats,
    this.onTapJenis,
  });

  /// Exactly the three segments to show, in display order.
  final List<JenisDokumenStat> stats;

  final ValueChanged<String>? onTapJenis;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.donut_small_rounded, size: 16, color: Colors.black45),
              const SizedBox(width: 6),
              const Text(
                'Jenis Dokumen',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i != 0)
                  Container(
                    width: 1,
                    height: 40,
                    color: const Color(0xFFEFEFEF),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                Expanded(child: _segment(stats[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _segment(JenisDokumenStat stat) {
    return InkWell(
      onTap: onTapJenis == null ? null : () => onTapJenis!(stat.jenis),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: stat.color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(stat.icon, size: 16, color: stat.color),
            ),
            const SizedBox(height: 8),
            Text(
              '${stat.count}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: stat.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              stat.jenis,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}
