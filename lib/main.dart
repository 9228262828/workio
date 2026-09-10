import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WorkioApp());
}

enum TaskState { todo, progress, done }

enum Priority { low, medium, high, urgent }

class TaskItem {
  String id, title, note;
  TaskState state;
  Priority priority;
  DateTime created;
  DateTime? due;

  TaskItem({
    required this.id,
    required this.title,
    this.note = '',
    this.state = TaskState.todo,
    this.priority = Priority.medium,
    required this.created,
    this.due,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'state': state.name,
    'priority': priority.name,
    'created': created.toIso8601String(),
    'due': due?.toIso8601String(),
  };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
    id: j['id'] ?? '',
    title: j['title'] ?? '',
    note: j['note'] ?? '',
    state: TaskState.values.firstWhere(
      (e) => e.name == j['state'],
      orElse: () => TaskState.todo,
    ),
    priority: Priority.values.firstWhere(
      (e) => e.name == j['priority'],
      orElse: () => Priority.medium,
    ),
    created: DateTime.tryParse(j['created'] ?? '') ?? DateTime.now(),
    due: j['due'] == null ? null : DateTime.tryParse(j['due']),
  );
}

class Meeting {
  String id, title, person, note;
  DateTime when;

  Meeting({
    required this.id,
    required this.title,
    this.person = '',
    this.note = '',
    required this.when,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'person': person,
    'note': note,
    'when': when.toIso8601String(),
  };

  factory Meeting.fromJson(Map<String, dynamic> j) => Meeting(
    id: j['id'] ?? '',
    title: j['title'] ?? '',
    person: j['person'] ?? '',
    note: j['note'] ?? '',
    when: DateTime.tryParse(j['when'] ?? '') ?? DateTime.now(),
  );
}

class NoteItem {
  String id, text;
  DateTime date;

  NoteItem(this.id, this.text, this.date);

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'date': date.toIso8601String(),
  };

  factory NoteItem.fromJson(Map<String, dynamic> j) => NoteItem(
    j['id'] ?? '',
    j['text'] ?? '',
    DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
  );
}

class FollowItem {
  String id, title, person;
  DateTime date;
  bool done;

  FollowItem(this.id, this.title, this.person, this.date, {this.done = false});

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'person': person,
    'date': date.toIso8601String(),
    'done': done,
  };

  factory FollowItem.fromJson(Map<String, dynamic> j) => FollowItem(
    j['id'] ?? '',
    j['title'] ?? '',
    j['person'] ?? '',
    DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
    done: j['done'] ?? false,
  );
}

class Session {
  String id;
  DateTime start;
  DateTime? end;
  int breaks;

  Session(this.id, this.start, {this.end, this.breaks = 0});

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': start.toIso8601String(),
    'end': end?.toIso8601String(),
    'breaks': breaks,
  };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
    j['id'] ?? '',
    DateTime.tryParse(j['start'] ?? '') ?? DateTime.now(),
    end: j['end'] == null ? null : DateTime.tryParse(j['end']),
    breaks: j['breaks'] ?? 0,
  );
}

class Store extends ChangeNotifier {
  bool ready = false, dark = false;
  final tasks = <TaskItem>[],
      meetings = <Meeting>[],
      notes = <NoteItem>[],
      follows = <FollowItem>[],
      sessions = <Session>[];

  String id() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    dark = p.getBool('w_dark') ?? false;
    try {
      tasks.addAll(
        (jsonDecode(p.getString('w_tasks') ?? '[]') as List).map(
          (e) => TaskItem.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
      meetings.addAll(
        (jsonDecode(p.getString('w_meet') ?? '[]') as List).map(
          (e) => Meeting.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
      notes.addAll(
        (jsonDecode(p.getString('w_notes') ?? '[]') as List).map(
          (e) => NoteItem.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
      follows.addAll(
        (jsonDecode(p.getString('w_follow') ?? '[]') as List).map(
          (e) => FollowItem.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
      sessions.addAll(
        (jsonDecode(p.getString('w_sessions') ?? '[]') as List).map(
          (e) => Session.fromJson(Map<String, dynamic>.from(e)),
        ),
      );
    } catch (_) {}
    ready = true;
    notifyListeners();
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('w_dark', dark);
    await p.setString(
      'w_tasks',
      jsonEncode(tasks.map((e) => e.toJson()).toList()),
    );
    await p.setString(
      'w_meet',
      jsonEncode(meetings.map((e) => e.toJson()).toList()),
    );
    await p.setString(
      'w_notes',
      jsonEncode(notes.map((e) => e.toJson()).toList()),
    );
    await p.setString(
      'w_follow',
      jsonEncode(follows.map((e) => e.toJson()).toList()),
    );
    await p.setString(
      'w_sessions',
      jsonEncode(sessions.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  Session? get active {
    for (final s in sessions.reversed) {
      if (s.end == null) return s;
    }
    return null;
  }

  int get done => tasks.where((e) => e.state == TaskState.done).length;

  int get open => tasks.where((e) => e.state != TaskState.done).length;

  int get overdue => tasks
      .where(
        (e) =>
            e.state != TaskState.done &&
            e.due != null &&
            e.due!.isBefore(DateTime.now()),
      )
      .length;

  double get completion => tasks.isEmpty ? 0 : done / tasks.length * 100;

  Future<void> reset() async {
    tasks.clear();
    meetings.clear();
    notes.clear();
    follows.clear();
    sessions.clear();
    await save();
  }
}

const blue = Color(0xff5267F7),
    mint = Color(0xff20C997),
    orange = Color(0xffFF9F43),
    red = Color(0xffFF5D6C);

String date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String time(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

Color pcolor(Priority p) => p == Priority.low
    ? mint
    : p == Priority.medium
    ? blue
    : p == Priority.high
    ? orange
    : red;

class WorkioApp extends StatefulWidget {
  const WorkioApp({super.key});

  @override
  State<WorkioApp> createState() => _App();
}

class _App extends State<WorkioApp> {
  final s = Store();

  @override
  void initState() {
    super.initState();
    s.load();
  }

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WORKIO',
      themeMode: s.dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: blue,
        scaffoldBackgroundColor: const Color(0xffF5F6FA),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: blue,
        scaffoldBackgroundColor: const Color(0xff0D1017),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      home: s.ready ? Shell(s) : const Splash(),
    ),
  );
}

class Splash extends StatelessWidget {
  const Splash({super.key});

  @override
  Widget build(BuildContext c) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 45,
            backgroundColor: blue,
            child: Icon(Icons.work_outline, size: 44, color: Colors.white),
          ),
          SizedBox(height: 18),
          Text(
            'WORKIO',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 5,
            ),
          ),
          Text(
            'OWN YOUR WORKDAY',
            style: TextStyle(
              color: blue,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              fontSize: 10,
            ),
          ),
        ],
      ),
    ),
  );
}

class Shell extends StatefulWidget {
  final Store s;

  const Shell(this.s, {super.key});

  @override
  State<Shell> createState() => _Shell();
}

class _Shell extends State<Shell> {
  int i = 0;

  @override
  Widget build(BuildContext c) {
    final p = [
      Today(widget.s, open: (x) => setState(() => i = x)),
      Tasks(widget.s),
      Meetings(widget.s),
      Notes(widget.s),
      More(widget.s),
    ];
    return Scaffold(
      body: IndexedStack(index: i, children: p),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (x) => setState(() => i = x),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Today',
          ),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Tasks'),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            label: 'Meetings',
          ),
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            label: 'Notes',
          ),
          NavigationDestination(icon: Icon(Icons.tune), label: 'More'),
        ],
      ),
    );
  }
}

class Today extends StatelessWidget {
  final Store s;
  final ValueChanged<int> open;

  const Today(this.s, {super.key, required this.open});

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (_, __) => SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Row(
            children: [
              CircleAvatar(
                backgroundColor: blue,
                child: Icon(Icons.work_outline, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text(
                'WORKIO',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 27),
          const Text(
            'YOUR WORKDAY',
            style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900),
          ),
          Text(date(DateTime.now())),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(colors: [blue, Color(0xff7558E8)]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.active == null ? 'READY TO START' : 'WORKDAY IN PROGRESS',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.active == null
                      ? 'Own your workday.'
                      : 'Started ${time(s.active!.start)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                if (s.active == null)
                  FilledButton.tonalIcon(
                    onPressed: () {
                      s.sessions.add(Session(s.id(), DateTime.now()));
                      s.save();
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('START DAY'),
                  )
                else
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () {
                          s.active!.breaks += 15;
                          s.save();
                        },
                        icon: const Icon(Icons.coffee),
                        label: Text('${s.active!.breaks}m BREAK'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          s.active!.end = DateTime.now();
                          s.save();
                        },
                        child: const Text('END DAY'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: metric('${s.open}', 'OPEN', blue)),
              const SizedBox(width: 8),
              Expanded(child: metric('${s.done}', 'DONE', mint)),
              const SizedBox(width: 8),
              Expanded(child: metric('${s.overdue}', 'OVERDUE', red)),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'OFFICE BOARD',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: shortcut(
                  c,
                  'Tasks',
                  '${s.open} open',
                  Icons.checklist,
                  () => open(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: shortcut(
                  c,
                  'Meetings',
                  '${s.meetings.length} total',
                  Icons.groups,
                  () => open(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: shortcut(
                  c,
                  'Notes',
                  '${s.notes.length} saved',
                  Icons.note_alt,
                  () => open(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: shortcut(
                  c,
                  'Follow-ups',
                  '${s.follows.where((e) => !e.done).length} pending',
                  Icons.reply_all,
                  () => Navigator.push(
                    c,
                    MaterialPageRoute(builder: (_) => Follows(s)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget metric(String v, String l, Color col) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: col.withOpacity(.1),
      borderRadius: BorderRadius.circular(19),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          v,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: col,
          ),
        ),
        Text(
          l,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );

  Widget shortcut(
    BuildContext c,
    String t,
    String sub,
    IconData icon,
    VoidCallback f,
  ) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: f,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: blue),
            const SizedBox(height: 13),
            Text(t, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(sub, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    ),
  );
}

class Tasks extends StatefulWidget {
  final Store s;

  const Tasks(this.s, {super.key});

  @override
  State<Tasks> createState() => _Tasks();
}

class _Tasks extends State<Tasks> {
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: widget.s,
    builder: (_, __) => SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('TASKS')),
        body: widget.s.tasks.isEmpty
            ? const Center(child: Text('No tasks yet.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: widget.s.tasks.length,
                itemBuilder: (_, i) {
                  final t = widget.s.tasks[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 9),
                    child: ListTile(
                      leading: Icon(
                        t.state == TaskState.done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: t.state == TaskState.done
                            ? mint
                            : pcolor(t.priority),
                      ),
                      title: Text(
                        t.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          decoration: t.state == TaskState.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        '${t.priority.name.toUpperCase()}${t.due == null ? '' : ' • ${date(t.due!)}'}${t.note.isEmpty ? '' : '\n${t.note}'}',
                      ),
                      isThreeLine: t.note.isNotEmpty,
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'delete') {
                            widget.s.tasks.remove(t);
                          } else {
                            t.state = TaskState.values.firstWhere(
                              (e) => e.name == v,
                            );
                          }
                          widget.s.save();
                        },
                        itemBuilder: (_) => [
                          ...TaskState.values.map(
                            (e) => PopupMenuItem(
                              value: e.name,
                              child: Text(e.name.toUpperCase()),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('DELETE'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => add(c),
          icon: const Icon(Icons.add),
          label: const Text('TASK'),
        ),
      ),
    ),
  );

  Future<void> add(BuildContext c) async {
    String title = '', note = '';
    Priority pr = Priority.medium;
    DateTime? due;
    final key = GlobalKey<FormState>();
    final ok = await showModalBottomSheet<bool>(
      context: c,
      isScrollControlled: true,
      builder: (x) => StatefulBuilder(
        builder: (x, set) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(x).viewInsets.bottom + 22,
          ),
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'NEW TASK',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Task title'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                    onSaved: (v) => title = v!.trim(),
                  ),
                  const SizedBox(height: 9),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Notes'),
                    onSaved: (v) => note = v?.trim() ?? '',
                  ),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<Priority>(
                    initialValue: pr,
                    items: Priority.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => pr = v!,
                    decoration: const InputDecoration(labelText: 'Priority'),
                  ),
                  ListTile(
                    title: Text(
                      due == null ? 'No due date' : 'Due ${date(due!)}',
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: x,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                        initialDate: due ?? DateTime.now(),
                      );
                      if (d != null) set(() => due = d);
                    },
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (key.currentState!.validate()) {
                          key.currentState!.save();
                          Navigator.pop(x, true);
                        }
                      },
                      child: const Text('ADD TASK'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (ok == true) {
      widget.s.tasks.insert(
        0,
        TaskItem(
          id: widget.s.id(),
          title: title,
          note: note,
          priority: pr,
          created: DateTime.now(),
          due: due,
        ),
      );
      widget.s.save();
    }
  }
}

class Meetings extends StatelessWidget {
  final Store s;

  const Meetings(this.s, {super.key});

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (_, __) => SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('MEETINGS')),
        body: s.meetings.isEmpty
            ? const Center(child: Text('No meetings scheduled.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: s.meetings.length,
                itemBuilder: (_, i) {
                  final m = s.meetings[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 9),
                    child: ListTile(
                      leading: const Icon(Icons.event, color: blue),
                      title: Text(
                        m.title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${date(m.when)} • ${time(m.when)}${m.person.isEmpty ? '' : '\n${m.person}'}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          s.meetings.remove(m);
                          s.save();
                        },
                      ),
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => add(c),
          icon: const Icon(Icons.add),
          label: const Text('MEETING'),
        ),
      ),
    ),
  );

  Future<void> add(BuildContext c) async {
    String title = '', person = '';
    DateTime when = DateTime.now().add(const Duration(hours: 1));
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: c,
      builder: (x) => AlertDialog(
        title: const Text('NEW MEETING'),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
                onSaved: (v) => title = v!.trim(),
              ),
              const SizedBox(height: 9),
              TextFormField(
                decoration: const InputDecoration(labelText: 'With / Team'),
                onSaved: (v) => person = v?.trim() ?? '',
              ),
              const SizedBox(height: 9),
              ListTile(
                title: Text('${date(when)} • ${time(when)}'),
                onTap: () async {
                  final d = await showDatePicker(
                    context: x,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    initialDate: when,
                  );
                  if (d != null)
                    when = DateTime(
                      d.year,
                      d.month,
                      d.day,
                      when.hour,
                      when.minute,
                    );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(x, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                key.currentState!.save();
                Navigator.pop(x, true);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    if (ok == true) {
      s.meetings.add(
        Meeting(id: s.id(), title: title, person: person, when: when),
      );
      s.meetings.sort((a, b) => a.when.compareTo(b.when));
      s.save();
    }
  }
}

class Notes extends StatelessWidget {
  final Store s;

  const Notes(this.s, {super.key});

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (_, __) => SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('QUICK NOTES')),
        body: s.notes.isEmpty
            ? const Center(child: Text('Capture a quick work note.'))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: s.notes.length,
                itemBuilder: (_, i) {
                  final n = s.notes[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.push_pin_outlined, color: blue),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Text(
                              n.text,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            date(n.date),
                            style: const TextStyle(fontSize: 10),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              s.notes.remove(n);
                              s.save();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => add(c),
          icon: const Icon(Icons.add),
          label: const Text('NOTE'),
        ),
      ),
    ),
  );

  Future<void> add(BuildContext c) async {
    String text = '';
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: c,
      builder: (x) => AlertDialog(
        title: const Text('QUICK NOTE'),
        content: Form(
          key: key,
          child: TextFormField(
            maxLines: 5,
            autofocus: true,
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            onSaved: (v) => text = v!.trim(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(x, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                key.currentState!.save();
                Navigator.pop(x, true);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    if (ok == true) {
      s.notes.insert(0, NoteItem(s.id(), text, DateTime.now()));
      s.save();
    }
  }
}

class Follows extends StatelessWidget {
  final Store s;

  const Follows(this.s, {super.key});

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (_, __) => Scaffold(
      appBar: AppBar(title: const Text('FOLLOW-UPS')),
      body: s.follows.isEmpty
          ? const Center(child: Text('No follow-ups yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: s.follows.length,
              itemBuilder: (_, i) {
                final f = s.follows[i];
                return Card(
                  child: CheckboxListTile(
                    value: f.done,
                    onChanged: (_) {
                      f.done = !f.done;
                      s.save();
                    },
                    title: Text(f.title),
                    subtitle: Text('${f.person} • ${date(f.date)}'),
                    secondary: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        s.follows.remove(f);
                        s.save();
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => add(c),
        icon: const Icon(Icons.add),
        label: const Text('FOLLOW-UP'),
      ),
    ),
  );

  Future<void> add(BuildContext c) async {
    String title = '', person = '';
    DateTime d = DateTime.now().add(const Duration(days: 1));
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: c,
      builder: (x) => AlertDialog(
        title: const Text('NEW FOLLOW-UP'),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Follow-up'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
                onSaved: (v) => title = v!.trim(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Person / Client'),
                onSaved: (v) => person = v?.trim() ?? '',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(x, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                key.currentState!.save();
                Navigator.pop(x, true);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    if (ok == true) {
      s.follows.add(FollowItem(s.id(), title, person, d));
      s.save();
    }
  }
}

class More extends StatelessWidget {
  final Store s;

  const More(this.s, {super.key});

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: s,
    builder: (_, __) => SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('MORE')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.reply_all),
                    title: const Text('Follow-ups'),
                    onTap: () => Navigator.push(
                      c,
                      MaterialPageRoute(builder: (_) => Follows(s)),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.insights),
                    title: const Text('Work insights'),
                    subtitle: Text(
                      '${s.completion.toStringAsFixed(0)}% task completion',
                    ),
                    onTap: () => Navigator.push(
                      c,
                      MaterialPageRoute(builder: (_) => Insights(s)),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Work history'),
                    onTap: () => Navigator.push(
                      c,
                      MaterialPageRoute(builder: (_) => History(s)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                value: s.dark,
                onChanged: (v) {
                  s.dark = v;
                  s.save();
                },
                title: const Text('Dark mode'),
                secondary: const Icon(Icons.dark_mode_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Privacy Policy'),
                    leading: const Icon(Icons.privacy_tip_outlined),
                    onTap: () => Navigator.push(
                      c,
                      MaterialPageRoute(
                        builder: (_) => const Legal('Privacy Policy', privacy),
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('Terms & Conditions'),
                    leading: const Icon(Icons.description_outlined),
                    onTap: () => Navigator.push(
                      c,
                      MaterialPageRoute(
                        builder: (_) =>
                            const Legal('Terms & Conditions', terms),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                textColor: Colors.redAccent,
                leading: const Icon(Icons.delete_sweep),
                title: const Text('Reset all data'),
                onTap: () => confirm(c),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> confirm(BuildContext c) async {
    final ok = await showDialog<bool>(
      context: c,
      builder: (x) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
          'Tasks, meetings, notes, follow-ups and work history will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(x, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(x, true),
            child: const Text('RESET'),
          ),
        ],
      ),
    );
    if (ok == true) s.reset();
  }
}

class Insights extends StatelessWidget {
  final Store s;

  const Insights(this.s, {super.key});

  @override
  Widget build(BuildContext c) {
    final completed = s.sessions.where((e) => e.end != null);
    final mins = completed.fold<int>(
      0,
      (a, e) => a + e.end!.difference(e.start).inMinutes - e.breaks,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('WORK INSIGHTS')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'WORK SNAPSHOT',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              title: Text(
                '${s.completion.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: blue,
                ),
              ),
              subtitle: const Text('TASK COMPLETION'),
            ),
          ),
          Card(
            child: ListTile(
              title: Text(
                '${s.done} / ${s.tasks.length}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: const Text('COMPLETED TASKS'),
            ),
          ),
          Card(
            child: ListTile(
              title: Text(
                '${mins ~/ 60}h ${mins % 60}m',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: const Text('RECORDED FOCUS TIME'),
            ),
          ),
          Card(
            child: ListTile(
              title: Text(
                '${s.meetings.length}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              subtitle: const Text('MEETINGS'),
            ),
          ),
        ],
      ),
    );
  }
}

class History extends StatelessWidget {
  final Store s;

  const History(this.s, {super.key});

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('WORK HISTORY')),
    body: s.sessions.isEmpty
        ? const Center(child: Text('No work sessions yet.'))
        : ListView(
            padding: const EdgeInsets.all(16),
            children: s.sessions.reversed
                .map(
                  (x) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.work_history),
                      title: Text(
                        date(x.start),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${time(x.start)} → ${x.end == null ? 'In progress' : time(x.end!)} • Break ${x.breaks}m',
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
  );
}

const privacy = '''WORKIO PRIVACY POLICY

WORKIO is an offline-first office work organizer. The current core version does not require an account, login, Firebase, advertising, analytics, or a remote backend.

Tasks, meeting details, quick notes, follow-ups, priorities, work-session times, and preferences entered in WORKIO are stored locally on your device using application storage such as SharedPreferences.

WORKIO does not intentionally sell or rent locally stored work information and does not use it for personalized advertising. The current core version does not provide WORKIO cloud synchronization.

You can delete records inside the app or use Reset All Data. Clearing app data or uninstalling the application may also remove local information, subject to operating-system backup and restore behavior.

Because work notes can contain business information, avoid storing passwords, access tokens, payment credentials, or highly confidential information. Protect your device with appropriate security controls.

The current core version does not require location, camera, microphone, contacts, or payment information for the described features.

If future versions add accounts, cloud storage, collaboration, analytics, advertising, crash reporting, payments, or additional permissions, this policy should be reviewed and updated before release.''';

const terms = '''WORKIO TERMS & CONDITIONS

WORKIO is a personal office work organization tool for tasks, meetings, notes, follow-ups, and work sessions.

WORKIO is not a substitute for an employer's official timekeeping, payroll, compliance, legal, accounting, project-management, or record-retention system.

Work statistics, completion rates, and focus-time figures are informational estimates based on records stored in the app.

The current core version stores its primary information locally. You are responsible for device security, backups where applicable, and the accuracy of information you enter.

We do not guarantee recovery of local information after uninstalling the app, clearing app data, device loss, hardware failure, or certain operating-system changes.

Features may be changed, improved, added, or removed in future releases. Use of WORKIO is subject to applicable laws and app-store terms.''';

class Legal extends StatelessWidget {
  final String title, body;

  const Legal(this.title, this.body, {super.key});

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [SelectableText(body, style: const TextStyle(height: 1.7))],
    ),
  );
}
