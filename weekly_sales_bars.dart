import 'package:flutter/material.dart';
import '../theme.dart';

class DayValue {
  final String label;
  final double value;
  const DayValue(this.label, this.value);
}

/// Horizontal progress-style bars (not fl_chart) because this exact look —
/// a label, a filled track, and the value printed inside the fill — is
/// simplest as plain widgets. Swap in fl_chart's BarChart if this grows
/// into a tappable/animated chart later.
class WeeklySalesBars extends StatelessWidget {
  final List<DayValue> data;

  const WeeklySalesBars({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final maxValue = data.map((d) => d.value).fold<double>(
        0, (prev, v) => v > prev ? v : prev);

    return Column(
      children: data.map((d) {
        final fraction = maxValue == 0 ? 0.0 : (d.value / maxValue);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(d.label,
                    style: const TextStyle(color: AppColors.textPrimary)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Container(
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.progressTrack,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: 28,
                          width: constraints.maxWidth * fraction,
                          decoration: BoxDecoration(
                            color: AppColors.progressFill,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 8),
                          child: fraction > 0.25
                              ? Text(
                                  d.value.toStringAsFixed(0),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
