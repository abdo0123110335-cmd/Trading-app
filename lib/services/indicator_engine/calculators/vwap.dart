/// Session VWAP: cumulative sum of (typicalPrice * volume) / cumulative
/// volume, reset at every UTC day boundary (the common convention — VWAP
/// is a session indicator, not a rolling one, otherwise it stops being
/// meaningful for intraday mean-reversion reads).
List<double?> vwap(
  List<double> highs,
  List<double> lows,
  List<double> closes,
  List<double> volumes,
  List<DateTime> openTimes,
) {
  final n = highs.length;
  final out = List<double?>.filled(n, null);
  double cumPv = 0;
  double cumVol = 0;
  DateTime? currentDay;

  for (var i = 0; i < n; i++) {
    final day = DateTime.utc(openTimes[i].year, openTimes[i].month, openTimes[i].day);
    if (currentDay == null || day != currentDay) {
      currentDay = day;
      cumPv = 0;
      cumVol = 0;
    }
    final typical = (highs[i] + lows[i] + closes[i]) / 3;
    cumPv += typical * volumes[i];
    cumVol += volumes[i];
    out[i] = cumVol == 0 ? null : cumPv / cumVol;
  }
  return out;
}
