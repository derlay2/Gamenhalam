import 'dart:math';

T pickWeighted<T>(List<T> items, int Function(T) weightOf, Random random) {
  final total = items.fold(0, (sum, item) => sum + weightOf(item));
  var roll = random.nextInt(total);
  for (final item in items) {
    roll -= weightOf(item);
    if (roll < 0) return item;
  }
  return items.last;
}

double randomBetween(Random random, double min, double max) => min + random.nextDouble() * (max - min);
