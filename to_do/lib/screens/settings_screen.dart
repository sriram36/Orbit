import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentTheme;

  const SettingsScreen({
    super.key,
    required this.onThemeChanged,
    required this.currentTheme,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TimeOfDay _resetTime = const TimeOfDay(hour: 3, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadResetTime();
  }

  Future<void> _loadResetTime() async {
    final prefs = await SharedPreferences.getInstance();
    final int? hour = prefs.getInt('reset_hour');
    final int? minute = prefs.getInt('reset_minute');
    if (hour != null && minute != null) {
      setState(() {
        _resetTime = TimeOfDay(hour: hour, minute: minute);
      });
    }
  }

  Future<void> _saveResetTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reset_hour', time.hour);
    await prefs.setInt('reset_minute', time.minute);
    setState(() {
      _resetTime = time;
    });
  }

  Future<void> _exportData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesString = prefs.getString('notes');
    if (notesString != null) {
      await Clipboard.setData(ClipboardData(text: notesString));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data copied to clipboard!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('Theme'),
                subtitle: Text(widget.currentTheme == ThemeMode.system
                    ? 'System Default'
                    : widget.currentTheme == ThemeMode.dark
                        ? 'Dark Mode'
                        : 'Light Mode'),
                trailing: DropdownButton<ThemeMode>(
                  value: widget.currentTheme,
                  onChanged: (ThemeMode? newValue) {
                    if (newValue != null) {
                      widget.onThemeChanged(newValue);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Daily Reset Time'),
                subtitle: Text(_resetTime.format(context)),
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: _resetTime,
                  );
                  if (picked != null && picked != _resetTime) {
                    _saveResetTime(picked);
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Export Data'),
                subtitle: const Text('Copy all routines to clipboard'),
                onTap: _exportData,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
