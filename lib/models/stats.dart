class Stats {
  const Stats({this.power = 0, this.maxHp = 0, this.physRes = 0, this.magicRes = 0, this.agility = 0});

  static const zero = Stats();

  factory Stats.fromJson(Map<String, dynamic> j) => Stats(
    power: (j['power'] as num).toDouble(),
    maxHp: (j['maxHp'] as num).toDouble(),
    physRes: (j['physRes'] as num).toDouble(),
    magicRes: (j['magicRes'] as num).toDouble(),
    // Bản lưu cũ dùng né tránh (0..1): quy đổi 1% né ≈ 1 nhanh nhẹn.
    agility: ((j['agility'] ?? (j['evasion'] as num) * 100) as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'power': power,
    'maxHp': maxHp,
    'physRes': physRes,
    'magicRes': magicRes,
    'agility': agility,
  };

  final double power;
  final double maxHp;
  final double physRes;
  final double magicRes;

  /// Nhanh nhẹn: quyết định thứ tự ra đòn và tỉ lệ né tránh (xem GameConfig.evasionFromAgility).
  final double agility;

  Stats operator +(Stats o) => Stats(
    power: power + o.power,
    maxHp: maxHp + o.maxHp,
    physRes: physRes + o.physRes,
    magicRes: magicRes + o.magicRes,
    agility: agility + o.agility,
  );

  Stats operator *(double k) =>
      Stats(power: power * k, maxHp: maxHp * k, physRes: physRes * k, magicRes: magicRes * k, agility: agility * k);
}
