import 'dart:math' as math;

/// Acoustic statistics helpers.
///
/// Decibels are logarithmic, so averaging them arithmetically understates
/// the true equivalent continuous sound level. The correct average (Leq)
/// converts each dB value back to relative energy, averages the energies,
/// and converts back to dB:
///
///   Leq = 10 * log10( mean( 10^(dB/10) ) )
class NoiseStats {
  NoiseStats._();

  /// Energy-based average (Leq) of a list of dB values.
  ///
  /// Returns 0.0 for an empty list.
  static double energyMeanDb(List<double> dbValues) {
    if (dbValues.isEmpty) return 0.0;
    double energySum = 0.0;
    for (final db in dbValues) {
      energySum += math.pow(10, db / 10).toDouble();
    }
    final meanEnergy = energySum / dbValues.length;
    return 10 * (math.log(meanEnergy) / math.ln10);
  }
}
