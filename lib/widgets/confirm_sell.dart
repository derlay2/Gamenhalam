import 'package:flutter/material.dart';

/// Hỏi lại trước khi guild bán thanh lý hàng tồn.
Future<bool> confirmSell(BuildContext context, String what, int price) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Bán thanh lý?'),
      content: Text('Bán $what cho thương lái, guild nhận $price 🪙.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Huỷ')),
        FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Bán')),
      ],
    ),
  );
  return ok ?? false;
}
