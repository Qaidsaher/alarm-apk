import 'dart:async';
import 'dart:isolate';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Top-level function for the alarm callback
void printHello() {
  final DateTime now = DateTime.now();
  final int isolateId = Isolate.current.hashCode;
  print("[$now] Hello, world! isolate=$isolateId function='$printHello'");
}

/// Global key for navigator access
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// --- Background handler ---
@pragma('vm:entry-point')
void callback() {
  WidgetsFlutterBinding.ensureInitialized();
  print('Alarm fired!');
  _backgroundHandler();
}

Future<void> _backgroundHandler() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final int fireCount = prefs.getInt('fire_count') ?? 0;
  await prefs.setInt('fire_count', fireCount + 1);
  print('Fire Count: $fireCount');

  const AndroidNotificationDetails notificationDetails =
      AndroidNotificationDetails(
    'alarm_channel', // Channel ID
    'Alarm Channel', // Channel name
    channelDescription: 'Channel for Alarm notifications',
    importance: Importance.max,
    priority: Priority.max,
    showWhen: false,
    fullScreenIntent: true,
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: notificationDetails);

  // Show the notification using the custom icon.
  await FlutterLocalNotificationsPlugin().show(
    0,
    'Alarm Fired ($fireCount)',
    'Time to wake up!',
    platformChannelSpecifics,
    payload: 'alarm_payload',
  );

  // Navigate to the alarm page if possible.
  if (navigatorKey.currentState != null) {
    navigatorKey.currentState!.pushNamed('/alarm-page');
  }
}

/// --- Main App ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Use the custom notification icon 'ic_notification'.
  // Make sure you have created ic_notification.png (a simple white, transparent icon)
  // and placed it in your android/app/src/main/res/drawable folder (or in appropriate mipmap directories).
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_notification');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse:
        (NotificationResponse notificationResponse) {
      if (notificationResponse.payload == 'alarm_payload') {
        navigatorKey.currentState?.pushNamed('/alarm-page');
      }
    },
  );

  runApp(const AlarmApp());
}

class AlarmApp extends StatelessWidget {
  const AlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Alarm App',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          elevation: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/alarm-page': (context) => const AlarmPage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _alarmSet = false;
  int _alarmId = 0; // Unique alarm ID

  // Time picker method
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.deepPurple,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            timePickerTheme: const TimePickerThemeData(
              dialBackgroundColor: Colors.white,
              hourMinuteTextColor: Colors.deepPurple,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // Set alarm method
  Future<void> _setAlarm() async {
    final now = DateTime.now();
    DateTime scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // If the scheduled time is in the past, schedule for the next day.
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    try {
      print("Setting alarm...");
      // Calculate the delay until the scheduled time.
      bool alarmSet = await AndroidAlarmManager.oneShot(
        scheduledTime.difference(now),
        _alarmId,
        callback,
        alarmClock: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );

      if (alarmSet) {
        setState(() {
          _alarmSet = true;
          _saveAlarmDetails(scheduledTime, _alarmId);
        });
        _showSnackBar(
            'Alarm set for ${scheduledTime.toLocal().toString().split(".")[0]}');
      } else {
        _showSnackBar('Failed to set alarm.');
      }
    } catch (e) {
      print("Error setting alarm: $e");
      _showSnackBar('Error setting alarm: $e');
    }
  }

  // Save alarm details using SharedPreferences
  Future<void> _saveAlarmDetails(DateTime scheduledTime, int alarmId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('alarm_id', alarmId);
    await prefs.setString('alarm_time', scheduledTime.toIso8601String());
    await prefs.setBool('alarm_set', true);
  }

  // Load alarm details
  Future<void> _loadAlarmDetails() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? savedAlarmId = prefs.getInt('alarm_id');
    final String? savedAlarmTime = prefs.getString('alarm_time');
    final bool? savedAlarmSet = prefs.getBool('alarm_set');

    if (savedAlarmId != null &&
        savedAlarmTime != null &&
        savedAlarmSet != null) {
      setState(() {
        _alarmId = savedAlarmId;
        _selectedTime = TimeOfDay.fromDateTime(DateTime.parse(savedAlarmTime));
        _alarmSet = savedAlarmSet;
      });
    }
  }

  // Cancel the alarm
  Future<void> _cancelAlarm() async {
    try {
      if (await AndroidAlarmManager.cancel(_alarmId)) {
        setState(() {
          _alarmSet = false;
          _clearAlarmDetails();
        });
        _showSnackBar('Alarm cancelled.');
      } else {
        _showSnackBar('Failed to cancel alarm.');
      }
    } catch (e) {
      print("Error cancelling alarm: $e");
      _showSnackBar("Error cancelling alarm: $e");
    }
  }

  // Clear saved alarm details
  Future<void> _clearAlarmDetails() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('alarm_id');
    await prefs.remove('alarm_time');
    await prefs.remove('alarm_set');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAlarmDetails();

    // Check if the app was launched via a notification tap.
    FlutterLocalNotificationsPlugin()
        .getNotificationAppLaunchDetails()
        .then((details) {
      if (details?.didNotificationLaunchApp ?? false) {
        if (details!.notificationResponse?.payload == 'alarm_payload') {
          Navigator.of(context).pushNamed('/alarm-page');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Gradient background for a modern look.
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.indigo],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Header Title
                  const Text(
                    'Set Your Alarm',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Card displaying selected time
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.access_time,
                                  color: Colors.deepPurple, size: 30),
                              const SizedBox(width: 8),
                              Text(
                                _selectedTime.format(context),
                                style: const TextStyle(
                                    fontSize: 28, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _selectTime(context),
                            icon: const Icon(Icons.edit),
                            label: const Text('Change Time'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Set / Cancel Alarm button
                  ElevatedButton.icon(
                    onPressed: _alarmSet ? _cancelAlarm : _setAlarm,
                    icon: Icon(_alarmSet ? Icons.cancel : Icons.alarm),
                    label: Text(_alarmSet ? 'Cancel Alarm' : 'Set Alarm'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_alarmSet)
                    const Text(
                      'Alarm is active!',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Alarm page shown when the alarm goes off.
class AlarmPage extends StatelessWidget {
  const AlarmPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm Ringing'),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.redAccent, Colors.deepOrange],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.alarm, size: 80, color: Colors.white),
            const SizedBox(height: 20),
            const Text(
              'Wake up! Your alarm is ringing!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.check),
              label: const Text('Dismiss'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.redAccent,
                minimumSize: const Size(150, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
