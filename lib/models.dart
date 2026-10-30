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
  });

  String pinHash;
  String childName;
  String updatedAt;
  List<TaskTemplate> tasks;
  List<TaskProgress> progress;
  List<Reward> rewards;
  List<Redemption> redemptions;
  Map<String, int> playsUsed;

  Map<String, dynamic> toJson() => {
        'pinHash': pinHash,
        'childName': childName,
        'updatedAt': updatedAt,
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'progress': progress.map((e) => e.toJson()).toList(),
        'rewards': rewards.map((e) => e.toJson()).toList(),
        'redemptions': redemptions.map((e) => e.toJson()).toList(),
        'playsUsed': playsUsed,
      };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
        pinHash: j['pinHash'] as String,
        childName: (j['childName'] as String?) ?? 'Cami',
        updatedAt: (j['updatedAt'] as String?) ?? '',
        tasks: ((j['tasks'] as List?) ?? [])
            .map((e) => TaskTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        progress: ((j['progress'] as List?) ?? [])
            .map((e) => TaskProgress.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        rewards: ((j['rewards'] as List?) ?? [])
            .map((e) => Reward.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        redemptions: ((j['redemptions'] as List?) ?? [])
            .map((e) => Redemption.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        playsUsed: ((j['playsUsed'] as Map?) ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ),
      );
}

const subjects = ['语文', '数学', '英语', '其他'];
const englishTypes = ['作业单', '歌谣', '跨学科', '词汇句型'];
const minuteChoices = [5, 10, 15, 20, 25, 30];
