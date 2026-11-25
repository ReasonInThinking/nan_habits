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
  String startIso;
  List<int> doneDays;

  Habit({
    required this.id,
    required this.title,
    required this.totalDays,
    required this.startIso,
    required this.doneDays,
  });

  bool get isCompleted => totalDays > 0 && doneDays.length >= totalDays;

  DateTime get startDate {
    final p = startIso.split('-');
    if (p.length == 3) {
      return DateTime(
        int.tryParse(p.elementAt(0)) ?? DateTime.now().year,
        int.tryParse(p.elementAt(1)) ?? DateTime.now().month,
        int.tryParse(p.elementAt(2)) ?? DateTime.now().day,
      );
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int get todayIndex {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(startDate).inDays;
    return (diff >= 0 && diff < totalDays) ? diff : -1;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'totalDays': totalDays,
        'startIso': startIso,
        'doneDays': doneDays,
      };

  factory Habit.fromJson(Map<String, dynamic> json) {
    final raw = json['doneDays'];
    final list = <int>[];
    if (raw is List) {
      for (final x in raw) {
        if (x is int) list.add(x);
      }
    }
    final now = DateTime.now();
    final fallback =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return Habit(
      id: json['id']?.toString() ?? now.microsecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? 'Импульс',
      totalDays: json['totalDays'] is int ? json['totalDays'] as int : 14,
      startIso: json['startIso']?.toString() ?? fallback,
      doneDays: list,
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
  final Map<String, GlobalKey> _cellKeys = {};
  final Set<int> _touched = {};

  List<Habit> _habits = [];
  int _selectedDays = 14;
  int _mode = 0; // 0 = Активные, 1 = Архив (Завершённые)
  double _dragX = 0;
  bool? _paintMode;

  List<Habit> get _activeList =>
      _habits.where((h) => !h.isCompleted).toList();

  List<Habit> get _completedList =>
      _habits.where((h) => h.isCompleted).toList();

  String get _savePath {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/.nan_habits_reactor.json';
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
    final now = DateTime.now();
    final iso =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    setState(() {
      _habits.insert(
        0,
        Habit(
          id: now.microsecondsSinceEpoch.toString(),
          title: text,
          totalDays: _selectedDays,
          startIso: iso,
          doneDays: <int>[],
        ),
      );
      _input.clear();
      _mode = 0;
      _dragX = 0;
    });
    playSound('message-new-instant');
    _save();
  }


  void _rotateOrbit({required bool forward, bool chargeToday = false}) {
    final active = _activeList;
    if (active.isEmpty) return;

    setState(() {
      _paintMode = null;
      _touched.clear();
      _dragX = 0;

      final current = active.first;
      if (chargeToday) {
        final tIdx = current.todayIndex;
        if (tIdx != -1 && !current.doneDays.contains(tIdx)) {
          current.doneDays.add(tIdx);
        } else {
          for (int i = 0; i < current.totalDays; i++) {
            if (!current.doneDays.contains(i)) {
              current.doneDays.add(i);
              break;
            }
          }
        }
      }

      if (!current.isCompleted && active.length > 1) {
        if (forward) {
          _habits.remove(current);
          _habits.add(current);
        } else {
          final lastActive = active.last;
          _habits.remove(lastActive);
          _habits.insert(0, lastActive);
        }
      }
    });

    playSound(chargeToday ? 'complete' : 'audio-volume-change');
    _save();
  }

  void _paintEnergyCell(Habit current, Offset pos, {required bool isDown}) {
    if (isDown) {
      _paintMode = null;
      _touched.clear();
    }

    for (int i = 0; i < current.totalDays; i++) {
      final key = _cellKeys['${current.id}_$i'];
      final ctx = key?.currentContext;
      if (ctx == null || !ctx.mounted) continue;

      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;

      final local = box.globalToLocal(pos);
      if (local.dx >= 0 &&
          local.dy >= 0 &&
          local.dx <= box.size.width &&
          local.dy <= box.size.height) {
        if (_paintMode == null) {
          _paintMode = !current.doneDays.contains(i);
        }
        if (!_touched.contains(i)) {
          _touched.add(i);
          setState(() {
            if (_paintMode!) {
              if (!current.doneDays.contains(i)) current.doneDays.add(i);
            } else {
              current.doneDays.remove(i);
            }
          });
          playSound(
              current.isCompleted ? 'complete' : 'audio-volume-change');
          _save();
        }
        break;
      }
    }
  }


  Widget _buildSideMagneticDock(int activeCount, int archivedCount) {
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
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
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
                size: 22,
                color: selected ? accent : NeoTheme.textDim,
              ),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 18,
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
                    fontSize: 10,
                    letterSpacing: 1.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
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
          const SizedBox(height: 16),
          capsule(
            idx: 1,
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
      constraints: const BoxConstraints(maxWidth: 680),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: NeoTheme.panel,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: NeoTheme.violet.withOpacity(0.5), width: 1.4),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: NeoTheme.violet.withOpacity(0.16),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: NeoTheme.cyan,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _input,
                  onSubmitted: (_) => _launchHabit(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: NeoTheme.textMain,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Задать новый цикл привычки...',
                    hintStyle: TextStyle(color: NeoTheme.textDim),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _launchHabit,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[NeoTheme.violet, NeoTheme.cyan],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rocket_launch_rounded,
                          size: 16, color: Colors.black),
                      SizedBox(width: 6),
                      Text(
                        'ЗАПУСК',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
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
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 46,
        height: 110,
        decoration: BoxDecoration(
          color: enabled ? NeoTheme.panel : NeoTheme.bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: enabled
                ? NeoTheme.cyan.withOpacity(0.55)
                : NeoTheme.border.withOpacity(0.35),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 28,
          color: enabled ? NeoTheme.cyan : NeoTheme.textDim.withOpacity(0.25),
        ),
      ),
    );
  }

  Widget _buildHologramMonolith(List<Habit> active) {
    if (active.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.blur_circular_rounded,
              size: 64,
              color: NeoTheme.violet.withOpacity(0.6),
            ),
            const SizedBox(height: 14),
            const Text(
              'ОРБИТА СВОБОДНА',
              style: TextStyle(
                fontSize: 16,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w900,
                color: NeoTheme.textMain,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Задайте новый цикл в консоли снизу',
              style: TextStyle(fontSize: 13, color: NeoTheme.textDim),
            ),
          ],
        ),
      );
    }

    final current = active.first;
    final canSwitch = active.length > 1;
    final ratio = current.totalDays > 0
        ? (current.doneDays.length / current.totalDays).clamp(0.0, 1.0)
        : 0.0;
    final percent = (ratio * 100).round();
    final tIdx = current.todayIndex;
    final isTodayDone = tIdx != -1 && current.doneDays.contains(tIdx);


    return Listener(
      onPointerSignal: (e) {
        if (e is PointerScrollEvent && canSwitch) {
          _rotateOrbit(forward: e.scrollDelta.dy > 0);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
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
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Transform.translate(
                    offset: Offset(_dragX, 0),
                    child: Transform.rotate(
                      angle: (_dragX / 1100).clamp(-0.14, 0.14),
                      child: Container(
                        key: ValueKey('holo_${current.id}'),
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[NeoTheme.panel, Color(0xFF0C101B)],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: _dragX.abs() > 25
                                ? NeoTheme.cyan
                                : NeoTheme.violet.withOpacity(0.55),
                            width: 1.6,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: NeoTheme.cyan.withOpacity(0.12),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanUpdate: (d) =>
                                  setState(() => _dragX += d.delta.dx),
                              onPanEnd: (_) {
                                if (_dragX > 90) {
                                  _rotateOrbit(
                                      forward: true, chargeToday: true);
                                } else if (_dragX < -90) {
                                  _rotateOrbit(forward: true);
                                } else {
                                  setState(() => _dragX = 0);
                                }
                              },
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 62,
                                    height: 62,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: ratio,
                                          strokeWidth: 5,
                                          backgroundColor: NeoTheme.panelLight,
                                          valueColor:
                                              const AlwaysStoppedAnimation<
                                                  Color>(NeoTheme.cyan),
                                        ),
                                        Text(
                                          '$percent%',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: NeoTheme.cyan,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'ОРБИТА 1 / ${active.length}  •  ${current.doneDays.length} ИЗ ${current.totalDays}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                letterSpacing: 1.2,
                                                fontWeight: FontWeight.bold,
                                                color: NeoTheme.violet,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isTodayDone
                                                    ? NeoTheme.cyan
                                                        .withOpacity(0.2)
                                                    : NeoTheme.amber
                                                        .withOpacity(0.18),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isTodayDone
                                                    ? 'СЕГОДНЯ ✓'
                                                    : 'ЖДЁТ СЕГОДНЯ',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                  color: isTodayDone
                                                      ? NeoTheme.cyan
                                                      : NeoTheme.amber,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          current.title,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: NeoTheme.textMain,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Удалить',
                                    icon: const Icon(Icons.close_rounded,
                                        color: NeoTheme.textDim),
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
                            ),



                        const SizedBox(height: 22),
                        Listener(
                          onPointerDown: (e) => _paintEnergyCell(
                              current, e.position,
                              isDown: true),
                          onPointerMove: (e) => _paintEnergyCell(
                              current, e.position,
                              isDown: false),
                          onPointerUp: (_) {
                            _paintMode = null;
                            _touched.clear();
                          },
                          child: Wrap(
                            spacing: 9,
                            runSpacing: 9,
                            alignment: WrapAlignment.center,
                            children: List.generate(current.totalDays, (i) {
                              final cellKey = _cellKeys.putIfAbsent(
                                  '${current.id}_$i', () => GlobalKey());
                              final done = current.doneDays.contains(i);
                              final date =
                                  current.startDate.add(Duration(days: i));
                              final now = DateTime.now();
                              final isToday = date.year == now.year &&
                                  date.month == now.month &&
                                  date.day == now.day;
                              const wNames = <String>[
                                'Пн',
                                'Вт',
                                'Ср',
                                'Чт',
                                'Пт',
                                'Сб',
                                'Вс'
                              ];
                              final wDay =
                                  wNames[(date.weekday - 1).clamp(0, 6)];

                              return AnimatedContainer(
                                key: cellKey,
                                duration: const Duration(milliseconds: 160),
                                width: 48,
                                height: 54,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: done
                                      ? const LinearGradient(
                                          colors: <Color>[
                                            NeoTheme.cyan,
                                            NeoTheme.violet,
                                          ],
                                        )
                                      : null,
                                  color: done ? null : NeoTheme.panelLight,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: done
                                        ? NeoTheme.cyan
                                        : (isToday
                                            ? Colors.white
                                            : NeoTheme.border),
                                    width: isToday ? 1.8 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isToday ? 'СЕГ' : wDay,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: done
                                            ? Colors.black87
                                            : (isToday
                                                ? NeoTheme.cyan
                                                : NeoTheme.textDim),
                                      ),
                                    ),
                                    Text(
                                      '${date.day}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: done
                                            ? Colors.black
                                            : NeoTheme.textMain,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
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
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () => _rotateOrbit(forward: true, chargeToday: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
              decoration: BoxDecoration(
                color: isTodayDone
                    ? NeoTheme.panel
                    : NeoTheme.cyan.withOpacity(0.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isTodayDone ? NeoTheme.border : NeoTheme.cyan,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isTodayDone
                        ? Icons.check_circle_rounded
                        : Icons.bolt_rounded,
                    size: 18,
                    color: isTodayDone ? NeoTheme.textDim : NeoTheme.cyan,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isTodayDone ? 'СЕГОДНЯ ЗАРЯЖЕНО' : 'ЗАРЯДИТЬ СЕГОДНЯ',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w900,
                      color: isTodayDone ? NeoTheme.textDim : NeoTheme.cyan,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
              size: 60,
              color: NeoTheme.amber.withOpacity(0.55),
            ),
            const SizedBox(height: 12),
            const Text(
              'АРХИВ ДОСТИЖЕНИЙ ПУСТ',
              style: TextStyle(
                fontSize: 15,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w900,
                color: NeoTheme.textMain,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Зарядите все энергоячейки любого цикла, чтобы перенести его сюда',
              style: TextStyle(fontSize: 13, color: NeoTheme.textDim),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
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
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: NeoTheme.amber.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: NeoTheme.amber,
                      size: 26,
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
                            fontSize: 11,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.bold,
                            color: NeoTheme.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Перезапустить цикл',
                    icon: const Icon(Icons.replay_rounded,
                        color: NeoTheme.cyan),
                    onPressed: () {
                      setState(() {
                        item.doneDays.clear();
                        _mode = 0;
                      });
                      playSound('audio-volume-change');
                      _save();
                    },
                  ),
                  IconButton(
                    tooltip: 'Удалить из архива',
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
    final active = _activeList;
    final archived = _completedList;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 12, 22),
                child: Column(
                  children: [
                    Expanded(
                      child: _mode == 0
                          ? _buildHologramMonolith(active)
                          : _buildArchiveVault(archived),
                    ),
                    const SizedBox(height: 16),
                    _buildCommandConsole(),
                  ],
                ),
              ),
            ),
            _buildSideMagneticDock(active.length, archived.length),
          ],
        ),
      ),
    );
  }
}

