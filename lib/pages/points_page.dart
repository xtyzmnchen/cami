import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../logic.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class PointsPage extends StatelessWidget {
  const PointsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final now = DateTime.now();
    final days = DateTime(now.year, now.month + 1, 0).day;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        RoseHeroBanner(
          title: '${store.balance}',
          subtitle: '可以用的积分 · 已得到 ${store.earned} · 已兑换 ${store.spent}',
          height: 140,
        ),
        const SizedBox(height: 14),
        GlassPanel(
          child: Row(
            children: [
              _stat('今天', '${store.pointsOn(store.todayKey)}'),
              _stat('这个月', '${monthPoints(store.data, now.year, now.month)}'),
              _stat('今年', '${yearPoints(store.data, now.year)}'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('这个月的小装饰', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var d = 1; d <= days; d++)
              _chip(store, DateTime(now.year, now.month, d)),
          ],
        ),
        const SizedBox(height: 16),
        RoseButton(
          label: '我要兑换',
          onPressed: () async {
            if (!await askPin(context) || !context.mounted) return;
            await showModalBottomSheet(context: context, builder: (_) => const _RedeemSheet());
          },
        ),
        const SizedBox(height: 16),
        const Text('已经兑换', style: TextStyle(fontWeight: FontWeight.w800)),
        for (final item in store.data.redemptions)
          GlassPanel(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Image.asset(CamiAssets.roseFlower, width: 36, height: 36),
              title: Text(item.title),
              subtitle: Text(DateFormat('M月d日 HH:mm').format(DateTime.parse(item.at))),
              trailing: Text('-${item.cost}', style: const TextStyle(color: CamiColors.roseDeep, fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: CamiColors.muted, fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _chip(Store store, DateTime day) {
    final decor = decorFor(store.data, day);
    final points = dayPoints(store.data, dayKey(day));
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CamiColors.line),
      ),
      child: Column(
        children: [
          Text('${day.day}', style: const TextStyle(fontSize: 11, color: CamiColors.muted)),
          if (decor != Decor.none)
            DecorBadge(decor, size: 18)
          else
            const SizedBox(height: 18),
          Text('$points', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RedeemSheet extends StatelessWidget {
  const _RedeemSheet();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Image.asset(CamiAssets.roseFlower, width: 40, height: 40),
            const SizedBox(width: 10),
            Text('现在有 ${store.balance} 分', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 12),
        for (final reward in store.data.rewards)
          GlassPanel(
            margin: const EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.zero,
            child: ListTile(
              title: Text(reward.title),
              trailing: FilledButton(
                onPressed: reward.cost > store.balance
                    ? null
                    : () {
                        final error = store.redeem(reward.id);
                        toast(context, error ?? '已兑换，扣掉 ${reward.cost} 分');
                        Navigator.pop(context);
                      },
                child: Text('${reward.cost} 分'),
              ),
            ),
          ),
      ],
    );
  }
}
