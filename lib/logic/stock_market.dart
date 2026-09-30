import 'dart:math';

import '../models/events.dart';
import '../models/stock.dart';
import 'game_config.dart';

/// Sàn chứng khoán: giá mỗi mã, lịch sử giá, cổ phiếu guild đang giữ và tin tức hôm nay.
class StockMarket {
  StockMarket() {
    for (final c in Company.values) {
      prices[c] = c.basePrice;
      history[c] = [c.basePrice];
    }
  }

  factory StockMarket.fromJson(Map<String, dynamic> j) {
    final m = StockMarket();
    for (final c in Company.values) {
      if ((j['prices'] as Map<String, dynamic>)[c.name] case final num p) {
        m.prices[c] = p.toDouble();
      }
      if ((j['history'] as Map<String, dynamic>)[c.name] case final List h) {
        m.history[c] = [for (final p in h) (p as num).toDouble()];
      }
      if ((j['holdings'] as Map<String, dynamic>)[c.name]
          case final Map<String, dynamic> h) {
        m.holdings[c] = Holding.fromJson(h);
      }
    }
    m.news.addAll([
      for (final n in j['news'] as List)
        StockNews.fromJson(n as Map<String, dynamic>),
    ]);
    return m;
  }

  Map<String, dynamic> toJson() => {
    'prices': {
      for (final MapEntry(:key, :value) in prices.entries) key.name: value,
    },
    'history': {
      for (final MapEntry(:key, :value) in history.entries) key.name: value,
    },
    'holdings': {
      for (final MapEntry(:key, :value) in holdings.entries)
        if (value.shares > 0) key.name: value.toJson(),
    },
    'news': [for (final n in news) n.toJson()],
  };

  final prices = <Company, double>{};

  /// Giá đóng cửa các ngày gần nhất (mới nhất ở cuối), tối đa [GameConfig.stockHistoryDays].
  final history = <Company, List<double>>{};
  final holdings = <Company, Holding>{};
  final news = <StockNews>[];

  int sharesOf(Company c) => holdings[c]?.shares ?? 0;

  /// Giá niêm yết làm tròn (đơn vị vàng) dùng để mua bán.
  int priceOf(Company c) => max(1, prices[c]!.round());

  /// % thay đổi so với phiên trước.
  double changeOf(Company c) {
    final h = history[c]!;
    return h.length < 2 ? 0 : h.last / h[h.length - 2] - 1;
  }

  /// Phí giao dịch cho một lệnh trị giá [value].
  static int feeFor(int value) =>
      max(1, (value * GameConfig.stockFeeRate).ceil());

  /// Tổng tiền phải trả khi mua [shares] cổ phiếu (gồm phí).
  int buyCost(Company c, int shares) {
    final value = priceOf(c) * shares;
    return value + feeFor(value);
  }

  /// Tiền nhận về khi bán [shares] cổ phiếu (đã trừ phí).
  int sellProceeds(Company c, int shares) {
    if (shares <= 0) return 0;
    final value = priceOf(c) * shares;
    return max(0, value - feeFor(value));
  }

  /// Số cổ phiếu mua được tối đa với [gold].
  int maxAffordable(Company c, int gold) {
    var n = gold ~/ priceOf(c);
    while (n > 0 && buyCost(c, n) > gold) {
      n--;
    }
    return n;
  }

  /// Giá trị thị trường của toàn bộ cổ phiếu đang giữ (chưa trừ phí).
  int get portfolioValue =>
      holdings.entries.fold(0, (s, e) => s + priceOf(e.key) * e.value.shares);

  /// Tiền thu được nếu bán hết ngay (đã trừ phí) — tính vào tài sản thanh lý.
  int get liquidationValue => holdings.entries.fold(
    0,
    (s, e) => s + sellProceeds(e.key, e.value.shares),
  );

  /// Tổng vốn đã bỏ vào số cổ phiếu đang giữ.
  double get portfolioCost => holdings.values.fold(0, (s, h) => s + h.cost);

  void recordBuy(Company c, int shares, int paid) {
    final h = holdings.putIfAbsent(c, Holding.new);
    h.shares += shares;
    h.cost += paid;
  }

  void recordSell(Company c, int shares) {
    final h = holdings[c]!;
    h.cost -= h.averageCost * shares;
    h.shares -= shares;
    if (h.shares == 0) holdings.remove(c);
  }

  /// Phiên mỗi sáng: giá đi ngẫu nhiên, kéo dần về giá gốc, cộng ảnh hưởng sự kiện và tin tức bất ngờ.
  /// [gatherSuccesses]: số quest thu thập thành công hôm qua (đẩy giá mỏ).
  Map<Company, double> tick(
    Random random, {
    WeeklyEvent? event,
    required int day,
    int gatherSuccesses = 0,
  }) {
    news.clear();
    final changes = <Company, double>{};
    final active = event != null && event.activeOn(day) ? event : null;
    for (final c in Company.values) {
      final price = prices[c]!;
      final shaken = active != null && c.isShakenBy(active);
      final vol = c.volatility * (shaken ? 2 : 1);
      var logReturn =
          _gaussian(random) * vol +
          GameConfig.stockMeanReversion * log(c.basePrice / price) +
          (active == null ? 0 : c.eventDrift(active));
      if (c == Company.mining) {
        logReturn += min(gatherSuccesses, 5) * GameConfig.stockGatherBoost;
      }
      // Tin bất ngờ: tăng hoặc giảm mạnh một mã.
      if (random.nextDouble() < GameConfig.stockNewsChance) {
        final up = random.nextBool();
        final size =
            GameConfig.stockNewsMin +
            random.nextDouble() *
                (GameConfig.stockNewsMax - GameConfig.stockNewsMin);
        final shock = up ? size : -size;
        logReturn += log(1 + shock);
        final headlines = up ? _goodNews[c]! : _badNews[c]!;
        news.add(
          StockNews(
            company: c,
            text: headlines[random.nextInt(headlines.length)],
            change: shock,
          ),
        );
      }
      final next = max(GameConfig.stockMinPrice, price * exp(logReturn));
      prices[c] = next;
      final h = history[c]!..add(next);
      if (h.length > GameConfig.stockHistoryDays) h.removeAt(0);
      changes[c] = next / price - 1;
    }
    if (active != null) {
      for (final c in Company.values) {
        final drift = c.eventDrift(active);
        if (drift.abs() >= 0.02) {
          news.add(
            StockNews(
              company: c,
              text:
                  '${active.type.label}: nhà đầu tư ${drift > 0 ? 'đổ xô mua' : 'bán tháo'} ${c.ticker}',
              change: drift,
            ),
          );
        }
      }
    }
    return changes;
  }

  /// Cổ tức tuần: mỗi mã trả [Company.dividend] × giá × số cổ phiếu.
  Map<Company, int> payDividends() => {
    for (final MapEntry(key: c, value: h) in holdings.entries)
      if (c.dividend > 0 && (prices[c]! * c.dividend * h.shares).round() > 0)
        c: (prices[c]! * c.dividend * h.shares).round(),
  };

  static double _gaussian(Random random) {
    // Box–Muller.
    final u = max(1e-12, random.nextDouble());
    return sqrt(-2 * log(u)) * cos(2 * pi * random.nextDouble());
  }

  static const _goodNews = <Company, List<String>>{
    Company.blacksmith: [
      'Xưởng nhận đơn rèn giáp cho quân đội hoàng gia',
      'Phát minh lò rèn mới tiết kiệm than',
    ],
    Company.mining: [
      'Phát hiện mạch quặng lớn ở tầng sâu',
      'Mỏ ký hợp đồng cung cấp quặng dài hạn',
    ],
    Company.temple: [
      'Đền được giáo hội cấp thêm ngân sách',
      'Thánh thủy bán chạy khắp vùng',
    ],
    Company.caravan: [
      'Mở tuyến buôn mới sang nước láng giềng',
      'Chuyến hàng tơ lụa về cảng lãi lớn',
    ],
    Company.arcane: [
      'Học viện chế tạo thành công bùa phép mới',
      'Pháp sư trưởng đoạt giải thưởng hoàng gia',
    ],
    Company.royalBank: [
      'Nhà vua gửi thêm kho báu vào ngân hàng',
      'Ngân hàng tăng lãi suất tiền gửi',
    ],
  };

  static const _badNews = <Company, List<String>>{
    Company.blacksmith: [
      'Lò rèn chính bị cháy, tạm ngừng sản xuất',
      'Thợ cả bỏ sang xưởng đối thủ',
    ],
    Company.mining: [
      'Sập hầm mỏ, nhiều thợ bị thương',
      'Quặng khai thác lẫn nhiều tạp chất',
    ],
    Company.temple: [
      'Bê bối tham ô của thầy tế',
      'Thánh thủy bị phát hiện pha loãng',
    ],
    Company.caravan: [
      'Đoàn xe bị cướp giữa đường',
      'Thuế qua biên giới tăng gấp đôi',
    ],
    Company.arcane: [
      'Thí nghiệm phát nổ, một tháp học viện sụp đổ',
      'Sinh viên bỏ học hàng loạt',
    ],
    Company.royalBank: [
      'Tin đồn nhà vua vay nợ nước ngoài',
      'Kiểm toán phát hiện sổ sách sai lệch',
    ],
  };
}
