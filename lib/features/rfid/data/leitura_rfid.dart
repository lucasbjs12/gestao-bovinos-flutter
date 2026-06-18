class LeituraRfid {
  final int bovinoId;
  final String? antena;
  final String timestamp;
  final String? numeroBrinco;
  final String? nomeAnimal;

  const LeituraRfid({
    required this.bovinoId,
    this.antena,
    required this.timestamp,
    this.numeroBrinco,
    this.nomeAnimal,
  });

  factory LeituraRfid.fromMap(Map<String, dynamic> m) => LeituraRfid(
        bovinoId: m['bovinoId'] as int,
        antena: m['antena'] as String?,
        timestamp: m['timestamp'] as String,
        numeroBrinco: m['numeroBrinco'] as String?,
        nomeAnimal: m['nomeAnimal'] as String?,
      );
}
