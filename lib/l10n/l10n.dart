import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../logic.dart';

/// 小皇冠中英文文案。家长端设置可切换，写入本地后全局生效。
class AppL10n {
  AppL10n(this.locale);

  final Locale locale;

  bool get isEn => locale.languageCode.toLowerCase() == 'en';

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n) ?? AppL10n(const Locale('zh'));
  }

  static AppL10n fromCode(String code) =>
      AppL10n(Locale(code == 'en' ? 'en' : 'zh', code == 'en' ? null : 'CN'));

  String get appTitle => isEn ? 'Little Crown' : '小皇冠';

  // —— 底部导航 ——
  String get tabToday => isEn ? 'Today' : '今日';
  String get tabCalendar => isEn ? 'Calendar' : '日历';
  String get tabPoints => isEn ? 'Points' : '积分';
  String get tabSummary => isEn ? 'Summary' : '总结';
  String get navReview => isEn ? 'Review' : '批改';
  String get navTasks => isEn ? 'Tasks' : '任务';
  String get navRewards => isEn ? 'Rewards' : '兑换';
  String get navSettings => isEn ? 'Settings' : '设置';

  // —— 通用 ——
  String get start => isEn ? 'Start' : '开始';
  String get view => isEn ? 'View' : '查看';
  String get save => isEn ? 'Save' : '保存';
  String get cancel => isEn ? 'Cancel' : '取消';
  String get close => isEn ? 'Close' : '关闭';
  String get done => isEn ? 'Done' : '完成';
  String get next => isEn ? 'Next' : '下一个';
  String get delete => isEn ? 'Delete' : '删除';
  String get confirm => isEn ? 'Confirm' : '确认';
  String get wrongPin => isEn ? 'Wrong PIN' : '密码不对';
  String get parentMode => isEn ? 'Parent' : '家长端';
  String get studentMode => isEn ? 'Student' : '学生端';
  String get pomodoro => isEn ? 'Pomodoro' : '番茄钟';
  String get language => isEn ? 'Language' : '语言';
  String get languageZh => isEn ? '中文' : '中文';
  String get languageEn => isEn ? 'English' : 'English';
  String get languageHint =>
      isEn ? 'Switch app language for everyone on this phone.' : '切换本机 App 显示语言（中 / 英）。';

  // —— 首页 ——
  String hello(DateTime now) {
    final h = now.hour;
    if (isEn) {
      if (h < 5 || h >= 22) return 'Good night';
      if (h < 12) return 'Good morning';
      if (h < 14) return 'Good noon';
      if (h < 18) return 'Good afternoon';
      return 'Good evening';
    }
    if (h < 5 || h >= 22) return '夜深了';
    if (h < 11) return '早安';
    if (h < 13) return '中午好';
    if (h < 18) return '下午好';
    return '晚上好';
  }

  String dateLabel(DateTime d) =>
      isEn ? '${_enMonth(d.month)} ${d.day}' : '${d.month}月${d.day}日';

  String _enMonth(int m) => const [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][m];

  String get allDoneToday => isEn ? 'All done today' : '今天都做完了';
  String remainingTasks(int n) => isEn ? '$n left' : '还差 $n 件';
  String gameUnlockHint(int n) =>
      isEn ? 'Finish today’s $n tasks to unlock the game' : '做完今天这 $n 件，小游戏才会亮';
  String get gameTestTitle => isEn ? 'Game testing' : '小游戏测试';
  String get gameTestHint =>
      isEn ? 'All games open for testing' : '临时开放全部游戏，测完把 kListAllGamesForTest 改回 false';
  String get todaysPick => isEn ? 'Today’s game' : '今天抽到';
  String get playTenMinutes => isEn ? 'Play for 10 minutes' : '今天可以玩 10 分钟';
  String playRemain(String clock) =>
      isEn ? '$clock left — keep playing' : '还剩 $clock，可继续玩';
  String get playStart => isEn ? 'Play' : '开始玩';
  String get playContinue => isEn ? 'Continue' : '继续玩';
  String get playTimeUsedUp => isEn ? 'Play time used up' : '今天的游戏时间用完了';
  String get playTomorrow =>
      isEn ? 'Come back tomorrow after homework' : '明天作业做完再来玩 10 分钟';
  String get gameLocked => isEn ? 'Games locked' : '小游戏还没亮';
  String get gameUnlockNeed =>
      isEn ? 'Finish today’s homework to unlock' : '今天作业都做完，这里才会亮';
  String nextTask(String title, int done, int total) =>
      isEn ? 'Next · $title · $done/$total' : '下一件 · $title · $done/$total';
  String allFinishedCount(int done, int total) =>
      isEn ? 'All done · $done/$total' : '都完成了 · $done/$total';
  String subjectProgress(int done, int total) =>
      isEn ? '$done / $total done' : '$done / $total 已完成';
  String get checkOff => isEn ? 'Check' : '打勾';

  // —— 科目 ——
  String subject(String raw) {
    if (!isEn) return raw;
    return switch (raw) {
      '语文' => 'Chinese',
      '数学' => 'Math',
      '英语' => 'English',
      '其他' => 'Other',
      _ => raw,
    };
  }

  String taskTitle(String id, String title) {
    if (!isEn) return title;
    const byId = {
      'cn1': 'School homework',
      'cn2': 'Huanggang workbook',
      'cn3': 'Handwriting practice',
      'cn4': 'Reading (in + out of class)',
      'm1': 'Calculations',
      'm2': 'Lesson workbook',
      'm3': 'Daily practice',
      'e1': 'English check-in',
      'e2': 'Read 3 pages',
      'e3': 'Vocab practice',
      'e4': 'English dictation',
      'o1': 'Exercise',
      'o2': 'Recite a poem',
      'o3': 'English class',
    };
    if (byId.containsKey(id)) return byId[id]!;
    const byTitle = {
      '校内作业': 'School homework',
      '黄冈每课一练': 'Huanggang workbook',
      '每课练字': 'Handwriting practice',
      '每课阅读 + 课外阅读': 'Reading (in + out of class)',
      '计算题': 'Calculations',
      '每课一练': 'Lesson workbook',
      '每日一练': 'Daily practice',
      '英语打卡': 'English check-in',
      '每日3页阅读': 'Read 3 pages',
      '背诵单词': 'Vocab practice',
      '背诵3个单词': 'Vocab practice',
      '英语默写': 'English dictation',
      '运动': 'Exercise',
      '背古诗': 'Recite a poem',
      '上英语课': 'English class',
      '新的一项': 'New item',
      '未命名': 'Untitled',
    };
    return byTitle[title] ?? title;
  }

  String minutesPoints(int minutes, int points) =>
      isEn ? '$minutes min · $points pts' : '$minutes 分钟 · $points 分';
  String schoolOnlyMeta(int points) =>
      isEn ? 'Done at school · $points pts' : '在学校完成 · $points 分';
  String get needsRecording => isEn ? 'Recording required' : '要录音';
  String get vocabTag => isEn ? 'Vocab' : '背单词';

  // —— 家长端 ——
  String parentTitle(String name) => isEn ? 'Parent · $name' : '家长端 · $name';
  String get switchToStudent => isEn ? 'Back to student' : '切回学生端';
  String get logout => isEn ? 'Log out' : '退出登录';
  String get loggedOut => isEn ? 'Logged out' : '已退出';
  String currentAccount(String phone) =>
      isEn ? 'Account $phone' : '当前账号 $phone';
  String get childName => isEn ? "Child's name" : '孩子的名字';
  String get saveName => isEn ? 'Save name' : '保存名字';
  String get syncComputer => isEn ? 'Sync PC' : '同步电脑';
  String get syncHint => isEn
      ? 'Each phone number has its own data. If the PC tunnel URL changes, the app can auto-fetch the new one from GitHub.'
      : '每个手机号的数据单独存放。电脑公网地址变了时，App 会从 GitHub 自动拉取新地址。';
  String get syncUrl => isEn ? 'Sync URL' : '同步地址';
  String get syncUrlHint => isEn ? 'e.g. https://xxxx.cpolar.cn' : '例如 https://xxxx.cpolar.cn';
  String get scanQr => isEn ? 'Scan QR' : '扫描二维码';
  String get syncToken => isEn ? 'Token (default cami-home)' : '口令（默认 cami-home）';
  String get saveUrl => isEn ? 'Save URL' : '保存地址';
  String get urlSaved => isEn ? 'URL saved' : '地址已保存';
  String get refreshEndpoint => isEn ? 'Fetch latest sync URL' : '从云端刷新同步地址';
  String endpointUpdated(String url) =>
      isEn ? 'Sync URL updated · $url' : '同步地址已更新 · $url';
  String get endpointUnchanged =>
      isEn ? 'Already using the latest sync URL' : '已是最新同步地址';
  String get endpointFetchFail =>
      isEn ? 'Couldn’t fetch sync URL from GitHub' : '没拉到云端同步地址';
  String get showSyncQr => isEn ? 'Show sync QR' : '显示同步二维码';
  String get syncQrTitle => isEn ? 'Sync QR code' : '同步二维码';
  String get syncQrHint =>
      isEn ? 'Scan on another phone’s login screen' : '用另一台手机在登录页扫一扫';
  String get needValidUrl => isEn ? 'Enter a valid sync URL first' : '先填写有效的同步地址';
  String get syncing => isEn ? 'Syncing…' : '正在同步';
  String get uploadNow => isEn ? 'Upload to sync PC' : '现在上传到同步电脑';
  String get uploaded => isEn ? 'Uploaded' : '已上传到同步电脑';
  String get pullNow => isEn ? 'Pull from sync PC' : '从同步电脑拉取';
  String get neverSynced => isEn ? 'Not synced yet' : '还没同步';
  String lastSynced(String hm) => isEn ? 'Last sync $hm' : '上次同步 $hm';
  String get newPin => isEn ? 'New 4-digit parent PIN' : '新的四位家长密码';
  String get changePin => isEn ? 'Change parent PIN' : '修改家长密码';
  String get pinNeedFour => isEn ? 'Enter 4 digits' : '请输入四位数字';
  String get pinChanged => isEn ? 'PIN updated' : '密码已改';

  // —— 批改状态 ——
  String notStarted(int pts) => isEn ? 'Not started · preset $pts pts' : '还没开始 · 预设 $pts 分';
  String noSubmit(int pts) => isEn ? 'Nothing submitted · preset $pts pts' : '还没交内容 · 预设 $pts 分';
  String pendingReview(int n) => isEn ? 'To review · $n files' : '待批改 · $n 个附件';
  String finishedPts(int pts, String comment) => isEn
      ? 'Done $pts pts${comment.isEmpty ? '' : ' · $comment'}'
      : '已完成 $pts 分${comment.isEmpty ? '' : ' · $comment'}';

  // —— 游戏 ——
  String gameName(GameKind kind) {
    if (!isEn) return gameTitles[kind]!;
    return switch (kind) {
      GameKind.snake => 'Snake',
      GameKind.memory => 'Memory',
      GameKind.catchFruit => 'Catch Fruit',
      GameKind.sliceFruit => 'Fruit Slice',
      GameKind.whackMole => 'Whack-a-Mole',
      GameKind.match3 => 'Match-3',
      GameKind.runner => 'Princess Run',
    };
  }

  String get scoreThisRound => isEn ? 'Score' : '本局得分';
  String get keepTimeOnExit =>
      isEn ? 'Time is saved when you leave' : '今天还剩这些时间，退出后还能继续玩';
  String get testingNoTime => isEn ? 'Test mode · no time cost' : '测试模式 · 不扣今日时间';
  String get exitKeepTime => isEn ? 'Leave — time kept' : '先退出，时间还留着';
  String get timeUp => isEn ? 'Time’s up' : '时间到了';
  String get exitTest => isEn ? 'Exit test' : '退出测试';
  String testingSuffix(String title) => isEn ? '$title (test)' : '$title（测试）';

  // —— 单词 ——
  String get vocabTitle => isEn ? 'Vocabulary' : '背诵单词';
  String get vocabList => isEn ? 'Word list' : '词单';
  String get vocabStart => isEn ? 'Start learning' : '开始背诵';
  String get vocabDoneAgain => isEn ? 'Done today · review again' : '今天已完成 · 再看一遍';
  String get vocabGoList => isEn ? 'Browse word list' : '去词单复习';
  String get vocabMonthList => isEn ? 'Month / history words' : '查看本月 / 往期单词';
  String get rememberPrompt => isEn ? 'Got it memorized?' : '记住了吗？';
  String rememberBody(String en, String zh) =>
      isEn ? '“$en” — $zh\nConfirm to learn the next one.' : '「$en」—— $zh\n确认记住就可以学下一个。';
  String get lookAgain => isEn ? 'Look again' : '再看看';
  String get remembered => isEn ? 'Got it' : '记住了';
  String get vocabAllDone => isEn ? 'Today’s words are done!' : '今天的单词都背完啦';
  String get dictationWrong =>
      isEn ? 'Not quite — listen again and rewrite' : '默写不对，再听一遍、看一眼再写';
  String get writeEnglish => isEn ? 'Write the English word' : '默写英文单词';
  String get writeHint => isEn ? 'Write from meaning & sound' : '根据中文和发音写出来';
  String get readWord => isEn ? 'Word' : '读单词';
  String get peek => isEn ? 'Peek' : '看一眼';
  String get hide => isEn ? 'Hide' : '藏起来';
  String get example => isEn ? 'Example' : '例句';
  String get alreadyRemembered => isEn ? 'Remembered' : '已记住';
  String get bankDone => isEn ? 'Word bank finished — review in list' : '词库已经学完啦，去「词单」复习吧';
  String get noReviewYet =>
      isEn ? 'No words to review yet — learn on weekdays first' : '还没有可复习的单词，先平日新学几天';
  String todayCount(int done, int total) => isEn ? 'Today $done/$total' : '今天 $done/$total';
  String bankProgress(int next, int size) =>
      isEn ? 'Bank $next/$size' : '词库进度 $next/$size';
  String wordOf(int no, int total) => isEn ? '$no / $total' : '第 $no / $total 个';
  String get modeDaily => isEn ? 'New today' : '今日新学';
  String get modeWeekly => isEn ? 'Saturday review' : '周六周复习';
  String get modeMonthly => isEn ? 'Monthly review' : '月度复盘';
  String modeTitleOf(String mode) => switch (mode) {
        'weekly' => modeWeekly,
        'monthly' => modeMonthly,
        _ => modeDaily,
      };
  String vocabBadge(String mode, int done, int total) {
    if (total == 0) return isEn ? 'Bank finished' : '词库已学完';
    return '${modeTitleOf(mode)} $done/$total';
  }
  String vocabBadgePreview(String mode, int n) => '${modeTitleOf(mode)} $n';

  // —— 英语打卡 ——
  String get englishCheckIn => isEn ? 'English check-in' : '英语打卡';
  String get englishMoreToday => isEn ? 'Also today' : '今天还有';
  String get noEnglishCheckIn =>
      isEn ? 'No English check-in yet — add it in Parent' : '还没有英语打卡这项，去家长端加一下';
  String get englishDoneListen =>
      isEn ? 'Check-in done today — you can replay recordings' : '今天英语打卡已完成，下面还能听回录音';
  String get englishReadyToCheck => isEn ? 'All four recorded — you can check off' : '四条都录好了，可以打勾';
  String get englishPickTypes =>
      isEn ? 'Pick a type — record all four to check off' : '选一个类型，四条都录完才能打勾';
  String stillMissing(String list) => isEn ? 'Still missing: $list' : '还没录：$list';
  String get englishCheckedToday => isEn ? 'Checked in today' : '今天已打卡';
  String get englishAllRecorded => isEn ? 'These are all recorded' : '这几条都录好了';
  String get englishSaved => isEn ? 'English check-in saved' : '英语打卡已记下';
  String get openWechatMini => isEn ? 'Open WeChat mini program' : '去微信小程序打卡';
  String get wechatBindHint =>
      isEn ? 'Opens WeChat if the page isn’t bound yet' : '还没绑定指定页时，会先打开微信';
  String get open => isEn ? 'Open' : '打开';
  String get noOtherEnglish => isEn ? 'No other English tasks' : '没有其他英语任务';
  String get noRecordingYet => isEn ? 'No recording yet' : '还没有录音';
  String get listenRecording => isEn ? 'Play' : '听录音';
  String get share => isEn ? 'Share' : '分享';
  String get preparingShare => isEn ? 'Preparing to share…' : '正在准备分享…';
  String get shareUnavailable =>
      isEn ? 'File not ready to share yet — sync first' : '还不能分享，请先同步上传';
  String get shareFailed => isEn ? 'Share failed, try again' : '分享失败，再试一次';
  String get tapToFullscreen => isEn ? 'Tap to view fullscreen' : '点按全屏查看';
  String get reRecord => isEn ? 'Re-record' : '重录';
  String get goRecord => isEn ? 'Record' : '去录';
  String englishType(String raw) {
    if (!isEn) return raw;
    return switch (raw) {
      '作业单' => 'Worksheet',
      '歌谣' => 'Chant',
      '跨学科' => 'Cross-subject',
      '词汇句型' => 'Vocab & sentences',
      _ => raw,
    };
  }

  // —— 录音 / 作业页 ——
  String get needMic => isEn ? 'Microphone permission needed' : '要用麦克风才能录音';
  String get recordTooShort => isEn ? 'Too short — record at least 10 seconds' : '录音过短，请录满 10 秒';
  String get noSound => isEn ? 'No sound captured, try again' : '没有录到声音，再试一次';
  String get recordSaved => isEn ? 'Recording saved' : '录音已保存';
  String get saving => isEn ? 'Saving…' : '正在保存…';
  String recordingClock(String clock) => isEn ? 'Recording $clock' : '正在录音 $clock';
  String recordNeedMore(int left) =>
      isEn ? 'At least 10s ($left s left)' : '至少录满 10 秒（还差 $left 秒）';
  String get stopWhenDone => isEn ? 'Tap stop when finished' : '说完再点一下停止';
  String get pleaseWait => isEn ? 'Please wait' : '请稍等';
  String get stopAndSave => isEn ? 'Stop & save' : '停止并保存';
  String get takePhoto => isEn ? 'Photo' : '拍照';
  String get takeVideo => isEn ? 'Video' : '录像';
  String get takeAudio => isEn ? 'Audio' : '录音';
  String get noMediaYet => isEn ? 'No photos, videos, or audio yet' : '还没有照片、视频或录音';
  String get iFinished => isEn ? 'I finished' : '我完成了';
  String get acceptChallenge => isEn ? 'Accept challenge' : '接受挑战';
  String get anotherRound => isEn ? 'Another round' : '再来一轮';
  String get endTimer => isEn ? 'End timer' : '结束计时';
  String get timerKeepsGoing =>
      isEn ? 'Timer keeps running if you leave — it resumes when you return.' : '离开页面后，倒计时会继续，再进来接着走。';
  String get inProgress => isEn ? 'In progress' : '进行中';
  String get roundTimeUp => isEn ? 'This round’s time is up' : '这轮时间到了';
  String get notStartedYet => isEn ? 'Not started' : '还没开始';
  String get timerStopped => isEn ? 'Timer stopped' : '已结束这轮计时';
  String get holdToStopAlarm =>
      isEn ? 'Hold 2 seconds to stop\nParent PIN can stop it right away' : '按住两秒就会停下\n妈妈输入密码可以马上关';
  String get holdCrown => isEn ? 'Hold the crown' : '按住小皇冠';
  String get alarmStopped => isEn ? 'Alarm stopped' : '闹钟停下了';
  String get photo => isEn ? 'Photo' : '照片';
  String get video => isEn ? 'Video' : '视频';
  String get audio => isEn ? 'Audio' : '录音';
  String taskTimeUpBody(String title, int minutes) =>
      isEn ? '$title — $minutes minutes are up' : '$title，$minutes 分钟到了';
  String get taskTimeUpSubtitle => isEn ? 'Time is up for this task' : '这件作业的时间到了';
  String minutesPts(int minutes, int points) =>
      isEn ? '$minutes min · $points pts' : '$minutes 分钟 · $points 分';

  // —— 登录 ——
  String get login => isEn ? 'Log in' : '登录';
  String get register => isEn ? 'Sign up' : '注册';
  String get phone => isEn ? 'Phone' : '手机号';
  String get password => isEn ? 'Password' : '密码';
  String get setPassword => isEn ? 'Set password (min 4)' : '设置密码（至少 4 位）';
  String get syncSettings => isEn ? 'Sync PC settings' : '同步电脑设置';
  String get collapseSync => isEn ? 'Hide sync settings' : '收起同步设置';
  String get welcomeBack => isEn ? 'Welcome back — enter password' : '欢迎回来，输入密码继续';
  String get newPhoneMeet => isEn ? 'New number — tell us about your child' : '新号码，先认识一下孩子';
  String get phoneLoginHint =>
      isEn ? 'Sign in with phone — each person has their own workbook' : '手机号登录，每人一份作业本';
  String get phoneConfirmHint =>
      isEn ? 'Confirm sync PC first, then check if this number is registered' : '先确认同步电脑，再查这个号码有没有注册';
  String get phone11 => isEn ? '11-digit phone' : '11 位手机号';
  String get scanFillUrl => isEn ? 'Scan to fill URL' : '扫码填地址';
  String get syncPassphrase => isEn ? 'Sync token' : '同步口令';
  String get nextStep => isEn ? 'Next' : '下一步';
  String get checking => isEn ? 'Checking…' : '查询中…';
  String get registeredAccount => isEn ? 'Registered account' : '已注册账号';
  String get loggingIn => isEn ? 'Signing in…' : '登录中…';
  String get enterApp => isEn ? 'Enter Little Crown' : '进入小皇冠';
  String get changePhone => isEn ? 'Use another phone' : '换一个手机号';
  String registerFor(String phone) => isEn ? 'Sign up $phone' : '注册 $phone';
  String get profileOnlyThisPhone =>
      isEn ? 'This info belongs only to this phone number' : '这些信息只属于这个手机号';
  String get age => isEn ? 'Age' : '年龄';
  String get gradeLabel => isEn ? 'Grade' : '年级';
  String get interests => isEn ? 'Interests' : '兴趣';
  String get otherInterests => isEn ? 'Other interests (optional)' : '其他兴趣（可空）';
  String get registering => isEn ? 'Signing up…' : '注册中…';
  String get registerAndEnter => isEn ? 'Sign up & enter' : '注册并进入';
  String get back => isEn ? 'Back' : '返回';
  String gradeName(String raw) {
    if (!isEn) return raw;
    const map = {
      '一年级': 'Grade 1',
      '二年级': 'Grade 2',
      '三年级': 'Grade 3',
      '四年级': 'Grade 4',
      '五年级': 'Grade 5',
      '六年级': 'Grade 6',
    };
    return map[raw] ?? raw;
  }

  String interestName(String raw) {
    if (!isEn) return raw;
    const map = {
      '画画': 'Drawing',
      '阅读': 'Reading',
      '运动': 'Sports',
      '音乐': 'Music',
      '乐高': 'LEGO',
      '英语': 'English',
    };
    return map[raw] ?? raw;
  }

  /// 兴趣字段按顿号/逗号拆开再逐项翻译。
  String interestsLine(String raw) {
    if (!isEn || raw.trim().isEmpty) return raw;
    final parts = raw.split(RegExp(r'[、,，/|]+')).map((e) => e.trim()).where((e) => e.isNotEmpty);
    return parts.map(interestName).join(', ');
  }

  /// 编辑框里显示的任务名；保存时用 [canonicalTaskTitle] 写回中文种子名。
  String displayTaskTitle(String id, String title) => taskTitle(id, title);

  String canonicalTaskTitle(String id, String display) {
    final typed = display.trim();
    if (typed.isEmpty) return '未命名';
    const idToZh = {
      'cn1': '校内作业',
      'cn2': '黄冈每课一练',
      'cn3': '每课练字',
      'cn4': '每课阅读 + 课外阅读',
      'm1': '计算题',
      'm2': '每课一练',
      'm3': '每日一练',
      'e1': '英语打卡',
      'e2': '每日3页阅读',
      'e3': '背诵单词',
      'e4': '英语默写',
      'o1': '运动',
      'o2': '背古诗',
      'o3': '上英语课',
    };
    final zh = idToZh[id];
    if (zh != null) {
      final en = taskTitle(id, zh);
      if (typed == zh || typed == en) return zh;
    }
    const enToZh = {
      'School homework': '校内作业',
      'Huanggang workbook': '黄冈每课一练',
      'Handwriting practice': '每课练字',
      'Reading (in + out of class)': '每课阅读 + 课外阅读',
      'Calculations': '计算题',
      'Lesson workbook': '每课一练',
      'Daily practice': '每日一练',
      'English check-in': '英语打卡',
      'Read 3 pages': '每日3页阅读',
      'Vocab practice': '背诵单词',
      'English dictation': '英语默写',
      'Exercise': '运动',
      'Recite a poem': '背古诗',
      'English class': '上英语课',
      'New item': '新的一项',
      'Untitled': '未命名',
    };
    return enToZh[typed] ?? typed;
  }

  // —— 日历 / 积分 ——
  String get calendar => isEn ? 'Calendar' : '月历';
  String get pointsBook => isEn ? 'Points' : '积分册';
  String get summary => isEn ? 'Summary' : '总结';
  String get pickDate => isEn ? 'Pick a date' : '选择年月日';
  String get previousMonth => isEn ? 'Previous month' : '上个月';
  String get nextMonth => isEn ? 'Next month' : '下个月';
  String get tapPickDate => isEn ? 'Tap to pick year/month/day' : '点这里选择年月日';
  String get legendAllDone => isEn ? 'All done' : '全完成';
  String get legendPartial => isEn ? 'Partial' : '一部分';
  String get legendNone => isEn ? 'None' : '没做';
  String get legendNoTask => isEn ? 'No tasks' : '无任务';
  String monthYear(int y, int m) => isEn ? '${_enMonth(m)} $y' : '$y年$m月';
  String monthPointsLine(int monthPts, int yearPts) => isEn
      ? 'This month $monthPts pts · This year $yearPts pts'
      : '本月 $monthPts 分 · 今年 $yearPts 分';
  String dayPointsLine(int pts) => isEn ? '$pts pts today' : '当天 $pts 分';
  String fullDate(DateTime d) =>
      isEn ? '${_enMonth(d.month)} ${d.day}, ${d.year}' : '${d.year}年${d.month}月${d.day}日';
  List<String> get weekdayShort =>
      isEn ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'] : const ['一', '二', '三', '四', '五', '六', '日'];
  List<String> get weekdaySunFirst =>
      isEn ? const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] : const ['日', '一', '二', '三', '四', '五', '六'];

  String get usablePoints => isEn ? 'Points you can use' : '可以用的积分';
  String earnedRedeemed(int earned, int spent) =>
      isEn ? 'Earned $earned · Redeemed $spent' : '已得到 $earned · 已兑换 $spent';
  String get today => isEn ? 'Today' : '今天';
  String get thisMonth => isEn ? 'This month' : '这个月';
  String get thisYear => isEn ? 'This year' : '今年';
  String get monthDecor => isEn ? 'This month’s decorations' : '这个月的小装饰';
  String get decorHint => isEn ? 'Finish tasks to light up flowers' : '完成任务就会亮起小花';
  String get iWantRedeem => isEn ? 'Redeem' : '我要兑换';
  String get alreadyRedeemed => isEn ? 'Already redeemed' : '已经兑换';
  String timesCount(int n) => isEn ? '$n times' : '$n 次';
  String get noRedeemYet => isEn ? 'Nothing redeemed yet' : '还没有兑换过';
  String get redeemHint =>
      isEn ? 'Save points for stickers and little gifts' : '攒够积分就能换贴纸和小礼物';
  String get redeemGift => isEn ? 'Redeem a gift' : '兑换礼物';
  String balanceNow(int n) => isEn ? 'You have $n pts now' : '现在有 $n 分可以用';
  String redeemedDeduct(int cost) => isEn ? 'Redeemed (−$cost pts)' : '已兑换，扣掉 $cost 分';
  String redeemFor(int cost) => isEn ? 'Redeem for $cost pts' : '$cost 分兑换';
  String needMorePts(int n) => isEn ? 'Need $n more pts' : '还差 $n 分';
  String pts(int n) => isEn ? '$n pts' : '$n 分';
  String get oneDayMile => isEn ? 'A mile a day' : '一日千里';
  String todayPtsBanner(int n) => isEn ? 'Today $n pts' : '今天 $n 分';

  /// 附件展示名：把种子任务名、英语类型、照片/视频/录音等换成当前语言。
  String mediaLabel(String label) {
    if (!isEn || label.isEmpty) return label;
    var out = label;
    const types = {
      '作业单': 'Worksheet',
      '歌谣': 'Chant',
      '跨学科': 'Cross-subject',
      '词汇句型': 'Vocab & sentences',
    };
    for (final e in types.entries) {
      out = out.replaceAll(e.key, e.value);
    }
    const titles = {
      '校内作业': 'School homework',
      '黄冈每课一练': 'Huanggang workbook',
      '每课练字': 'Handwriting practice',
      '每课阅读 + 课外阅读': 'Reading (in + out of class)',
      '计算题': 'Calculations',
      '每课一练': 'Lesson workbook',
      '每日一练': 'Daily practice',
      '英语打卡': 'English check-in',
      '每日3页阅读': 'Read 3 pages',
      '背诵单词': 'Vocab practice',
      '背诵3个单词': 'Vocab practice',
      '英语默写': 'English dictation',
      '运动': 'Exercise',
      '背古诗': 'Recite a poem',
      '上英语课': 'English class',
      '作业': 'Task',
    };
    for (final e in titles.entries) {
      out = out.replaceAll(e.key, e.value);
    }
    out = out
        .replaceAll('照片', ' photo')
        .replaceAll('视频', ' video')
        .replaceAll('录音', ' audio');
    return out.trim();
  }

  String rewardTitle(String id, String title) {
    if (!isEn) return title;
    const byId = {
      'r1': 'A sticker',
      'r2': 'Pick a bedtime story',
      'r3': 'Watch a cartoon',
      'r4': 'Weekend little gift',
    };
    if (byId.containsKey(id)) return byId[id]!;
    const byTitle = {
      '一张贴纸': 'A sticker',
      '选一个睡前故事': 'Pick a bedtime story',
      '看一集动画': 'Watch a cartoon',
      '周末小礼物': 'Weekend little gift',
      '小奖励': 'Little reward',
    };
    return byTitle[title] ?? title;
  }

  // —— 番茄钟 ——
  String focusMinutesBody(int minutes) =>
      isEn ? 'Focused for $minutes minutes' : '专注了 $minutes 分钟';
  String get pomodoroEnded => isEn ? 'Pomodoro finished' : '番茄钟结束了';
  String get confirmExit => isEn ? 'Leave now?' : '确定退出吗？';
  String get pomodoroExitHint =>
      isEn ? 'Timer is running — leaving will stop this round.' : '番茄钟还在走，退出后这轮计时会停掉。';
  String get keepFocusing => isEn ? 'Keep focusing' : '继续专注';
  String get confirmLeave => isEn ? 'Leave' : '确定退出';
  String get thenRest5 => isEn ? 'Then rest 5 minutes' : '然后休息 5 分钟';
  String get alarmHoldHint =>
      isEn ? 'It will call you. Hold the crown to stop.' : '到点会叫你。按住小皇冠就能停下。';
  String get startFocus => isEn ? 'Start focus' : '开始专注';
  String get focusing => isEn ? 'Focusing…' : '正在专注';

  // —— 家长批改 / 任务 ——
  String todayPtsWaiting(int pts, int waiting) =>
      isEn ? 'Today $pts pts · $waiting to review' : '今天 $pts 分 · 待批改 $waiting 件';
  String monthPtsOnly(int pts) => isEn ? 'This month $pts pts' : '本月 $pts 分';
  String get refresh => isEn ? 'Refresh' : '刷新';
  String get priorityReview => isEn ? 'Review first' : '优先待批改';
  String get noTasksTodaySubject => isEn ? 'No tasks in this subject today' : '这科今天没有任务';
  String get scoreThisTask => isEn ? 'Score this task' : '给这件打几分';
  String get commentOptional => isEn ? 'Comment (optional)' : '评语，可以空着';
  String get saveScore => isEn ? 'Save score' : '记下分数';
  String get scoreSaved => isEn ? 'Saved' : '已记下';
  String get schoolProxyCheck => isEn ? 'Done at school — parent checks' : '人在学校，家长代勾';
  String get sendBack => isEn ? 'Send back to redo' : '退回，让她再做一次';
  String get manageTasksBySubject =>
      isEn ? 'Manage daily tasks by subject' : '按学科管理每天要做的任务';
  String itemsCount(int n) => isEn ? '$n items' : '$n 项';
  String get newItem => isEn ? 'New item' : '新的一项';
  String addForSubject(String subject) => isEn ? 'Add for $subject' : '给$subject加一项';
  String get addTask => isEn ? 'Add task' : '添加任务';
  String get editTask => isEn ? 'Edit task' : '编辑任务';
  String get taskName => isEn ? 'Name' : '名称';
  String get schoolOnlyToggle => isEn ? 'Done at school — check only' : '在学校完成，只打勾';
  String get durationMinutes => isEn ? 'Duration (minutes)' : '时长（分钟）';
  String get pointsOnComplete => isEn ? 'Points when done' : '完成可得几分';
  String get englishSpecialToggle =>
      isEn ? 'English check-in — pick type & record' : '这是英语打卡，要选类型并录音';
  String get unnamed => isEn ? 'Untitled' : '未命名';
  String get deleteThis => isEn ? 'Delete this' : '删除这件';
  String balanceSpent(int balance, int spent) =>
      isEn ? 'Available $balance pts · Redeemed $spent pts' : '可用 $balance 分 · 已兑换 $spent 分';
  String get redeem => isEn ? 'Redeem' : '兑换';
  String get addReward => isEn ? 'Add a reward' : '添加一个奖励';
  String get redeemHistory => isEn ? 'Redeem history' : '兑换记录';
  String get newReward => isEn ? 'New reward' : '新奖励';
  String get rewardName => isEn ? 'Reward name' : '奖励名称';
  String get needs => isEn ? 'Costs' : '需要';
  String get littleReward => isEn ? 'Little reward' : '小奖励';
  String redeemedTitle(String title) => isEn ? 'Redeemed $title' : '已兑换 $title';

  // —— 单词页补充 ——
  String get noWordsLeft => isEn ? 'No words left to learn' : '没有可学的单词了';
  String get backToList => isEn ? 'Back to list' : '返回列表';
  String get readSentence => isEn ? 'Read sentence' : '读句子';
  String get vocabHistoryTitle => isEn ? 'Word list' : '单词词单';
  String vocabSyncHint(int next, int size) => isEn
      ? 'Learned $next / $size\nProgress syncs to the server — keep going after reinstall.'
      : '已学到第 $next 个 / 共 $size 个\n进度会同步到服务器，换手机或重装也能接着背。';
  String get noVocabHistory =>
      isEn ? 'No history yet — learn today’s words first' : '还没有学习记录，先去背今天的单词吧';
  String wordsCount(int n) => isEn ? '$n words' : '$n 词';
  String progressDone(int done, int total) =>
      isEn ? 'Done $done/$total' : '已完成 $done/$total';
  String progressOnly(int done, int total) => isEn ? 'Progress $done/$total' : '进度 $done/$total';
  String todayWords(int n) => isEn ? 'Today’s $n words' : '今天这 $n 个';
  String saturdayReview(int n) => isEn ? 'Saturday review · $n' : '本周六复习 $n 个';
  String monthReview(int n) => isEn ? 'Monthly review · $n' : '本月复盘 $n 个';
  String modeHint(String mode, int count) {
    if (isEn) {
      return switch (mode) {
        'weekly' => 'Review last week’s $count words',
        'monthly' => 'Review this month’s $count words',
        _ => 'Learn $count new words today',
      };
    }
    return switch (mode) {
      'weekly' => '复习上一周的 $count 个单词',
      'monthly' => '复盘近一个月的 $count 个单词',
      _ => '今天要背 $count 个新单词',
    };
  }

  // —— 附件 / 日视图 ——
  String donePtsLine(int done, int total, int points) =>
      isEn ? '$done/$total · $points pts' : '$done/$total · $points 分';
  String get unfinished => isEn ? 'Not done' : '未完成';
  String get noAttachments => isEn ? 'No attachments' : '没有附件';
  String get notStartedShort => isEn ? 'Not started' : '还没开始';
  String mediaTapHint(int n) =>
      isEn ? '$n files — tap arrow to view' : '$n 个附件，点箭头查看';
  String deleteKind(String kind) => isEn ? 'Delete $kind?' : '删除$kind？';
  String deleteCannotUndo(String label) => label.isEmpty
      ? (isEn ? 'This cannot be undone.' : '删掉后不能恢复。')
      : (isEn ? 'Delete “$label”? This cannot be undone.' : '删掉「$label」后不能恢复。');

  // —— 扫码 ——
  String get scanSyncTitle => isEn ? 'Scan sync URL' : '扫描同步地址';
  String get toggleFlash => isEn ? 'Flash' : '开关闪光灯';
  String get notSyncQr =>
      isEn ? 'Not a sync URL — scan the sync QR on the PC' : '不是同步地址，请扫电脑上的同步二维码';
  String cameraError(String code) =>
      isEn ? 'Cannot open camera: $code\nAllow camera permission and retry' : '无法打开相机：$code\n请允许相机权限后再试';
  String get aimSyncQr =>
      isEn ? 'Aim at the sync QR on the PC or another phone' : '对准电脑或另一台手机上的同步二维码';

  // —— Store 错误 ——
  String get errNeedSyncUrl => isEn ? 'Enter sync PC URL first' : '先填写同步电脑地址';
  String get errBadPhone => isEn ? 'Invalid phone number' : '手机号不对';
  String get errBadToken => isEn ? 'Wrong sync token' : '同步口令不对';
  String get errNoServer => isEn ? 'Cannot reach server' : '查不到服务器';
  String get errPasswordShort => isEn ? 'Password needs at least 4 characters' : '密码至少 4 位';
  String get errNeedName => isEn ? 'Please enter a name' : '请填写名字';
  String get errRegisterFail => isEn ? 'Sign-up failed' : '注册失败';
  String get errLoginFail => isEn ? 'Login failed' : '登录失败';
  String get errTaskNotFound => isEn ? 'Task not found' : '找不到这件作业';
  String get errVocabNotDone => isEn ? 'Today’s words aren’t finished' : '今天的单词还没背完';
  String get errPoemNotDone => isEn ? 'Today’s poem isn’t memorized' : '今天的古诗还没背熟';
  String get errFinishFirst => isEn ? 'Finish first, then tap done' : '请先完成后再点击哦';
  String errStillRecord(String list) => isEn ? 'Still missing: $list' : '还没录完：$list';
  String get errRewardNotFound => isEn ? 'Reward not found' : '找不到这个奖励';
  String get errNotEnoughPts => isEn ? 'Not enough points' : '积分还不够';
  String get errWrongPassphrase => isEn ? 'Wrong token' : '口令不对';
  String get errReLogin => isEn ? 'Please sign in again' : '请重新登录';
  String get errSessionExpired => isEn ? 'Session expired — sign in again' : '登录已失效，请重新登录';
  String get errTokenFix =>
      isEn ? 'Wrong token — set cami-home in Settings' : '口令不对，设置里填 cami-home 后再保存';
  String get errSyncOffline =>
      isEn ? 'Not connected to sync PC — check URL and cpolar' : '还没连上同步电脑，检查地址和 cpolar';
  String get errNeedUrlLogin => isEn ? 'Enter sync URL and sign in first' : '先填写同步电脑地址并登录';
  String get errNeedPhoneLogin => isEn ? 'Sign in with phone first' : '请先用手机号登录';
  String errUploadFail(int code) => isEn ? 'Upload failed $code' : '上传失败 $code';
  String errSyncFail(int code) => isEn ? 'Sync failed $code' : '同步失败 $code';
  String errReadFail(int code) => isEn ? 'Read failed $code' : '读取失败 $code';
  String syncPartialMedia(int n) => isEn
      ? 'Progress synced, but $n attachments didn’t upload. Use the phone that took the photos/audio and tap Upload again.'
      : '进度已同步，但有 $n 个附件没传到电脑。请用拍过照/录过音的那台手机再点「现在上传」';

  // —— 游戏 HUD ——
  String levelUp(int level) => isEn ? 'Level $level! Faster & harder' : '第 $level 关！更快更难啦';
  String get level => isEn ? 'Level' : '关卡';
  String get score => isEn ? 'Score' : '得分';
  String get combo => isEn ? 'Combo' : '连击';
  String get awesome => isEn ? 'Awesome!' : '太棒了';

  // —— 录音页补充 ——
  String get recordedBack => isEn ? 'Saved — go back' : '录好了，返回';
  String get recordAnother => isEn ? 'Record another' : '再录一条';
  String get readyThenStart => isEn ? 'Ready? Tap start' : '准备好了再点开始';
  String get startRecord => isEn ? 'Start recording' : '开始录音';
  String get listeningNote => isEn ? 'Listening for note…' : '正在听备注…';
  String get speakNoteOptional =>
      isEn ? 'Speak a note → Chinese (optional)' : '说出备注，译成中文（可选）';
  String justSaid(String text) => isEn ? 'You said\n$text' : '刚才说到\n$text';
  String zhNote(String text) => isEn ? 'Chinese note\n$text' : '中文备注\n$text';
  String get didntCatch => isEn ? 'Didn’t catch that, say again' : '没听清，再说一次';

  String tr(String zh, String en) => isEn ? en : zh;
}

class AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const AppL10nDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'zh' || locale.languageCode == 'en';

  @override
  Future<AppL10n> load(Locale locale) => SynchronousFuture(AppL10n(locale));

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppL10n> old) => false;
}

extension AppL10nX on BuildContext {
  AppL10n get l10n => AppL10n.of(this);
}
