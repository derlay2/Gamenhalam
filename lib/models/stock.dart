import 'events.dart';

/// Công ty niêm yết trên sàn chứng khoán của thị trấn.
/// [volatility]: độ lệch chuẩn biến động giá mỗi ngày; [dividend]: cổ tức mỗi tuần theo % giá.
enum Company {
  blacksmith(
    'Xưởng Rèn Sắt Đỏ',
    'RSD',
    basePrice: 40,
    volatility: 0.04,
    dividend: 0.015,
    description:
        'Rèn vũ khí cho cả vùng. Làm ăn phát đạt khi chiến tranh, quái vật công thành.',
  ),
  mining(
    'Mỏ Đá Xám',
    'MDX',
    basePrice: 25,
    volatility: 0.06,
    dividend: 0.01,
    description:
        'Khai thác quặng. Hưởng lợi khi giá nguyên liệu tăng và khi guild làm nhiều quest thu thập; '
        'sợ thời tiết xấu.',
  ),
  temple(
    'Đền Ánh Sáng',
    'DAS',
    basePrice: 60,
    volatility: 0.025,
    dividend: 0.02,
    description:
        'Chữa bệnh, bán thánh thủy. Cổ phiếu phòng thủ, bùng nổ khi có dịch bệnh.',
  ),
  caravan(
    'Thương Đoàn Gió Bắc',
    'TGB',
    basePrice: 35,
    volatility: 0.05,
    dividend: 0.015,
    description:
        'Buôn bán đường dài. Lên khi có thương nhân lạ và dân nhập cư, xuống khi bão tuyết hay dịch bệnh.',
  ),
  arcane(
    'Học Viện Ma Pháp',
    'HVM',
    basePrice: 80,
    volatility: 0.09,
    dividend: 0,
    description:
        'Nghiên cứu phép thuật. Không chia cổ tức, giá lên xuống thất thường, '
        'đặc biệt nhạy với các thí nghiệm cấm.',
  ),
  royalBank(
    'Ngân Hàng Hoàng Gia',
    'NHH',
    basePrice: 120,
    volatility: 0.015,
    dividend: 0.025,
    description:
        'Ngân hàng của nhà vua. Ổn định, cổ tức đều; phụ thuộc quan hệ giữa thị trấn và vương quốc.',
  );

  const Company(
    this.label,
    this.ticker, {
    required this.basePrice,
    required this.volatility,
    required this.dividend,
    required this.description,
  });

  final String label;
  final String ticker;
  final double basePrice;
  final double volatility;
  final double dividend;
  final String description;

  /// Ảnh hưởng của sự kiện tuần lên giá mỗi ngày sự kiện còn hiệu lực (+0.03 = +3%/ngày).
  double eventDrift(WeeklyEvent event) => switch ((this, event.type)) {
    (Company.blacksmith, WeeklyEventType.siege) => 0.03,
    (Company.royalBank, WeeklyEventType.siege) => -0.01,
    (Company.temple, WeeklyEventType.plague) => 0.04,
    (Company.caravan, WeeklyEventType.plague) => -0.02,
    (Company.mining, WeeklyEventType.plague) => -0.015,
    (Company.caravan, WeeklyEventType.weather) => -0.03,
    (Company.mining, WeeklyEventType.weather) => -0.03,
    (Company.mining, WeeklyEventType.inflation) => 0.04,
    (_, WeeklyEventType.inflation) => 0.015,
    (Company.royalBank, WeeklyEventType.rumor) => -0.015,
    (_, WeeklyEventType.rumor) => -0.02,
    (Company.caravan, WeeklyEventType.merchant) => 0.02,
    (
      Company.caravan || Company.royalBank || Company.blacksmith,
      WeeklyEventType.immigration,
    ) =>
      0.01,
    (Company.royalBank, WeeklyEventType.royalAid) => switch (event.choice) {
      true => 0.03,
      false => -0.025,
      null => 0,
    },
    (Company.arcane, WeeklyEventType.experiment) => switch (event.choice) {
      true => 0.05,
      false => -0.03,
      null => 0,
    },
    (Company.temple, WeeklyEventType.traitor) => -0.01,
    _ => 0,
  };

  /// Sự kiện làm cổ phiếu này biến động mạnh gấp đôi.
  bool isShakenBy(WeeklyEvent event) =>
      (this == Company.arcane &&
          event.type == WeeklyEventType.experiment &&
          event.choice == true) ||
      event.type == WeeklyEventType.rumor;
}

/// Cổ phiếu guild đang nắm giữ.
class Holding {
  Holding({this.shares = 0, this.cost = 0});

  factory Holding.fromJson(Map<String, dynamic> j) =>
      Holding(shares: j['shares'] as int, cost: (j['cost'] as num).toDouble());

  Map<String, dynamic> toJson() => {'shares': shares, 'cost': cost};

  int shares;

  /// Tổng tiền vốn (gồm phí) của số cổ phiếu đang giữ.
  double cost;

  double get averageCost => shares == 0 ? 0 : cost / shares;
}

/// Tin tức sàn trong ngày.
class StockNews {
  const StockNews({
    required this.company,
    required this.text,
    required this.change,
  });

  factory StockNews.fromJson(Map<String, dynamic> j) => StockNews(
    company: Company.values.byName(j['company'] as String),
    text: j['text'] as String,
    change: (j['change'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'company': company.name,
    'text': text,
    'change': change,
  };

  final Company company;
  final String text;

  /// % thay đổi giá do tin này (0.12 = +12%).
  final double change;
}

/// Kết quả phiên sáng: tin tức, biến động và cổ tức (nếu hôm nay trả).
class StockDayReport {
  const StockDayReport({
    required this.changes,
    required this.news,
    this.dividends = const {},
  });

  /// % thay đổi giá từng mã so với hôm qua.
  final Map<Company, double> changes;
  final List<StockNews> news;

  /// Cổ tức guild nhận theo từng mã.
  final Map<Company, int> dividends;

  int get dividendTotal => dividends.values.fold(0, (a, b) => a + b);

  /// Mã tăng / giảm mạnh nhất.
  MapEntry<Company, double> get topGainer =>
      changes.entries.reduce((a, b) => a.value >= b.value ? a : b);
  MapEntry<Company, double> get topLoser =>
      changes.entries.reduce((a, b) => a.value <= b.value ? a : b);
}
