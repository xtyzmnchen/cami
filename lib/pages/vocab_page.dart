import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models.dart';
import '../services/voice.dart';
import '../store.dart';
import '../theme.dart';
import '../vocab/schedule.dart';
import '../vocab/words.dart';
import '../widgets.dart';

class VocabPage extends StatefulWidget {
  const VocabPage({super.key});

  @override
  State<VocabPage> createState() => _VocabPageState();
}

class _VocabPageState extends State<VocabPage> {
  late VocabDayRecord _session;
  var _cursor = 0;
  var _studying = false;
  final _input = TextEditingController();
  var _showAnswer = false;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    final store = context.read<Store>();
    _session = store.ensureVocabToday();
    _cursor = _firstPending();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  int _firstPending() {
    for (var i = 0; i < _session.wordIndexes.length; i++) {
      if (!_session.mastered.contains(_session.wordIndexes[i])) return i;
    }
    return 0;
  }

  void _reloadSession() {
    final store = context.read<Store>();
    _session = store.data.vocab.dayOf(store.todayKey) ?? store.ensureVocabToday();
  }

  VocabWord? get _current {
    if (_session.wordIndexes.isEmpty) return null;
    if (_cursor < 0 || _cursor >= _session.wordIndexes.length) return null;
    return wordAt(_session.wordIndexes[_cursor]);
  }

  int? get _currentIndex {
    if (_session.wordIndexes.isEmpty) return null;
    if (_cursor < 0 || _cursor >= _session.wordIndexes.length) return null;
    return _session.wordIndexes[_cursor];
  }

  Future<void> _finishWord() async {
    final word = _current;
    final index = _currentIndex;
    if (word == null || index == null) return;

    final s = context.l10n;
    if (!dictationMatches(_input.text, word.en)) {
      setState(() {
        _feedback = s.dictationWrong;
        _showAnswer = true;
      });
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.rememberPrompt),
        content: Text(s.rememberBody(word.en, word.zh)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.lookAgain)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.remembered)),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await context.read<Store>().masterVocabWord(context.read<Store>().todayKey, index);
    if (!mounted) return;
    _reloadSession();
    _input.clear();
    _showAnswer = false;
    _feedback = null;

    final next = _firstPending();
    final allDone = _session.done;
    setState(() {
      _cursor = next;
      if (allDone) _studying = false;
    });
    if (allDone) {
      toast(context, s.vocabAllDone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final s = context.l10n;
    _reloadSession();
    final mode = parseVocabMode(_session.mode);
    final total = _session.wordIndexes.length;
    final done = _session.mastered.length;

    return RoseBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(s.vocabTitle),
          actions: [
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VocabHistoryPage()),
              ),
              child: Text(s.vocabList),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            GlassPanel(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.modeTitleOf(vocabModeKey(mode)),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total == 0
                        ? (mode == VocabMode.daily ? s.bankDone : s.noReviewYet)
                        : s.modeHint(vocabModeKey(mode), total),
                    style: const TextStyle(color: CamiColors.muted),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _chip(s.todayCount(done, total)),
                      const SizedBox(width: 8),
                      _chip(s.bankProgress(store.data.vocab.nextIndex, vocabBankSize)),
                    ],
                  ),
                  if (total > 0) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : done / total,
                        minHeight: 8,
                        color: CamiColors.roseDeep,
                        backgroundColor: CamiColors.blush,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (total > 0) _todayList(mode),
            const SizedBox(height: 12),
            if (!_studying) ...[
              RoseButton(
                label: _session.done
                    ? s.vocabDoneAgain
                    : total == 0
                        ? s.vocabGoList
                        : s.vocabStart,
                onPressed: total == 0
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const VocabHistoryPage()),
                        )
                    : () => setState(() {
                          _studying = true;
                          _cursor = _session.done ? 0 : _firstPending();
                          _input.clear();
                          _showAnswer = false;
                          _feedback = null;
                        }),
              ),
              if (_session.done)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: RoseButton(
                    label: s.vocabMonthList,
                    filled: false,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VocabHistoryPage()),
                    ),
                  ),
                ),
            ] else
              _studyCard(),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: CamiColors.blush,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CamiColors.line),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _todayList(VocabMode mode) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mode == VocabMode.daily
                ? context.l10n.todayWords(_session.wordIndexes.length)
                : mode == VocabMode.weekly
                    ? context.l10n.saturdayReview(_session.wordIndexes.length)
                    : context.l10n.monthReview(_session.wordIndexes.length),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < _session.wordIndexes.length; i++)
            _wordTile(_session.wordIndexes[i], i + 1),
        ],
      ),
    );
  }

  Widget _wordTile(int index, int no) {
    final w = wordAt(index);
    if (w == null) return const SizedBox.shrink();
    final mastered = _session.mastered.contains(index);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        mastered ? Icons.check_circle : Icons.circle_outlined,
        color: mastered ? CamiColors.green : CamiColors.line,
        size: 22,
      ),
      title: Text('$no. ${w.en}', style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${w.ipa}  ·  ${w.zh}'),
      trailing: IconButton(
        icon: const Icon(Icons.volume_up_rounded, color: CamiColors.roseDeep),
        onPressed: () => Voice.sayEn(w.en),
      ),
      onTap: () => setState(() {
        _studying = true;
        _cursor = _session.wordIndexes.indexOf(index).clamp(0, _session.wordIndexes.length - 1);
        _input.clear();
        _showAnswer = false;
        _feedback = null;
      }),
    );
  }

  Widget _studyCard() {
    final s = context.l10n;
    final word = _current;
    if (word == null) {
      return GlassPanel(
        child: Text(s.noWordsLeft, style: const TextStyle(color: CamiColors.muted)),
      );
    }
    final no = _cursor + 1;
    final total = _session.wordIndexes.length;
    final mastered = _session.mastered.contains(_currentIndex);

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(s.wordOf(no, total), style: const TextStyle(color: CamiColors.muted, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (mastered)
                Text(s.alreadyRemembered, style: const TextStyle(color: CamiColors.green, fontWeight: FontWeight.w800)),
              IconButton(
                tooltip: s.backToList,
                onPressed: () => setState(() => _studying = false),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _showAnswer || mastered ? word.en : '······',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
          const SizedBox(height: 6),
          Text(
            word.ipa,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: CamiColors.muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            word.zh,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CamiColors.roseDeep),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => Voice.sayEn(word.en),
                icon: const Icon(Icons.volume_up_rounded),
                label: Text(s.readWord),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => setState(() => _showAnswer = !_showAnswer),
                icon: Icon(_showAnswer ? Icons.visibility_off : Icons.visibility),
                label: Text(_showAnswer ? s.hide : s.peek),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CamiColors.blush.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CamiColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(s.example, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const Spacer(),
                    IconButton(
                      tooltip: s.readSentence,
                      onPressed: () => Voice.sayEn(word.sentence),
                      icon: const Icon(Icons.record_voice_over_rounded, color: CamiColors.roseDeep),
                    ),
                  ],
                ),
                Text(word.sentence, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35)),
                const SizedBox(height: 6),
                Text(word.sentenceZh, style: const TextStyle(color: CamiColors.muted, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(s.writeEnglish, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _input,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _finishWord(),
            decoration: InputDecoration(
              hintText: s.writeHint,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: CamiColors.roseDeep, width: 1.5),
              ),
            ),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 8),
            Text(_feedback!, style: const TextStyle(color: CamiColors.red, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 14),
          RoseButton(
            label: mastered ? s.next : s.done,
            onPressed: () async {
              if (mastered) {
                setState(() {
                  if (_cursor < total - 1) {
                    _cursor++;
                  } else {
                    _studying = false;
                  }
                  _input.clear();
                  _showAnswer = false;
                  _feedback = null;
                });
                return;
              }
              await _finishWord();
            },
          ),
        ],
      ),
    );
  }
}

class VocabHistoryPage extends StatelessWidget {
  const VocabHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final s = context.l10n;
    final history = store.vocabHistory();
    final monthly = history.where((d) => d.mode == 'monthly').toList();
    final weekly = history.where((d) => d.mode == 'weekly').toList();
    final daily = history.where((d) => d.mode == 'daily').toList();

    return RoseBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, title: Text(s.vocabHistoryTitle)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            GlassPanel(
              padding: const EdgeInsets.all(14),
              child: Text(
                s.vocabSyncHint(store.data.vocab.nextIndex, vocabBankSize),
                style: const TextStyle(color: CamiColors.muted, height: 1.4),
              ),
            ),
            const SizedBox(height: 12),
            _section(context, s.modeMonthly, monthly),
            _section(context, s.modeWeekly, weekly),
            _section(context, s.modeDaily, daily),
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(s.noVocabHistory, textAlign: TextAlign.center, style: const TextStyle(color: CamiColors.muted)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<VocabDayRecord> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final s = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ),
        for (final row in rows)
          GlassPanel(
            margin: const EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              title: Text(
                '${row.date} · ${s.wordsCount(row.wordIndexes.length)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                row.done
                    ? s.progressDone(row.mastered.length, row.wordIndexes.length)
                    : s.progressOnly(row.mastered.length, row.wordIndexes.length),
              ),
              children: [
                for (final index in row.wordIndexes)
                  Builder(
                    builder: (context) {
                      final w = wordAt(index);
                      if (w == null) return const SizedBox.shrink();
                      final ok = row.mastered.contains(index);
                      return ListTile(
                        leading: Icon(ok ? Icons.check_circle : Icons.circle_outlined, color: ok ? CamiColors.green : CamiColors.line),
                        title: Text(w.en, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${w.ipa}  ·  ${w.zh}\n${w.sentence}\n${w.sentenceZh}'),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.volume_up_rounded, color: CamiColors.roseDeep),
                          onPressed: () => Voice.sayEn(w.en),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
