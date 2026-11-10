import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/l10n.dart';
import 'logic.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

class RoseBackdrop extends StatelessWidget {
  const RoseBackdrop({super.key, required this.child, this.intensity = 0.42});

  final Widget child;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF5F8), Color(0xFFFFE8F0), Color(0xFFFFF0F5)],
            ),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: intensity,
            child: Image.asset(
              CamiAssets.roseBg,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    final content = Padding(padding: padding, child: child);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: CamiColors.rose.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            ),
            child: onTap == null
                ? content
                : InkWell(onTap: onTap, borderRadius: radius, child: content),
          ),
        ),
      ),
    );
  }
}

class RoseAvatar extends StatelessWidget {
  const RoseAvatar({super.key, this.size = 44, this.label, this.pale = false});
  final double size;
  final String? label;
  final bool pale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipOval(
            child: Image.asset(
              pale ? CamiAssets.rosePale : CamiAssets.roseFlower,
              fit: BoxFit.cover,
            ),
          ),
          if (label != null)
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: pale ? 0.55 : 0.35),
              ),
              child: Text(
                label!,
                style: TextStyle(
                  color: CamiColors.roseDeep,
                  fontWeight: FontWeight.w900,
                  fontSize: size * (pale ? 0.48 : 0.34),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RoseHeroBanner extends StatelessWidget {
  const RoseHeroBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.height = 148,
  });

  final String title;
  final String? subtitle;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(CamiAssets.roseBg, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xCCFF6B9A),
                    CamiColors.rose.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      shadows: [Shadow(color: Color(0x66000000), blurRadius: 8)],
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.label,
    this.progress,
    this.size = 220,
    this.fontSize = 48,
    this.stroke = 6,
  });

  final String label;
  final double? progress;
  final double size;
  final double fontSize;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final value = (progress ?? 1).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CountdownRingPainter(progress: value, stroke: stroke),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: CamiColors.ink,
              height: 1,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  _CountdownRingPainter({required this.progress, required this.stroke});
  final double progress;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final track = Paint()
      ..color = CamiColors.blush
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final active = Paint()
      ..color = CamiColors.roseDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.57079632679,
      6.28318530718 * progress,
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.stroke != stroke;
}

class RoseButton extends StatelessWidget {
  const RoseButton({super.key, required this.label, required this.onPressed, this.filled = true});

  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));
    if (!filled) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: CamiColors.roseDeep,
            backgroundColor: Colors.white.withValues(alpha: 0.85),
            side: const BorderSide(color: Color(0xFFFFB8D0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: child,
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: onPressed == null ? const Color(0xFFFFEAF2) : CamiColors.roseDeep,
          foregroundColor: onPressed == null ? const Color(0xFFC898A8) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: child,
      ),
    );
  }
}

class DecorBadge extends StatelessWidget {
  const DecorBadge(this.decor, {super.key, this.size = 18});
  final Decor decor;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (decor == Decor.none) return const SizedBox.shrink();
    if (decor == Decor.flower || decor == Decor.berry) {
      return ClipOval(
        child: Image.asset(CamiAssets.roseFlower, width: size, height: size, fit: BoxFit.cover),
      );
    }
    return Icon(Icons.workspace_premium, color: CamiColors.gold, size: size);
  }
}

Future<bool> askPin(BuildContext context) async {
  final store = context.read<Store>();
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x99000000),
    builder: (context) => _PinDialog(checkPin: store.checkPin),
  );
  return ok == true;
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.checkPin});
  final bool Function(String pin) checkPin;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final controller = TextEditingController();
  final focus = FocusNode();
  var wrong = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      final text = controller.text;
      if (text.length > 4) {
        controller.text = text.substring(0, 4);
        controller.selection = const TextSelection.collapsed(offset: 4);
      }
      setState(() => wrong = false);
      if (controller.text.length == 4) {
        Future.microtask(_submit);
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  void _submit() {
    if (controller.text.length != 4) return;
    if (widget.checkPin(controller.text)) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => wrong = true);
    controller.clear();
    focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final filled = controller.text.length;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: CamiColors.rose.withValues(alpha: 0.28),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.asset(CamiAssets.rosePale, width: 64, height: 64, fit: BoxFit.cover),
              ),
              const SizedBox(height: 14),
              Text(s.tr('家长密码', 'Parent PIN'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                wrong ? s.tr('密码不对，再试一次', 'Wrong PIN, try again') : s.pinNeedFour,
                style: TextStyle(
                  color: wrong ? CamiColors.red : CamiColors.muted,
                  fontWeight: wrong ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => focus.requestFocus(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 52,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: wrong ? CamiColors.redBg : CamiColors.blush,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: i == filled
                                ? CamiColors.roseDeep
                                : (wrong ? CamiColors.red : CamiColors.line),
                            width: i == filled ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          i < filled ? '●' : '',
                          style: TextStyle(
                            fontSize: 22,
                            color: wrong ? CamiColors.red : CamiColors.roseDeep,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Opacity(
                opacity: 0,
                child: SizedBox(
                  height: 1,
                  child: TextField(
                    controller: controller,
                    focusNode: focus,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: const InputDecoration(counterText: ''),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        foregroundColor: CamiColors.muted,
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: Text(context.l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: CamiColors.roseDeep,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(context.l10n.open),
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

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

String taskMeta(TaskTemplate task, [AppL10n? l10n]) {
  final s = l10n ?? AppL10n(const Locale('zh', 'CN'));
  if (task.schoolOnly) return s.schoolOnlyMeta(task.points);
  final bits = <String>[s.minutesPoints(task.minutes, task.points)];
  if (task.note.isNotEmpty) bits.add(task.note);
  if (task.englishSpecial) bits.add(s.needsRecording);
  if (task.id == 'e3' || task.title.contains('单词')) bits.add(s.vocabTag);
  return bits.join(' · ');
}
