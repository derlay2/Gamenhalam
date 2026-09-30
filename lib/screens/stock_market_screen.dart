import 'dart:math';

import 'package:flutter/material.dart';

import '../logic/game_config.dart';
import '../logic/game_state.dart';
import '../logic/stock_market.dart';
import '../models/stock.dart';
import '../widgets/visuals.dart';

extension CompanyVisuals on Company {
  IconData get icon => switch (this) {
    Company.blacksmith => Icons.hardware,
    Company.mining => Icons.landslide,
    Company.temple => Icons.church,
    Company.caravan => Icons.local_shipping,
    Company.arcane => Icons.auto_fix_high,
    Company.royalBank => Icons.account_balance,
  };

  Color get color => switch (this) {
    Company.blacksmith => Colors.deepOrange,
    Company.mining => Colors.brown,
    Company.temple => Colors.amber.shade700,
    Company.caravan => Colors.teal,
    Company.arcane => Colors.purple,
    Company.royalBank => Colors.indigo,
  };

  String get riskLabel => volatility >= 0.07
      ? 'Rủi ro cao'
      : volatility >= 0.04
      ? 'Rủi ro vừa'
      : 'An toàn';
}

Color changeColor(double change) => change > 0.0005
    ? Colors.green.shade700
    : change < -0.0005
    ? Colors.red.shade700
    : Colors.grey;

String changeText(double change) =>
    '${change >= 0 ? '▲' : '▼'} ${(change.abs() * 100).toStringAsFixed(1)}%';

class StockMarketScreen extends StatelessWidget {
  const StockMarketScreen({super.key, required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final market = game.stocks;
        return Scaffold(
          appBar: AppBar(title: Text('Sàn chứng khoán · 🪙 ${game.gold}')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            children: [
              _PortfolioCard(game: game),
              if (market.news.isNotEmpty) _NewsCard(news: market.news),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                child: Text(
                  'Bảng giá',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              for (final c in Company.values)
                _StockTile(
                  market: market,
                  company: c,
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => StockTradeSheet(game: game, company: c),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    final market = game.stocks;
    final value = market.portfolioValue;
    final profit = market.liquidationValue - market.portfolioCost;
    final text = Theme.of(context).textTheme;
    final daysToDividend =
        (GameConfig.weekDays - (game.day - 1) % GameConfig.weekDays) %
        GameConfig.weekDays;
    Widget cell(String label, String v, {Color? color}) => Expanded(
      child: Column(
        children: [
          Text(
            v,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: text.labelSmall, textAlign: TextAlign.center),
        ],
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  game.stockMarketOpen ? Icons.storefront : Icons.lock_clock,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    game.stockMarketOpen
                        ? 'Sàn đang mở cửa (sáng & trưa)'
                        : 'Sàn đóng cửa ban đêm',
                    style: text.labelLarge,
                  ),
                ),
                Text(
                  daysToDividend == 0
                      ? '💰 Cổ tức hôm nay'
                      : '💰 Cổ tức sau $daysToDividend ngày',
                  style: text.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                cell('Giá trị cổ phiếu', '$value 🪙'),
                cell(
                  'Lãi/lỗ nếu bán hết',
                  market.holdings.isEmpty
                      ? '–'
                      : '${profit >= 0 ? '+' : ''}${profit.round()}',
                  color: market.holdings.isEmpty ? null : changeColor(profit),
                ),
                cell('Vàng guild', '${game.gold}'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Giá đổi mỗi sáng theo tin tức và sự kiện tuần. Phí mỗi lệnh ${percent(GameConfig.stockFeeRate)}. '
              'Cổ phiếu tính vào tài sản thanh lý khi xét phá sản.',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.news});

  final List<StockNews> news;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📰 Tin sáng nay',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          for (final n in news)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Ticker(company: n.company),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      n.text,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    changeText(n.change),
                    style: TextStyle(
                      fontSize: 12,
                      color: changeColor(n.change),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _Ticker extends StatelessWidget {
  const _Ticker({required this.company});

  final Company company;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: company.color,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      company.ticker,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _StockTile extends StatelessWidget {
  const _StockTile({
    required this.market,
    required this.company,
    required this.onTap,
  });

  final StockMarket market;
  final Company company;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = company;
    final change = market.changeOf(c);
    final shares = market.sharesOf(c);
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: c.color.withValues(alpha: 0.15),
                child: Icon(c.icon, color: c.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Ticker(company: c),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            c.label,
                            style: text.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        c.riskLabel,
                        if (c.dividend > 0)
                          'cổ tức ${percent(c.dividend)}/tuần'
                        else
                          'không cổ tức',
                        if (shares > 0) '📦 giữ $shares',
                      ].join(' · '),
                      style: text.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 56,
                height: 28,
                child: Sparkline(
                  values: market.history[c]!,
                  color: changeColor(change),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${market.priceOf(c)} 🪙',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    changeText(change),
                    style: TextStyle(
                      fontSize: 12,
                      color: changeColor(change),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Đường giá nhỏ gọn; có thể tô nền dưới đường.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.fill = false,
  });

  final List<double> values;
  final Color color;
  final bool fill;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _SparklinePainter(values, color, fill));
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color, this.fill);

  final List<double> values;
  final Color color;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        Paint()
          ..color = color
          ..strokeWidth = 1.5,
      );
      return;
    }
    final lo = values.reduce(min);
    final hi = values.reduce(max);
    final span = max(hi - lo, 1e-6);
    Offset at(int i) => Offset(
      i / (values.length - 1) * size.width,
      size.height - (values[i] - lo) / span * size.height,
    );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    if (fill) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.12));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = fill ? 2 : 1.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}

/// Bảng chi tiết 1 mã: biểu đồ 30 ngày, thông tin, chọn số lượng và đặt lệnh.
class StockTradeSheet extends StatefulWidget {
  const StockTradeSheet({super.key, required this.game, required this.company});

  final GameState game;
  final Company company;

  @override
  State<StockTradeSheet> createState() => _StockTradeSheetState();
}

class _StockTradeSheetState extends State<StockTradeSheet> {
  var _qty = 1;

  GameState get game => widget.game;
  Company get c => widget.company;

  void _trade({required bool buy}) {
    final n = _qty;
    buy ? game.buyShares(c, n) : game.sellShares(c, n);
    setState(() => _qty = 1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${buy ? 'Đã mua' : 'Đã bán'} $n cổ phiếu ${c.ticker}.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final market = game.stocks;
        final history = market.history[c]!;
        final change = market.changeOf(c);
        final held = market.holdings[c];
        final text = Theme.of(context).textTheme;
        final maxBuy = market.maxAffordable(c, game.gold);
        final buyError = game.stockTradeError(c, _qty, buy: true);
        final sellError = game.stockTradeError(c, _qty, buy: false);
        final first = history.first;
        final periodChange = history.last / first - 1;

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: c.color,
                      child: Icon(c.icon, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.label,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${c.ticker} · ${c.riskLabel}',
                            style: text.labelMedium,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${market.priceOf(c)} 🪙',
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          changeText(change),
                          style: TextStyle(
                            color: changeColor(change),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: Sparkline(
                    values: history,
                    color: changeColor(periodChange),
                    fill: true,
                  ),
                ),
                Row(
                  children: [
                    Text('${history.length} ngày', style: text.labelSmall),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Thấp ${history.reduce(min).round()} · Cao ${history.reduce(max).round()} · '
                        '${changeText(periodChange)}',
                        style: text.labelSmall,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(c.description, style: text.bodySmall),
                const SizedBox(height: 4),
                Text(
                  c.dividend > 0
                      ? '💰 Cổ tức ${percent(c.dividend)} giá mỗi tuần '
                            '(≈ ${(market.prices[c]! * c.dividend).toStringAsFixed(1)} 🪙/cổ phiếu)'
                      : '💰 Không chia cổ tức',
                  style: text.bodySmall,
                ),
                const Divider(height: 24),
                if (held != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '📦 Đang giữ ${held.shares} cổ phiếu · giá vốn TB ${held.averageCost.toStringAsFixed(1)} · '
                      'lãi/lỗ ${_signed(market.sellProceeds(c, held.shares) - held.cost)} 🪙',
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Text('Số lượng', style: text.labelLarge),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final step in [-10, -1])
                      _StepButton(
                        label: '$step',
                        onTap: () => setState(() => _qty = max(1, _qty + step)),
                      ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '$_qty',
                        textAlign: TextAlign.center,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    for (final step in [1, 10])
                      _StepButton(
                        label: '+$step',
                        onTap: () => setState(() => _qty += step),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    ActionChip(
                      label: Text('Mua tối đa ($maxBuy)'),
                      onPressed: maxBuy > 0
                          ? () => setState(() => _qty = maxBuy)
                          : null,
                    ),
                    if (held != null)
                      ActionChip(
                        label: Text('Bán hết (${held.shares})'),
                        onPressed: () => setState(() => _qty = held.shares),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: buyError == null
                            ? () => _trade(buy: true)
                            : null,
                        child: _OrderLabel(
                          title: 'Mua',
                          amount: '-${market.buyCost(c, _qty)} 🪙',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: sellError == null
                            ? () => _trade(buy: false)
                            : null,
                        child: _OrderLabel(
                          title: 'Bán',
                          amount: '+${market.sellProceeds(c, _qty)} 🪙',
                        ),
                      ),
                    ),
                  ],
                ),
                if (!game.stockMarketOpen)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '🌙 Sàn đóng cửa ban đêm, quay lại vào sáng mai.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _signed(double v) => '${v >= 0 ? '+' : ''}${v.round()}';
}

class _OrderLabel extends StatelessWidget {
  const _OrderLabel({required this.title, required this.amount});

  final String title;
  final String amount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Text(title),
          Text(amount, style: const TextStyle(fontSize: 11)),
        ],
      ),
    ),
  );
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    ),
  );
}
