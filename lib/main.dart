import 'dart:async';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

/// -------------------------
/// GLOBAL CONSTANTS & HELPERS
/// -------------------------

// Map of available colors (keys are used for dropdown values).
final Map<String, Color> availableColors = {
  'Green': Colors.greenAccent,
  'Blue': Colors.blue,
  'Red': Colors.red,
  'Purple': Colors.purple,
};

// Map of available sound options.
final Map<String, String> availableSounds = {
  'Default': 'default',
  'Chime': 'chime',
  'Beep': 'beep',
};

MaterialColor createMaterialColor(Color color) {
  List<double> strengths = <double>[.05];
  final swatch = <int, Color>{};
  final int r = color.red, g = color.green, b = color.blue;
  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (final strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}

/// -------------------------
/// THEME CONTROLLER (using Provider)
/// -------------------------
class ThemeController extends ChangeNotifier {
  String _selectedColorKey = 'Green';
  int _snoozeDurationSetting = 2;
  String _selectedSoundKey = 'Default';

  String get selectedColorKey => _selectedColorKey;
  int get snoozeDurationSetting => _snoozeDurationSetting;
  String get selectedSoundKey => _selectedSoundKey;

  Color get primaryColor => availableColors[_selectedColorKey]!;

  void updateTheme({String? colorKey, int? snooze, String? soundKey}) {
    if (colorKey != null) _selectedColorKey = colorKey;
    if (snooze != null) _snoozeDurationSetting = snooze;
    if (soundKey != null) _selectedSoundKey = soundKey;
    notifyListeners();
  }
}

/// -------------------------
/// MODEL: ALARM
/// -------------------------
class Alarm {
  int id;
  DateTime time;
  String name;
  bool active;
  Alarm({
    required this.id,
    required this.time,
    required this.name,
    this.active = true,
  });
}

/// -------------------------
/// GLOBAL VARIABLES FOR ALARMS & NOTIFICATIONS
/// -------------------------
int nextAlarmId = 1;
Map<int, Alarm> scheduledAlarms = {}; // alarm id -> Alarm object
int? currentAlarmId; // id of the alarm currently firing

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// -------------------------
/// NOTIFICATION CHANNEL & ALARM CALLBACK
/// -------------------------
Future<void> createNotificationChannel() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'alarm_channel', // id
    'Alarm Notifications', // name
    description: 'Channel for alarm notifications',
    importance: Importance.max,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

@pragma('vm:entry-point')
void alarmCallback() {
  WidgetsFlutterBinding.ensureInitialized();
  final DateTime now = DateTime.now();
  String alarmLabel = 'Alarm';
  // Find an active alarm due.
  for (var alarm in scheduledAlarms.values) {
    if (alarm.active &&
        (alarm.time.isBefore(now) ||
            alarm.time.difference(now) < const Duration(seconds: 1))) {
      currentAlarmId = alarm.id;
      alarmLabel = alarm.name;
      break;
    }
  }
  print('Alarm callback executed. Alarm: $alarmLabel');

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'alarm_channel',
    'Alarm Notifications',
    channelDescription: 'Channel for alarm notifications',
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: true,
  );
  final NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails);

  flutterLocalNotificationsPlugin.show(
    0,
    alarmLabel,
    'Time to wake up!',
    notificationDetails,
    payload: 'alarm_payload',
  );
}

/// -------------------------
/// MAIN
/// -------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  await createNotificationChannel();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_notification');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload == 'alarm_payload') {
        navigatorKey.currentState?.pushNamed('/alarm');
      }
    },
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeController(),
      child: const AlarmApp(),
    ),
  );
}

/// -------------------------
/// MAIN APP WITH THEME CONTROLLER (Light Theme Only)
/// -------------------------
class AlarmApp extends StatelessWidget {
  const AlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeController>(
      builder: (context, themeController, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Saher Qaid Test Alarm',
          navigatorKey: navigatorKey,
          theme: ThemeData.light().copyWith(
            useMaterial3: true,
            primaryColor: themeController.primaryColor,
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeController.primaryColor,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: AppBarTheme(
              backgroundColor: themeController.primaryColor,
              centerTitle: true,
              elevation: 4,
              titleTextStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              backgroundColor: themeController.primaryColor,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            textTheme: ThemeData.light().textTheme.apply(
                  bodyColor: Colors.black,
                  displayColor: Colors.black,
                ),
          ),
          initialRoute: '/welcome',
          routes: {
            '/welcome': (context) => const WelcomePage(),
            '/home': (context) => const AlarmListPage(),
            '/add-alarm': (context) => const AddAlarmPage(),
            '/edit-alarm': (context) => const EditAlarmPage(),
            '/alarm': (context) => const AlarmPage(),
            '/settings': (context) => const SettingsPage(),
          },
        );
      },
    );
  }
}

/// -------------------------
/// WELCOME PAGE
/// -------------------------
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Light gradient background.
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00C853), Color(0xFFB9F6CA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top icon to quickly go to the app.
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.apps, color: Colors.white, size: 30),
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/home');
                  },
                ),
              ),
              const Spacer(),
              const Text(
                'Welcome to\nSaher Qaid Test Alarm',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/home');
                },
                child: const Text('Enter App'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// -------------------------
/// ALARM LIST PAGE
/// -------------------------
class AlarmListPage extends StatefulWidget {
  const AlarmListPage({super.key});

  @override
  _AlarmListPageState createState() => _AlarmListPageState();
}

class _AlarmListPageState extends State<AlarmListPage> {
  final List<Alarm> alarms = [];

  @override
  void initState() {
    super.initState();
    // Load alarms from persistent storage if needed.
  }

  Future<void> _deleteAlarm(Alarm alarm) async {
    await AndroidAlarmManager.cancel(alarm.id);
    scheduledAlarms.remove(alarm.id);
    setState(() {
      alarms.removeWhere((a) => a.id == alarm.id);
    });
  }

  void _editAlarm(Alarm alarm) async {
    final updatedAlarm =
        await Navigator.of(context).pushNamed('/edit-alarm', arguments: alarm);
    if (updatedAlarm != null && updatedAlarm is Alarm) {
      setState(() {
        final index = alarms.indexWhere((a) => a.id == updatedAlarm.id);
        if (index != -1) {
          alarms[index] = updatedAlarm;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Alarms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).pushNamed('/settings');
            },
          )
        ],
      ),
      body: alarms.isEmpty
          ? const Center(
              child: Text('No alarms scheduled.',
                  style: TextStyle(fontSize: 18, color: Colors.black)),
            )
          : ListView.builder(
              itemCount: alarms.length,
              itemBuilder: (context, index) {
                final alarm = alarms[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  child: ListTile(
                    title: Text(alarm.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.black)),
                    subtitle: Text(
                        '${alarm.time.hour.toString().padLeft(2, '0')}:${alarm.time.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.black54)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.edit, color: Colors.blueAccent),
                          onPressed: () => _editAlarm(alarm),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _deleteAlarm(alarm),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: themeController.primaryColor,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.of(context).pushNamed('/add-alarm').then((newAlarm) {
            if (newAlarm != null && newAlarm is Alarm) {
              setState(() {
                alarms.add(newAlarm);
              });
            }
          });
        },
      ),
    );
  }
}

/// -------------------------
/// ADD ALARM PAGE
/// -------------------------
class AddAlarmPage extends StatefulWidget {
  const AddAlarmPage({super.key});

  @override
  _AddAlarmPageState createState() => _AddAlarmPageState();
}

class _AddAlarmPageState extends State<AddAlarmPage> {
  TimeOfDay _selectedTime = TimeOfDay.now();
  final TextEditingController _nameController = TextEditingController();

  Future<void> _selectTime(BuildContext context) async {
    final themeController =
        Provider.of<ThemeController>(context, listen: false);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: themeController.primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black54,
            ),
            timePickerTheme: TimePickerThemeData(
              entryModeIconColor: themeController.primaryColor,
              dialBackgroundColor: Colors.grey[200],
              hourMinuteTextColor: Colors.green[400],
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<Alarm?> _scheduleAlarm() async {
    final DateTime now = DateTime.now();
    DateTime scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    final alarm = Alarm(
      id: nextAlarmId++,
      time: scheduledTime,
      name: _nameController.text.isNotEmpty
          ? _nameController.text
          : 'Alarm $nextAlarmId',
    );

    final Duration delay = scheduledTime.difference(now);
    final bool scheduled = await AndroidAlarmManager.oneShot(
      delay,
      alarm.id,
      alarmCallback,
      alarmClock: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    if (scheduled) {
      scheduledAlarms[alarm.id] = alarm;
      return alarm;
    } else {
      return null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Alarm'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                labelText: 'Alarm Name',
                labelStyle: TextStyle(color: Colors.black54),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Selected Time:',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black)),
                Text(_selectedTime.format(context),
                    style: const TextStyle(fontSize: 18, color: Colors.black)),
                ElevatedButton(
                  onPressed: () => _selectTime(context),
                  child: const Text('Change'),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                final alarm = await _scheduleAlarm();
                if (alarm != null) {
                  Navigator.of(context).pop(alarm);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to set alarm.')));
                }
              },
              child: const Text('Save Alarm'),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------------
/// EDIT ALARM PAGE
/// -------------------------
class EditAlarmPage extends StatefulWidget {
  const EditAlarmPage({super.key});

  @override
  _EditAlarmPageState createState() => _EditAlarmPageState();
}

class _EditAlarmPageState extends State<EditAlarmPage> {
  late Alarm alarm;
  late TimeOfDay _selectedTime;
  late TextEditingController _nameController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    alarm = ModalRoute.of(context)!.settings.arguments as Alarm;
    _selectedTime = TimeOfDay.fromDateTime(alarm.time);
    _nameController = TextEditingController(text: alarm.name);
  }

  Future<void> _selectTime(BuildContext context) async {
    final themeController =
        Provider.of<ThemeController>(context, listen: false);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: themeController.primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black54,
            ),
            timePickerTheme: TimePickerThemeData(
              dialBackgroundColor: Colors.grey[200],
              hourMinuteTextColor: themeController.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<bool> _updateAlarm() async {
    await AndroidAlarmManager.cancel(alarm.id);
    final DateTime now = DateTime.now();
    DateTime scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    alarm.time = scheduledTime;
    alarm.name =
        _nameController.text.isNotEmpty ? _nameController.text : alarm.name;
    final Duration delay = scheduledTime.difference(now);
    final bool scheduled = await AndroidAlarmManager.oneShot(
      delay,
      alarm.id,
      alarmCallback,
      alarmClock: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
    if (scheduled) {
      scheduledAlarms[alarm.id] = alarm;
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Alarm'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                labelText: 'Alarm Name',
                labelStyle: TextStyle(color: Colors.black54),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Selected Time:',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black)),
                Text(_selectedTime.format(context),
                    style: const TextStyle(fontSize: 18, color: Colors.black)),
                ElevatedButton(
                  onPressed: () => _selectTime(context),
                  child: const Text('Change'),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                bool updated = await _updateAlarm();
                if (updated) {
                  Navigator.of(context).pop(alarm);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to update alarm.')));
                }
              },
              child: const Text('Update Alarm'),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------------
/// ALARM PAGE (FULL-SCREEN)
/// -------------------------
class AlarmPage extends StatelessWidget {
  const AlarmPage({super.key});

  @override
  Widget build(BuildContext context) {
    String alarmLabel = 'Alarm';
    if (currentAlarmId != null && scheduledAlarms.containsKey(currentAlarmId)) {
      alarmLabel = scheduledAlarms[currentAlarmId]!.name;
    }
    final themeController = Provider.of<ThemeController>(context);
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00C853), Color(0xFFB9F6CA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.alarm, size: 80, color: Colors.white),
              const SizedBox(height: 20),
              Text(
                alarmLabel,
                style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      AndroidAlarmManager.cancel(0); // Adjust id as needed.
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeController.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(130, 50),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final Duration snoozeDuration = Duration(
                          minutes: themeController.snoozeDurationSetting);
                      bool snoozed = await AndroidAlarmManager.oneShot(
                        snoozeDuration,
                        0,
                        alarmCallback,
                        alarmClock: true,
                        wakeup: true,
                        rescheduleOnReboot: true,
                      );
                      if (snoozed) {
                        Navigator.of(context).pop();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Failed to snooze alarm.')));
                      }
                    },
                    icon: const Icon(Icons.snooze),
                    label: const Text('Snooze'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeController.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(130, 50),
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

/// -------------------------
/// SETTINGS PAGE
/// -------------------------
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String selectedColorKeyLocal;
  late int selectedSnooze;
  late String selectedSoundKeyLocal;

  @override
  void initState() {
    super.initState();
    final themeController =
        Provider.of<ThemeController>(context, listen: false);
    selectedColorKeyLocal = themeController.selectedColorKey;
    selectedSnooze = themeController.snoozeDurationSetting;
    selectedSoundKeyLocal = themeController.selectedSoundKey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Primary color selection.
            Row(
              children: [
                const Text(
                  'Primary Color:',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 20),
                DropdownButton<String>(
                  value: selectedColorKeyLocal,
                  items: availableColors.keys.map((key) {
                    return DropdownMenuItem<String>(
                      value: key,
                      child: Text(key),
                    );
                  }).toList(),
                  onChanged: (String? newKey) {
                    if (newKey != null) {
                      setState(() {
                        selectedColorKeyLocal = newKey;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Snooze duration selection.
            Row(
              children: [
                const Text(
                  'Snooze Duration (min):',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 20),
                DropdownButton<int>(
                  value: selectedSnooze,
                  items: List.generate(5, (index) => index + 1)
                      .map((min) => DropdownMenuItem<int>(
                            value: min,
                            child: Text('$min'),
                          ))
                      .toList(),
                  onChanged: (int? newDuration) {
                    if (newDuration != null) {
                      setState(() {
                        selectedSnooze = newDuration;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Alarm sound selection.
            Row(
              children: [
                const Text(
                  'Alarm Sound:',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 20),
                DropdownButton<String>(
                  value: selectedSoundKeyLocal,
                  items: availableSounds.keys.map((key) {
                    return DropdownMenuItem<String>(
                      value: key,
                      child: Text(key),
                    );
                  }).toList(),
                  onChanged: (String? newSound) {
                    if (newSound != null) {
                      setState(() {
                        selectedSoundKeyLocal = newSound;
                      });
                    }
                  },
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                Provider.of<ThemeController>(context, listen: false)
                    .updateTheme(
                  colorKey: selectedColorKeyLocal,
                  snooze: selectedSnooze,
                  soundKey: selectedSoundKeyLocal,
                );
                Navigator.of(context).pop();
              },
              child: const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
