/// Server-provided, anonymous community percentages. No participant counts
/// are exposed in this DTO or in the Campus Pulse user interface.
class CommunityPulse {
  const CommunityPulse({required this.percent100, required this.percent90,
    required this.percent50, required this.period, required this.asOf});

  final int percent100;
  final int percent90;
  final int percent50;
  final String period;
  final DateTime asOf;

  factory CommunityPulse.fromJson(Map<String, dynamic> json, String period) {
    int percentage(String key) {
      final number = json[key];
      if (number is! num || !number.isFinite || number < 0 || number > 100) {
        throw FormatException('Invalid community percentage: $key');
      }
      return number.round();
    }
    final p100 = percentage('percent_100');
    final p90 = percentage('percent_90');
    final p50 = percentage('percent_50');
    if (p100 > p90 || p90 > p50) {
      throw const FormatException('Inconsistent community achievement thresholds');
    }
    final stamp = DateTime.tryParse((json['as_of'] ?? '').toString());
    if (stamp == null) throw const FormatException('Missing community update time');
    if (json['period'] != period) throw const FormatException('Unexpected community period');
    return CommunityPulse(percent100: p100, percent90: p90,
      percent50: p50, period: period, asOf: stamp);
  }
}
