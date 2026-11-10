import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models.dart';
import '../poems/poems.dart';
import '../services/voice.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class PoemPage extends StatefulWidget {
  const PoemPage({super.key, required this.task});
  final TaskTemplate task;

  @override
  State<PoemPage> createState() => _PoemPageState();
}

class _PoemPageState extends State<PoemPage> {
  late PoemDayRecord _session;
  var _lineIndex = 0;
  var _speaking = false;
  var _listening = false;
  String _echo = '';

  @override
  void initState() {
    super.initState();
    _session = context.read<Store>().ensurePoemToday();
  }

  Poem? get _poem => poemAt(_session.poemIndex);

  Future<void> _speakLine(int i) async {
    final poem = _poem;
    if (poem == null || i < 0 || i >= poem.lines.length) return;
    setState(() {
      _speaking = true;
      _lineIndex = i;
    });
    await Voice.sayPoem(poem.lines[i].text);
    if (mounted) setState(() => _speaking = false);
  }

  Future<void> _speakAll() async {
    final poem = _poem;
    if (poem == null) return;
    setState(() => _speaking = true);
    for (var i = 0; i < poem.lines.length; i++) {
      if (!mounted) return;
      setState(() => _lineIndex = i);
      await Voice.sayPoem(poem.lines[i].text);
    }
    if (mounted) setState(() => _speaking = false);
  }

  Future<void> _follow() async {
    final poem = _poem;
    if (poem == null || _listening) return;
    final line = poem.lines[_lineIndex.clamp(0, poem.lines.length - 1)];
    setState(() {
      _listening = true;
      _echo = '';
    });
    await Voice.sayPoem(line.text);
    if (!mounted) return;
    toast(context, context.l10n.tr('轮到你跟读啦', 'Your turn — read aloud'));
    final heard = await Voice.listen(localeId: 'zh_CN');
    if (!mounted) return;
    setState(() {
      _listening = false;
      _echo = heard ?? '';
    });
    if (heard == null || heard.isEmpty) {
      toast(context, context.l10n.tr('没听清，再试一次', 'Didn’t catch that, try again'));
      return;
    }
    toast(context, context.l10n.tr('听你说：$heard', 'Heard: $heard'));
  }

  Future<void> _onFinish() async {
    final poem = _poem;
    if (poem == null) return;
    final s = context.l10n;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tr('确定背熟了吗？', 'Memorized it?')),
        content: Text(
          s.tr(
            '「${poem.title}」\n背熟了就进入下一首；没背熟的话，明天还背这一首。',
            '"${poem.title}"\nIf mastered, next poem tomorrow; if not, keep this one.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'defer'),
            child: Text(s.tr('没背熟，明天继续', 'Not yet — continue tomorrow')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'master'),
            child: Text(s.tr('背熟了', 'Mastered')),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    final store = context.read<Store>();
    if (choice == 'master') {
      await store.masterPoemToday(widget.task.id);
      if (!mounted) return;
      toast(context, s.tr('太棒了，今天背熟啦', 'Great — memorized today!'));
      setState(() => _session = store.data.poems.dayOf(store.todayKey) ?? _session);
    } else {
      await store.deferPoemToday();
      if (!mounted) return;
      toast(context, s.tr('没关系，明天继续背这一首', 'OK — same poem tomorrow'));
      setState(() => _session = store.data.poems.dayOf(store.todayKey) ?? _session);
    }
  }

  @override
  void dispose() {
    Voice.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    _session = store.data.poems.dayOf(store.todayKey) ?? _session;
    final s = context.l10n;
    final poem = _poem;

    return RoseBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(s.tr('背古诗', 'Recite poems')),
          actions: [
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PoemListPage()),
              ),
              child: Text(s.tr('诗单', 'List')),
            ),
          ],
        ),
        body: poem == null
            ? Center(child: Text(s.tr('古诗库已学完', 'Poem bank finished')))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  GlassPanel(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poem.title,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          poem.titlePy,
                          style: const TextStyle(color: CamiColors.muted, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${poem.dynasty} · ${poem.author}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: CamiColors.roseDeep),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _session.mastered
                              ? s.tr('今天已背熟', 'Mastered today')
                              : (store.data.poems.continueIndex == _session.poemIndex
                                  ? s.tr('昨天没背熟，今天继续这一首', 'Continue yesterday’s poem')
                                  : s.tr(
                                      '进度 ${_session.poemIndex + 1} / $poemBankSize',
                                      'Progress ${_session.poemIndex + 1} / $poemBankSize',
                                    )),
                          style: const TextStyle(color: CamiColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassPanel(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                    child: Column(
                      children: [
                        for (var i = 0; i < poem.lines.length; i++)
                          _lineCard(poem.lines[i], i, highlighted: i == _lineIndex),
                      ],
                    ),
                  ),
                  if (_echo.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      s.tr('你刚才说：$_echo', 'You said: $_echo'),
                      style: const TextStyle(color: CamiColors.muted, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _speaking ? null : _speakAll,
                          icon: const Icon(Icons.volume_up_rounded),
                          label: Text(s.tr('朗诵全诗', 'Read all')),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: (_speaking || _listening) ? null : () => _speakLine(_lineIndex),
                          icon: const Icon(Icons.record_voice_over),
                          label: Text(s.tr('读这句', 'This line')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RoseButton(
                    label: _listening ? s.tr('正在听你跟读…', 'Listening…') : s.tr('跟读这句', 'Shadow this line'),
                    filled: false,
                    onPressed: (_speaking || _listening) ? null : _follow,
                  ),
                  const SizedBox(height: 8),
                  RoseButton(
                    label: _session.mastered ? s.tr('今天已完成', 'Done today') : s.tr('完成', 'Finish'),
                    onPressed: _session.mastered ? null : _onFinish,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _lineCard(PoemLine line, int index, {required bool highlighted}) {
    return InkWell(
      onTap: () {
        setState(() => _lineIndex = index);
        _speakLine(index);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: highlighted ? CamiColors.blush : Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: highlighted ? CamiColors.roseDeep : CamiColors.line),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 2,
          runSpacing: 6,
          children: [
            for (final c in line.chars)
              if (c.han.trim().isNotEmpty)
                SizedBox(
                  width: c.py.isEmpty ? 14 : 28,
                  child: Column(
                    children: [
                      if (c.py.isNotEmpty)
                        Text(
                          c.py,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9, color: CamiColors.muted, height: 1.1),
                        ),
                      Text(
                        c.han,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.15),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class PoemListPage extends StatelessWidget {
  const PoemListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final s = context.l10n;
    final mastered = {
      for (final d in store.data.poems.days)
        if (d.mastered) d.poemIndex,
    };
    return RoseBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, title: Text(s.tr('古诗诗单', 'Poem list'))),
        body: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          itemCount: poemBankSize,
          itemBuilder: (context, i) {
            final poem = grade6Poems[i];
            final ok = mastered.contains(i);
            final current = store.data.poems.nextIndex == i || store.data.poems.continueIndex == i;
            return GlassPanel(
              margin: const EdgeInsets.only(bottom: 10),
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  ok ? Icons.check_circle : Icons.menu_book_outlined,
                  color: ok ? CamiColors.green : CamiColors.roseDeep,
                ),
                title: Text(poem.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                  '${poem.titlePy}\n${poem.dynasty} · ${poem.author}${current ? s.tr(' · 正在背', ' · Current') : ''}',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.volume_up_rounded, color: CamiColors.roseDeep),
                  onPressed: () => Voice.sayPoem(poem.speakText),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
