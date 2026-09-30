/// Bình máu hunter mang theo; tự uống sau trận nếu máu dưới ngưỡng nhập viện.
enum Potion {
  small('Bình máu nhỏ', healPercent: 0.25, price: 30),
  medium('Bình máu vừa', healPercent: 0.5, price: 80),
  large('Bình máu lớn', healPercent: 1.0, price: 200);

  const Potion(this.label, {required this.healPercent, required this.price});
  final String label;

  /// % máu tối đa được hồi.
  final double healPercent;
  final int price;
}
