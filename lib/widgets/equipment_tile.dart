import 'package:flutter/material.dart';

import '../models/equipment.dart';
import 'visuals.dart';

class EquipmentTile extends StatelessWidget {
  const EquipmentTile({super.key, required this.item, this.onTap});

  final Equipment item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = item.type;
    final q = item.quality;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: item.grade.color.withValues(alpha: 0.2),
          foregroundColor: item.grade.color,
          child: Icon(type.icon),
        ),
        title: Text(
          item.name,
          style: TextStyle(color: item.grade.color, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${type.slot.label}${type.twoHanded ? ' (2 tay)' : ''} · Lv ≥ ${item.grade.minLevel} · '
          '${type.classes.map((c) => c.label).join(', ')}\n'
          '${describeStats(item.bonus)}\n'
          '${describeDurability(item)}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${item.price} 🪙'),
            Text(
              'CL ${(q * 100).round()}%',
              style: TextStyle(fontSize: 12, color: q >= 1.1 ? Colors.green : (q < 0.9 ? Colors.red : null)),
            ),
          ],
        ),
      ),
    );
  }
}
