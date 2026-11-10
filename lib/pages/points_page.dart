import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../logic.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../l10n/l10n.dart';

class PointsPage extends StatelessWidget {
  const PointsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final now = DateTime.now();
    final days = DateTime(now.year, now.month + 1, 0).day;
    final weekdayOffset = DateTime(now.year, now.month, 1).weekday % 7; // Sun=0
    final redemptions = store.data.redemptions;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        RoseHeroBanner(
          title: '${store.balance}',
          subtitle: '${context.l10n.usablePoints} · ${context.l10n.earnedRedeemed(store.earned, store.spent)}',
          height: 148,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _StatTile(label: context.l10n.today, value: '${store.pointsOn(store.todayKey)}')),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(label: context.l10n.thisMonth, value: '${monthPoints(store.data, now.year, now.month)}')),
            const SizedBox(width: 10),
            Expanded(child: _StatTile(label: context.l10n.thisYear, value: '${yearPoints(store.data, now.year)}')),
          ],
        ),
        const SizedBox(height: 18),
        GlassPanel(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(context.l10n.monthDecor, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  Text(
                    DateFormat('M月').format(now),
                    style: const TextStyle(color: CamiColors.muted, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(context.l10n.decorHint, style: const TextStyle(color: CamiColors.muted, fontSize: 12)),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final label in context.l10n.weekdaySunFirst)
                    Expanded(
                      child: Center(
                        child: Text(label, style: const TextStyle(fontSize: 11, color: CamiColors.muted, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: weekdayOffset + days,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 0.72,
                ),
                itemBuilder: (context, index) {
                  if (index < weekdayOffset) return const SizedBox.shrink();
                  final day = index - weekdayOffset + 1;
                  return _DayCell(store: store, day: DateTime(now.year, now.month, day));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        RoseButton(
          label: context.l10n.iWantRedeem,
          onPressed: () async {
            if (!await askPin(context) || !context.mounted) return;
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: CamiColors.paper,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              builder: (_) => const _RedeemSheet(),
            );
          },
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(context.l10n.alreadyRedeemed, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            if (redemptions.isNotEmpty)
              Text(
                context.l10n.timesCount(redemptions.length),
                style: const TextStyle(color: CamiColors.muted, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (redemptions.isEmpty)
          GlassPanel(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            child: Column(
              children: [
                Image.asset(CamiAssets.roseFlower, width: 56, height: 56),
                const SizedBox(height: 12),
                Text(context.l10n.noRedeemYet, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(context.l10n.redeemHint, style: const TextStyle(color: CamiColors.muted, fontSize: 13)),
              ],
            ),
          )
        else
          _RedemptionTimeline(items: redemptions),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: CamiColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.1)),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.store, required this.day});
  final Store store;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final decor = decorFor(store.data, day);
    final points = dayPoints(store.data, dayKey(day));
    final isToday = dayKey(day) == store.todayKey;
    final hasDecor = decor != Decor.none;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: hasDecor
            ? CamiColors.blush.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday ? CamiColors.roseDeep : (hasDecor ? CamiColors.rose : CamiColors.line),
          width: isToday ? 1.6 : 1,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 10,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: isToday ? CamiColors.roseDeep : CamiColors.muted,
              ),
            ),
            const SizedBox(height: 2),
            if (hasDecor)
              DecorBadge(decor, size: 14)
            else
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: points > 0 ? CamiColors.rose.withValues(alpha: 0.55) : CamiColors.line,
                ),
              ),
            const SizedBox(height: 2),
            Text(
              points > 0 ? '$points' : '·',
              style: TextStyle(
                fontSize: 9,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: points > 0 ? CamiColors.ink : CamiColors.line,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RedemptionTimeline extends StatelessWidget {
  const _RedemptionTimeline({required this.items});
  final List<Redemption> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _RedemptionCard(item: items[i], latest: i == 0),
          if (i != items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RedemptionCard extends StatelessWidget {
  const _RedemptionCard({required this.item, required this.latest});
  final Redemption item;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final at = DateTime.tryParse(item.at);
    final when = at == null ? item.at : DateFormat('M月d日 HH:mm').format(at);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: latest
              ? [const Color(0xFFFFF7FA), const Color(0xFFFFE8F1)]
              : [Colors.white.withValues(alpha: 0.92), CamiColors.blush.withValues(alpha: 0.45)],
        ),
        border: Border.all(color: latest ? CamiColors.rose : CamiColors.line),
        boxShadow: [
          BoxShadow(
            color: CamiColors.rose.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.9),
              border: Border.all(color: CamiColors.line),
            ),
            alignment: Alignment.center,
            child: Image.asset(CamiAssets.roseFlower, width: 30, height: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.rewardTitle('', item.title),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(when, style: const TextStyle(color: CamiColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: CamiColors.line),
            ),
            child: Text(
              '-${item.cost}',
              style: const TextStyle(color: CamiColors.roseDeep, fontWeight: FontWeight.w900),
            ),
          ),
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
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: CamiColors.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(CamiAssets.roseFlower, width: 44, height: 44, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.redeemGift, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                      Text(
                        context.l10n.balanceNow(store.balance),
                        style: const TextStyle(color: CamiColors.muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: store.data.rewards.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.92,
                ),
                itemBuilder: (context, index) {
                  final reward = store.data.rewards[index];
                  final enough = reward.cost <= store.balance;
                  return _RewardCard(
                    reward: reward,
                    enough: enough,
                    shortfall: (reward.cost - store.balance).clamp(0, reward.cost),
                    onTap: enough
                        ? () {
                            final error = store.redeem(reward.id);
                            toast(context, error ?? context.l10n.redeemedDeduct(reward.cost));
                            Navigator.pop(context);
                          }
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.enough,
    required this.shortfall,
    this.onTap,
  });
  final Reward reward;
  final bool enough;
  final int shortfall;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: enough
                  ? [Colors.white, const Color(0xFFFFEAF2)]
                  : [const Color(0xFFF7F2F4), const Color(0xFFF0E8EB)],
            ),
            border: Border.all(color: enough ? CamiColors.rose : CamiColors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(CamiAssets.roseFlower, width: 26, height: 26),
                ),
                const Spacer(),
                Text(
                  context.l10n.rewardTitle(reward.id, reward.title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.25,
                    color: enough ? CamiColors.ink : CamiColors.muted,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: enough ? CamiColors.roseDeep : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: enough ? CamiColors.roseDeep : CamiColors.line),
                  ),
                  child: Text(
                    enough ? context.l10n.redeemFor(reward.cost) : context.l10n.needMorePts(shortfall),
                    style: TextStyle(
                      color: enough ? Colors.white : CamiColors.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
