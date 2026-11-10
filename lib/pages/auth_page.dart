import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../store.dart';
import '../sync_qr.dart';
import '../theme.dart';
import '../widgets.dart';
import 'server_scan_page.dart';
import '../l10n/l10n.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  final server = TextEditingController();
  final token = TextEditingController(text: 'cami-home');
  final phone = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final age = TextEditingController();
  final interests = TextEditingController();

  var step = 0; // 0 地址+手机 1 登录 2 注册
  var busy = false;
  var obscure = true;
  var showAdvanced = false;
  String? error;
  String grade = '二年级';
  final interestChips = ['画画', '阅读', '运动', '音乐', '乐高', '英语'];
  final selectedInterests = <String>{};

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    final store = context.read<Store>();
    server.text = store.serverUrl;
    token.text = store.serverToken;
    showAdvanced = store.serverUrl.isEmpty;
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    server.dispose();
    token.dispose();
    phone.dispose();
    password.dispose();
    name.dispose();
    age.dispose();
    interests.dispose();
    super.dispose();
  }

  String get _subtitle => switch (step) {
        1 => context.l10n.welcomeBack,
        2 => context.l10n.newPhoneMeet,
        _ => context.l10n.phoneLoginHint,
      };

  Future<void> _scanServer() async {
    final endpoint = await Navigator.of(context).push<SyncEndpoint>(
      MaterialPageRoute(builder: (_) => const ServerScanPage()),
    );
    if (!mounted || endpoint == null) return;
    setState(() {
      server.text = endpoint.url;
      token.text = endpoint.token;
      showAdvanced = true;
      error = null;
    });
  }

  Future<void> _next() async {
    setState(() {
      busy = true;
      error = null;
    });
    final store = context.read<Store>();
    try {
      await store.setServer(server.text, token.text);
      final exists = await store.checkPhoneExists(phone.text);
      if (!mounted) return;
      setState(() => step = exists ? 1 : 2);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _login() async {
    setState(() {
      busy = true;
      error = null;
    });
    final err = await context.read<Store>().login(rawPhone: phone.text, password: password.text);
    if (!mounted) return;
    setState(() {
      busy = false;
      error = err;
    });
  }

  Future<void> _register() async {
    setState(() {
      busy = true;
      error = null;
    });
    final merged = {
      ...selectedInterests,
      if (interests.text.trim().isNotEmpty) interests.text.trim(),
    }.join('、');
    final err = await context.read<Store>().register(
          rawPhone: phone.text,
          password: password.text,
          name: name.text,
          age: int.tryParse(age.text.trim()) ?? 0,
          grade: grade,
          interests: merged,
        );
    if (!mounted) return;
    setState(() {
      busy = false;
      error = err;
    });
  }

  InputDecoration _field({
    required String label,
    String? hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.92),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: CamiColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: CamiColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: CamiColors.roseDeep, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RoseBackdrop(
      intensity: 0.5,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _HeroHeader(pulse: _pulse, subtitle: _subtitle),
              const SizedBox(height: 18),
              _StepDots(step: step),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) {
                  final offset = Tween<Offset>(begin: const Offset(0.04, 0.06), end: Offset.zero).animate(anim);
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(step),
                  child: step == 0
                      ? _buildPhoneStep()
                      : step == 1
                          ? _buildLoginStep()
                          : _buildRegisterStep(),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: CamiColors.redBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFC8C8)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: CamiColors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(error!, style: const TextStyle(color: CamiColors.red, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanel(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.phone, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(context.l10n.phoneConfirmHint, style: const TextStyle(color: CamiColors.muted, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 11,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                decoration: _field(
                  label: context.l10n.phone11,
                  hint: '13800000000',
                  prefix: const Icon(Icons.phone_iphone, color: CamiColors.roseDeep),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => showAdvanced = !showAdvanced),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              showAdvanced ? Icons.expand_less : Icons.expand_more,
                              color: CamiColors.muted,
                            ),
                            Text(
                              showAdvanced ? context.l10n.collapseSync : context.l10n.syncSettings,
                              style: const TextStyle(color: CamiColors.muted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : _scanServer,
                    icon: const Icon(Icons.qr_code_scanner, color: CamiColors.roseDeep),
                    label: Text(context.l10n.scanFillUrl, style: const TextStyle(color: CamiColors.roseDeep, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  children: [
                    TextField(
                      controller: server,
                      decoration: _field(
                        label: context.l10n.syncUrl,
                        hint: 'https://xxxx.cpolar.top',
                        prefix: const Icon(Icons.cloud_outlined, color: CamiColors.roseDeep),
                        suffix: IconButton(
                          tooltip: context.l10n.scanQr,
                          onPressed: busy ? null : _scanServer,
                          icon: const Icon(Icons.qr_code_scanner, color: CamiColors.roseDeep),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: token,
                      decoration: _field(
                        label: context.l10n.syncPassphrase,
                        prefix: const Icon(Icons.key_outlined, color: CamiColors.roseDeep),
                      ),
                    ),
                  ],
                ),
                crossFadeState: showAdvanced ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        RoseButton(label: busy ? context.l10n.checking : context.l10n.nextStep, onPressed: busy ? null : _next),
      ],
    );
  }

  Widget _buildLoginStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanel(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  RoseAvatar(size: 48, label: phone.text.isEmpty ? '?' : phone.text.substring(phone.text.length - 1)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.registeredAccount, style: const TextStyle(color: CamiColors.muted, fontSize: 12)),
                        Text(phone.text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: password,
                obscureText: obscure,
                onSubmitted: (_) => busy ? null : _login(),
                decoration: _field(
                  label: context.l10n.password,
                  prefix: const Icon(Icons.lock_outline, color: CamiColors.roseDeep),
                  suffix: IconButton(
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: CamiColors.muted),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        RoseButton(label: busy ? context.l10n.loggingIn : context.l10n.enterApp, onPressed: busy ? null : _login),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy
              ? null
              : () => setState(() {
                    step = 0;
                    password.clear();
                    error = null;
                  }),
          child: Text(context.l10n.changePhone, style: const TextStyle(color: CamiColors.roseDeep, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildRegisterStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanel(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.registerFor(phone.text), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(context.l10n.profileOnlyThisPhone, style: const TextStyle(color: CamiColors.muted, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                decoration: _field(
                  label: context.l10n.childName,
                  prefix: const Icon(Icons.favorite_outline, color: CamiColors.roseDeep),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: age,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _field(
                  label: context.l10n.age,
                  prefix: const Icon(Icons.cake_outlined, color: CamiColors.roseDeep),
                ),
              ),
              const SizedBox(height: 14),
              Text(context.l10n.gradeLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in ['一年级', '二年级', '三年级', '四年级', '五年级', '六年级'])
                    ChoiceChip(
                      label: Text(context.l10n.gradeName(g)),
                      selected: grade == g,
                      selectedColor: CamiColors.blush,
                      labelStyle: TextStyle(
                        color: grade == g ? CamiColors.roseDeep : CamiColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(color: grade == g ? CamiColors.rose : CamiColors.line),
                      onSelected: (_) => setState(() => grade = g),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(context.l10n.interests, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in interestChips)
                    FilterChip(
                      label: Text(context.l10n.interestName(item)),
                      selected: selectedInterests.contains(item),
                      selectedColor: CamiColors.blush,
                      checkmarkColor: CamiColors.roseDeep,
                      labelStyle: TextStyle(
                        color: selectedInterests.contains(item) ? CamiColors.roseDeep : CamiColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: selectedInterests.contains(item) ? CamiColors.rose : CamiColors.line,
                      ),
                      onSelected: (on) => setState(() {
                        if (on) {
                          selectedInterests.add(item);
                        } else {
                          selectedInterests.remove(item);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: interests,
                decoration: _field(
                  label: context.l10n.otherInterests,
                  prefix: const Icon(Icons.auto_awesome_outlined, color: CamiColors.roseDeep),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: password,
                obscureText: obscure,
                decoration: _field(
                  label: context.l10n.setPassword,
                  prefix: const Icon(Icons.lock_outline, color: CamiColors.roseDeep),
                  suffix: IconButton(
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: CamiColors.muted),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        RoseButton(label: busy ? context.l10n.registering : context.l10n.registerAndEnter, onPressed: busy ? null : _register),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy
              ? null
              : () => setState(() {
                    step = 0;
                    error = null;
                  }),
          child: Text(context.l10n.back, style: const TextStyle(color: CamiColors.roseDeep, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.pulse, required this.subtitle});
  final AnimationController pulse;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(CamiAssets.roseBg, fit: BoxFit.cover, alignment: Alignment.center),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xE6FF6B9A),
                        CamiColors.rose.withValues(alpha: 0.55),
                        const Color(0x66FFFFFF),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: pulse,
                  builder: (context, child) {
                    final t = 0.92 + pulse.value * 0.08;
                    return Transform.scale(scale: t, child: child);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(CamiAssets.crownBadge, width: 58, height: 58, fit: BoxFit.cover),
                  ),
                ),
                const Spacer(),
                Text(
                  context.l10n.appTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    shadows: [Shadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 2))],
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    subtitle,
                    key: ValueKey(subtitle),
                    style: const TextStyle(
                      color: Color(0xFFF8E8EF),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final labels = [context.l10n.phone, step == 2 ? context.l10n.register : context.l10n.login, context.l10n.tr('进入', 'Go')];
    final active = step == 0
        ? 0
        : step == 1 || step == 2
            ? 1
            : 2;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: i <= active ? CamiColors.rose : CamiColors.line,
              ),
            ),
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= active ? CamiColors.roseDeep : Colors.white,
                  border: Border.all(color: i <= active ? CamiColors.roseDeep : CamiColors.line, width: 2),
                ),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: i <= active ? Colors.white : CamiColors.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: i <= active ? CamiColors.roseDeep : CamiColors.muted,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
