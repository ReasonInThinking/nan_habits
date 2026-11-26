import 'dart:convert';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

void main() => runApp(const NanHabitsApp());

class NeoTheme {
  static const Color bg = Color(0xFF07080D);
  static const Color panel = Color(0xFF10131D);
  static const Color panelLight = Color(0xFF171C2B);
  static const Color border = Color(0xFF252D44);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color amber = Color(0xFFF59E0B);
  static const Color textMain = Color(0xFFF8FAFC);
  static const Color textDim = Color(0xFF64748B);
}

void playSound(String name) {
  final file = '/usr/share/sounds/freedesktop/stereo/$name.oga';
  Process.run('paplay', <String>['--volume=36000', file])
      .catchError((_) => ProcessResult(0, 0, '', ''));
}

String todayIsoString() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class NanHabitsApp extends StatelessWidget {
  const NanHabitsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NanHabits Reactor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: NeoTheme.bg),
      home: const HabitReactorScreen(),
    );
  }
}

class Habit {
  String id;
  String title;
  int totalDays;
  List<String> doneDates; // Список дат YYYY-MM-DD, когда привычка выполнена

  Habit({
    required this.id,
    required this.title,
    required this.totalDays,
    required this.doneDates,
  });

  bool get isCompleted => totalDays > 0 && doneDates.length >= totalDays;
  bool get isDoneToday => doneDates.contains(todayIsoString());

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'totalDays': totalDays,
        'doneDates': doneDates,
      };

  factory Habit.fromJson(Map<String, dynamic> json) {
    final raw = json['doneDates'];
    final list = <String>[];
    if (raw is List) {
      for (final x in raw) {
        if (x is String) list.add(x);
      }
    }
    return Habit(
      id: json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? 'Привычка',
      totalDays: json['totalDays'] is int ? json['totalDays'] as int : 14,
      doneDates: list,
    );
  }
}



class HabitReactorScreen extends StatefulWidget {
  const HabitReactorScreen({super.key});

  @override
  State<HabitReactorScreen> createState() => _HabitReactorScreenState();
}

class _HabitReactorScreenState extends State<HabitReactorScreen> {
  final TextEditingController _input = TextEditingController();

  List<Habit> _habits = [];
  int _selectedDays = 14;
  int _mode = 0; // 0 = Актив (сегодня), 1 = Кэш (до завтра), 2 = Архив
  double _dragX = 0;

  List<Habit> get _activeTodayList =>
      _habits.where((h) => !h.isCompleted && !h.isDoneToday).toList();

  List<Habit> get _cachedTodayList =>
      _habits.where((h) => !h.isCompleted && h.isDoneToday).toList();

  List<Habit> get _archivedList =>
      _habits.where((h) => h.isCompleted).toList();

  String get _savePath {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/.nan_habits_v2.json';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final f = File(_savePath);
      if (await f.exists()) {
        final raw = jsonDecode(await f.readAsString());
        if (raw is List) {
          setState(() {
            _habits = raw
                .whereType<Map<String, dynamic>>()
                .map(Habit.fromJson)
                .toList();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final f = File(_savePath);
      await f.writeAsString(jsonEncode(_habits.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  void _launchHabit() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _habits.insert(
        0,
        Habit(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: text,
          totalDays: _selectedDays,
          doneDates: <String>[],
        ),
      );
      _input.clear();
      _mode = 0;
      _dragX = 0;
    });
    playSound('message-new-instant');
    _save();
  }

  void _completeForToday(Habit habit) {
    final today = todayIsoString();
    setState(() {
      if (!habit.doneDates.contains(today)) {
        habit.doneDates.add(today);
      }
      _dragX = 0;
    });
    playSound(habit.isCompleted ? 'complete' : 'message-new-instant');
    _save();
  }

  void _undoToday(Habit habit) {
    final today = todayIsoString();
    setState(() {
      habit.doneDates.remove(today);
      _mode = 0;
      _dragX = 0;
    });
    playSound('audio-volume-change');
    _save();
  }

  void _rotateOrbit({required bool forward}) {
    final active = _activeTodayList;
    if (active.length < 2) return;

    setState(() {
      _dragX = 0;
      if (forward) {
        final first = active.first;
        _habits.remove(first);
        _habits.add(first);
      } else {
        final last = active.last;
        _habits.remove(last);
        _habits.insert(0, last);
      }
    });
    playSound('audio-volume-change');
    _save();
  }



  Widget _buildSideMagneticDock(
      int activeCount, int cachedCount, int archivedCount) {
    Widget capsule({
      required int idx,
      required String label,
      required int count,
      required IconData icon,
      required Color accent,
    }) {
      final selected = _mode == idx;
      return GestureDetector(
        onTap: () {
          setState(() => _mode = idx);
          playSound('audio-volume-change');
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 68,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? accent.withOpacity(0.18) : NeoTheme.panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? accent : NeoTheme.border,
              width: selected ? 1.8 : 1.0,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withOpacity(0.28),
                      blurRadius: 16,
                      spreadRadius: 1,
                    )
                  ]
                : <BoxShadow>[],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? accent : NeoTheme.textDim,
              ),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: selected ? NeoTheme.textMain : NeoTheme.textDim,
                ),
              ),
              const SizedBox(height: 6),
              RotatedBox(
                quarterTurns: 3,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.bold,
                    color: selected ? accent : NeoTheme.textDim,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          capsule(
            idx: 0,
            label: 'АКТИВ',
            count: activeCount,
            icon: Icons.bolt_rounded,
            accent: NeoTheme.cyan,
          ),
          const SizedBox(height: 12),
          capsule(
            idx: 1,
            label: 'КЭШ',
            count: cachedCount,
            icon: Icons.hourglass_bottom_rounded,
            accent: NeoTheme.violet,
          ),
          const SizedBox(height: 12),
          capsule(
            idx: 2,
            label: 'АРХИВ',
            count: archivedCount,
            icon: Icons.workspace_premium_rounded,
            accent: NeoTheme.amber,
          ),
        ],
      ),
    );
  }



  Widget _buildCommandConsole() {
    final presets = <int>[]
      ..add(7)
      ..add(14)
      ..add(21)
      ..add(30)
      ..add(60);

      return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: NeoTheme.panel,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  onSubmitted: (_) => _launchHabit(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: NeoTheme.textMain,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Новая привычка...',
                    hintStyle: TextStyle(color: NeoTheme.textDim),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Добавить',
                onPressed: _launchHabit,
                icon: const Icon(
                  Icons.arrow_upward_rounded,
                  color: NeoTheme.cyan,
                  size: 24,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'ЦИКЛ:',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.bold,
                  color: NeoTheme.textDim,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: presets.map((d) {
                      final active = _selectedDays == d;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedDays = d);
                          playSound('audio-volume-change');
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: active
                                ? NeoTheme.cyan.withOpacity(0.22)
                                : NeoTheme.panelLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: active ? NeoTheme.cyan : NeoTheme.border,
                            ),
                          ),
                          child: Text(
                            '$d ДН.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color:
                                  active ? NeoTheme.cyan : NeoTheme.textDim,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



   Widget _buildOrbitWing({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 88,
        decoration: BoxDecoration(
          color: enabled ? Colors.white.withOpacity(0.03) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enabled
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.02),
            width: 1.0,
          ),
        ),
        child: Icon(
          icon,
          size: 24,
          color: enabled
              ? NeoTheme.textMain.withOpacity(0.75)
              : NeoTheme.textDim.withOpacity(0.2),
        ),
      ),
    );
  }

  Widget _buildFocusMonolith(List<Habit> active) {
    if (active.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: NeoTheme.cyan.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'На сегодня всё выполнено',
              style: TextStyle(
                fontSize: 20,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w400,
                color: NeoTheme.textMain.withOpacity(0.88),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Привычки отдыхают в «Кэше» до завтра, или добавьте новую снизу',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                letterSpacing: 0.3,
                color: NeoTheme.textDim.withOpacity(0.75),
              ),
            ),
          ],
        ),
      );
    }


    final current = active.first;
    final canSwitch = active.length > 1;
    final ratio = current.totalDays > 0
        ? (current.doneDates.length / current.totalDays).clamp(0.0, 1.0)
        : 0.0;
    final percent = (ratio * 100).round();

    return Listener(
      onPointerSignal: (e) {
        if (e is PointerScrollEvent && canSwitch) {
          _rotateOrbit(forward: e.scrollDelta.dy > 0);
        }
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildOrbitWing(
            icon: Icons.keyboard_arrow_left_rounded,
            enabled: canSwitch,
            onTap: () => _rotateOrbit(forward: false),
          ),
          const SizedBox(width: 18),
                   Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => setState(() => _dragX += d.delta.dx),
                onPanEnd: (_) {
                  if (_dragX > 90) {
                    _completeForToday(current);
                  } else if (_dragX < -90 && canSwitch) {
                    _rotateOrbit(forward: true);
                  } else {
                    setState(() => _dragX = 0);
                  }
                },
                child: Transform.translate(
                  offset: Offset(_dragX, 0),
                  child: Transform.rotate(
                    angle: (_dragX / 1000).clamp(-0.14, 0.14),
                    child: Container(
                      key: ValueKey('focus_${current.id}'),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[NeoTheme.panel, Color(0xFF0C101B)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),




                                                            child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Осталось на сегодня: ${active.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 0.4,
                                  fontWeight: FontWeight.w400,
                                  color: NeoTheme.textDim.withOpacity(0.55),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Удалить привычку',
                                icon: Icon(Icons.close_rounded,
                                    size: 18,
                                    color: NeoTheme.textDim.withOpacity(0.55)),
                                onPressed: () {
                                  setState(() {
                                    _habits.remove(current);
                                    _dragX = 0;
                                  });
                                  _save();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 136,
                            height: 136,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox.expand(
                                  child: CircularProgressIndicator(
                                    value: ratio,
                                    strokeWidth: 3.0,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor:
                                        Colors.white.withOpacity(0.05),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        NeoTheme.cyan.withOpacity(0.7)),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$percent%',
                                      style: TextStyle(
                                        fontSize: 28,
                                        letterSpacing: 1.0,
                                        fontWeight: FontWeight.w300,
                                        color: NeoTheme.textMain
                                            .withOpacity(0.88),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${current.doneDates.length} из ${current.totalDays} дн.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        letterSpacing: 0.6,
                                        fontWeight: FontWeight.w400,
                                        color: NeoTheme.textDim
                                            .withOpacity(0.75),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),
                          Text(
                            current.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 27,
                              height: 1.25,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w400,
                              color: NeoTheme.textMain.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: 44,
                            height: 1.5,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _completeForToday(current),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: NeoTheme.cyan.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: NeoTheme.cyan.withOpacity(0.75),
                                    ),
                                  ),

                                  const SizedBox(width: 12),
                                  Text(
                                    'Выполнить сегодня',
                                    style: TextStyle(
                                      fontSize: 17,
                                      letterSpacing: 0.9,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          NeoTheme.textMain.withOpacity(0.78),
                                    ),

                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 18),
          _buildOrbitWing(
            icon: Icons.keyboard_arrow_right_rounded,
            enabled: canSwitch,
            onTap: () => _rotateOrbit(forward: true),
          ),
        ],
      ),
    );
  }




  Widget _buildCacheVault(List<Habit> cached) {
    if (cached.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              size: 56,
              color: NeoTheme.violet.withOpacity(0.55),
            ),
            const SizedBox(height: 12),
            const Text(
              'КЭШ ПУСТ',
              style: TextStyle(
                fontSize: 15,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w900,
                color: NeoTheme.textMain,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Выполненные сегодня привычки попадают сюда и вернутся завтра',
              style: TextStyle(fontSize: 13, color: NeoTheme.textDim),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 20),
          itemCount: cached.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, idx) {
            final item = cached[idx];
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: NeoTheme.panel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: NeoTheme.violet.withOpacity(0.5),
                  width: 1.3,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: NeoTheme.violet.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.hourglass_bottom_rounded,
                      color: NeoTheme.violet,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: NeoTheme.textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ПРОГРЕСС: ${item.doneDates.length} / ${item.totalDays} ДН.  •  ВЕРНЁТСЯ ЗАВТРА',
                          style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.bold,
                            color: NeoTheme.violet,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Отменить сегодняшнюю отметку',
                    icon: const Icon(Icons.undo_rounded, color: NeoTheme.cyan),
                    onPressed: () => _undoToday(item),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildArchiveVault(List<Habit> archived) {
    if (archived.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              size: 56,
              color: NeoTheme.amber.withOpacity(0.55),
            ),
            const SizedBox(height: 12),
            const Text(
              'АРХИВ ПУСТ',
              style: TextStyle(
                fontSize: 15,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w900,
                color: NeoTheme.textMain,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Здесь появятся полностью завершённые циклы привычек',
              style: TextStyle(fontSize: 13, color: NeoTheme.textDim),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 20),
          itemCount: archived.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, idx) {
            final item = archived[idx];
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: NeoTheme.panel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: NeoTheme.amber.withOpacity(0.55),
                  width: 1.4,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: NeoTheme.amber.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: NeoTheme.amber,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: NeoTheme.textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ЦИКЛ ЗАВЕРШЁН: ${item.totalDays} / ${item.totalDays} ДН.',
                          style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.bold,
                            color: NeoTheme.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Пройти цикл заново',
                    icon: const Icon(Icons.replay_rounded, color: NeoTheme.cyan),
                    onPressed: () {
                      setState(() {
                        item.doneDates.clear();
                        _mode = 0;
                      });
                      playSound('audio-volume-change');
                      _save();
                    },
                  ),
                  IconButton(
                    tooltip: 'Удалить',
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: NeoTheme.textDim),
                    onPressed: () {
                      setState(() => _habits.remove(item));
                      _save();
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeTodayList;
    final cached = _cachedTodayList;
    final archived = _archivedList;

    Widget currentView;
    if (_mode == 0) {
      currentView = _buildFocusMonolith(active);
    } else if (_mode == 1) {
      currentView = _buildCacheVault(cached);
    } else {
      currentView = _buildArchiveVault(archived);
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 12, 22),
                child: Column(
                  children: [
                    Expanded(child: currentView),
                    const SizedBox(height: 16),
                    _buildCommandConsole(),
                  ],
                ),
              ),
            ),
            _buildSideMagneticDock(
                active.length, cached.length, archived.length),
          ],
        ),
      ),
    );
  }
}

