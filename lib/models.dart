class TaskTemplate {
  TaskTemplate({
    required this.id,
    required this.subject,
    required this.title,
    required this.minutes,
    required this.points,
    this.schoolOnly = false,
    this.englishSpecial = false,
    this.note = '',
    this.bonus = false,
    this.bonusDate,
    this.removed = false,
  });

  String id;
  String subject;
  String title;
  int minutes;
  int points;
  bool schoolOnly;
  bool englishSpecial;
  String note;
  bool bonus;
  String? bonusDate;
  /// 家长「移除」后对学生端隐藏，数据仍保留，可再改/恢复。
  bool removed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'title': title,
        'minutes': minutes,
        'points': points,
        'schoolOnly': schoolOnly,
        'englishSpecial': englishSpecial,
        'note': note,
        'bonus': bonus,
        'bonusDate': bonusDate,
        'removed': removed,
      };

  factory TaskTemplate.fromJson(Map<String, dynamic> j) => TaskTemplate(
        id: j['id'] as String,
        subject: j['subject'] as String,
        title: j['title'] as String,
        minutes: (j['minutes'] as num).toInt(),
        points: (j['points'] as num).toInt(),
        schoolOnly: j['schoolOnly'] == true,
        englishSpecial: j['englishSpecial'] == true,
        note: (j['note'] as String?) ?? '',
        bonus: j['bonus'] == true,
        bonusDate: j['bonusDate'] as String?,
        removed: j['removed'] == true,
      );
}

class MediaItem {
  MediaItem({
    required this.id,
    required this.kind,
    required this.storedName,
    required this.path,
    required this.label,
    this.englishType = '',
    this.note = '',
    this.noteZh = '',
  });

  String id;
  String kind;
  String storedName;
  String path;
  String label;
  String englishType;
  String note;
  String noteZh;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'storedName': storedName,
        'path': path,
        'label': label,
        'englishType': englishType,
        'note': note,
        'noteZh': noteZh,
      };

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
        id: j['id'] as String,
        kind: j['kind'] as String,
        storedName: j['storedName'] as String,
        path: (j['path'] as String?) ?? '',
        label: (j['label'] as String?) ?? '',
        englishType: (j['englishType'] as String?) ?? '',
        note: (j['note'] as String?) ?? '',
        noteZh: (j['noteZh'] as String?) ?? '',
      );
}

class TaskProgress {
  TaskProgress({
    required this.taskId,
    required this.date,
    this.done = false,
    this.points = 0,
    this.comment = '',
    this.timerEndsAt,
    List<MediaItem>? media,
  }) : media = media ?? [];

  String taskId;
  String date;
  bool done;
  int points;
  String comment;
  /// ISO8601；有值表示这件作业的倒计时还在走或刚结束。
  String? timerEndsAt;
  List<MediaItem> media;

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'date': date,
        'done': done,
        'points': points,
        'comment': comment,
        'timerEndsAt': timerEndsAt,
        'media': media.map((e) => e.toJson()).toList(),
      };

  factory TaskProgress.fromJson(Map<String, dynamic> j) => TaskProgress(
        taskId: j['taskId'] as String,
        date: j['date'] as String,
        done: j['done'] == true,
        points: (j['points'] as num?)?.toInt() ?? 0,
        comment: (j['comment'] as String?) ?? '',
        timerEndsAt: j['timerEndsAt'] as String?,
        media: ((j['media'] as List?) ?? [])
            .map((e) => MediaItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class UserProfile {
  UserProfile({
    required this.phone,
    required this.name,
    required this.age,
    required this.grade,
    required this.interests,
  });

  String phone;
  String name;
  int age;
  String grade;
  String interests;

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'name': name,
        'age': age,
        'grade': grade,
        'interests': interests,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        phone: '${j['phone'] ?? ''}',
        name: '${j['name'] ?? ''}',
        age: (j['age'] as num?)?.toInt() ?? 0,
        grade: '${j['grade'] ?? ''}',
        interests: '${j['interests'] ?? ''}',
      );
}

class Reward {
  Reward({required this.id, required this.title, required this.cost});

  String id;
  String title;
  int cost;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'cost': cost};

  factory Reward.fromJson(Map<String, dynamic> j) => Reward(
        id: j['id'] as String,
        title: j['title'] as String,
        cost: (j['cost'] as num).toInt(),
      );
}

class Redemption {
  Redemption({
    required this.id,
    required this.title,
    required this.cost,
    required this.at,
  });

  String id;
  String title;
  int cost;
  String at;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cost': cost,
        'at': at,
      };

  factory Redemption.fromJson(Map<String, dynamic> j) => Redemption(
        id: j['id'] as String,
        title: j['title'] as String,
        cost: (j['cost'] as num).toInt(),
        at: j['at'] as String,
      );
}

class VocabDayRecord {
  VocabDayRecord({
    required this.date,
    required this.mode,
    List<int>? wordIndexes,
    List<int>? mastered,
  })  : wordIndexes = wordIndexes ?? [],
        mastered = mastered ?? [];

  /// yyyy-MM-dd
  String date;

  /// daily | weekly | monthly
  String mode;
  List<int> wordIndexes;
  List<int> mastered;

  bool get done =>
      wordIndexes.isNotEmpty && mastered.length >= wordIndexes.length;

  int get remaining =>
      (wordIndexes.length - mastered.length).clamp(0, wordIndexes.length);

  Map<String, dynamic> toJson() => {
        'date': date,
        'mode': mode,
        'wordIndexes': wordIndexes,
        'mastered': mastered,
      };

  factory VocabDayRecord.fromJson(Map<String, dynamic> j) => VocabDayRecord(
        date: (j['date'] as String?) ?? '',
        mode: (j['mode'] as String?) ?? 'daily',
        wordIndexes: ((j['wordIndexes'] as List?) ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
        mastered: ((j['mastered'] as List?) ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
      );
}

class VocabState {
  VocabState({
    this.nextIndex = 0,
    List<VocabDayRecord>? days,
  }) : days = days ?? [];

  /// 下一个新学单词在词库中的索引（随同步保存，删 App 不丢）
  int nextIndex;
  List<VocabDayRecord> days;

  VocabDayRecord? dayOf(String date) {
    for (final d in days) {
      if (d.date == date) return d;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'nextIndex': nextIndex,
        'days': days.map((e) => e.toJson()).toList(),
      };

  factory VocabState.fromJson(Map<String, dynamic>? j) {
    if (j == null) return VocabState();
    return VocabState(
      nextIndex: (j['nextIndex'] as num?)?.toInt() ?? 0,
      days: ((j['days'] as List?) ?? [])
          .map((e) => VocabDayRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class PoemDayRecord {
  PoemDayRecord({
    required this.date,
    required this.poemIndex,
    this.mastered = false,
  });

  String date;
  int poemIndex;
  bool mastered;

  Map<String, dynamic> toJson() => {
        'date': date,
        'poemIndex': poemIndex,
        'mastered': mastered,
      };

  factory PoemDayRecord.fromJson(Map<String, dynamic> j) => PoemDayRecord(
        date: (j['date'] as String?) ?? '',
        poemIndex: (j['poemIndex'] as num?)?.toInt() ?? 0,
        mastered: j['mastered'] == true,
      );
}

class PoemState {
  PoemState({
    this.nextIndex = 0,
    this.continueIndex,
    List<PoemDayRecord>? days,
  }) : days = days ?? [];

  /// 下一首新诗索引
  int nextIndex;

  /// 昨天没背熟，今天继续这一首
  int? continueIndex;
  List<PoemDayRecord> days;

  PoemDayRecord? dayOf(String date) {
    for (final d in days) {
      if (d.date == date) return d;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'nextIndex': nextIndex,
        'continueIndex': continueIndex,
        'days': days.map((e) => e.toJson()).toList(),
      };

  factory PoemState.fromJson(Map<String, dynamic>? j) {
    if (j == null) return PoemState();
    return PoemState(
      nextIndex: (j['nextIndex'] as num?)?.toInt() ?? 0,
      continueIndex: (j['continueIndex'] as num?)?.toInt(),
      days: ((j['days'] as List?) ?? [])
          .map((e) => PoemDayRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class AppData {
  AppData({
    required this.pinHash,
    required this.childName,
    required this.updatedAt,
    required this.tasks,
    required this.progress,
    required this.rewards,
    required this.redemptions,
    required this.playsUsed,
    Map<String, int>? playSecondsLeft,
    Set<String>? removedTaskIds,
    Set<String>? deletedTaskIds,
    Set<String>? deletedRewardIds,
    VocabState? vocab,
    PoemState? poems,
  })  : playSecondsLeft = playSecondsLeft ?? {},
        removedTaskIds = removedTaskIds ?? {},
        deletedTaskIds = deletedTaskIds ?? {},
        deletedRewardIds = deletedRewardIds ?? {},
        vocab = vocab ?? VocabState(),
        poems = poems ?? PoemState();

  String pinHash;
  String childName;
  String updatedAt;
  List<TaskTemplate> tasks;
  List<TaskProgress> progress;
  List<Reward> rewards;
  List<Redemption> redemptions;
  /// 旧字段：曾表示「玩过几轮」。新逻辑用 [playSecondsLeft]，保留仅为兼容同步。
  Map<String, int> playsUsed;
  /// 当天游戏剩余秒数；有键且为 0 表示 10 分钟已用完。
  Map<String, int> playSecondsLeft;
  /// 家长「移除」的任务 id（对学生隐藏）。合并时移除优先，避免旧机又显示出来。
  Set<String> removedTaskIds;
  /// 真正删除过的任务 id（兼容旧数据）；新逻辑用 [removedTaskIds] 软移除。
  Set<String> deletedTaskIds;
  /// 已删除兑换项 id（墓碑）。
  Set<String> deletedRewardIds;
  VocabState vocab;
  PoemState poems;

  Map<String, dynamic> toJson() => {
        'pinHash': pinHash,
        'childName': childName,
        'updatedAt': updatedAt,
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'progress': progress.map((e) => e.toJson()).toList(),
        'rewards': rewards.map((e) => e.toJson()).toList(),
        'redemptions': redemptions.map((e) => e.toJson()).toList(),
        'playsUsed': playsUsed,
        'playSecondsLeft': playSecondsLeft,
        'removedTaskIds': removedTaskIds.toList(),
        'deletedTaskIds': deletedTaskIds.toList(),
        'deletedRewardIds': deletedRewardIds.toList(),
        'vocab': vocab.toJson(),
        'poems': poems.toJson(),
      };

  factory AppData.fromJson(Map<String, dynamic> j) {
    final removedTaskIds = {
      for (final e in ((j['removedTaskIds'] as List?) ?? [])) '$e',
    };
    final deletedTaskIds = {
      for (final e in ((j['deletedTaskIds'] as List?) ?? [])) '$e',
    };
    final deletedRewardIds = {
      for (final e in ((j['deletedRewardIds'] as List?) ?? [])) '$e',
    };
    // 旧版硬删墓碑：不再出现在列表；软移除则保留任务并标 removed。
    final tasks = ((j['tasks'] as List?) ?? [])
        .map((e) => TaskTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((t) => !deletedTaskIds.contains(t.id))
        .map((t) {
          if (removedTaskIds.contains(t.id) || t.removed) {
            t.removed = true;
            removedTaskIds.add(t.id);
          }
          return t;
        })
        .toList();
    return AppData(
      pinHash: j['pinHash'] as String,
      childName: (j['childName'] as String?) ?? 'Cami',
      updatedAt: (j['updatedAt'] as String?) ?? '',
      tasks: tasks,
      progress: ((j['progress'] as List?) ?? [])
          .map((e) => TaskProgress.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      rewards: ((j['rewards'] as List?) ?? [])
          .map((e) => Reward.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((r) => !deletedRewardIds.contains(r.id))
          .toList(),
      redemptions: ((j['redemptions'] as List?) ?? [])
          .map((e) => Redemption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      playsUsed: ((j['playsUsed'] as Map?) ?? {}).map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      ),
      playSecondsLeft: ((j['playSecondsLeft'] as Map?) ?? {}).map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      ),
      removedTaskIds: removedTaskIds,
      deletedTaskIds: deletedTaskIds,
      deletedRewardIds: deletedRewardIds,
      vocab: VocabState.fromJson(
        j['vocab'] is Map ? Map<String, dynamic>.from(j['vocab'] as Map) : null,
      ),
      poems: PoemState.fromJson(
        j['poems'] is Map ? Map<String, dynamic>.from(j['poems'] as Map) : null,
      ),
    );
  }
}

const subjects = ['语文', '数学', '英语', '其他'];
const englishTypes = ['作业单', '歌谣', '跨学科', '词汇句型'];
const minuteChoices = [5, 10, 15, 20, 25, 30];
