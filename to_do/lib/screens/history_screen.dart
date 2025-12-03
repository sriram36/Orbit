import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, int> _history = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyString = prefs.getString('history_log');
    if (historyString != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(historyString);
        setState(() {
          _history = decoded.map((key, value) {
            try {
              return MapEntry(DateTime.parse(key), value as int);
            } catch (e) {
              debugPrint('Error parsing history date $key: $e');
              return MapEntry(DateTime.now(), 0);
            }
          });
        });
      } catch (e) {
        debugPrint('Error loading history: $e');
      }
    }
  }

  List<int> _getEventsForDay(DateTime day) {
    // Normalize date to remove time component
    final normalizedDay = DateTime(day.year, day.month, day.day);
    // Find entry matching this date
    final entry = _history.entries.firstWhere(
      (e) => isSameDay(e.key, normalizedDay),
      orElse: () => MapEntry(normalizedDay, -1),
    );

    if (entry.value != -1) {
      return [entry.value];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'History',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  }
                },
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                eventLoader: _getEventsForDay,
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return null;
                    final int progress = events.first as int;
                    Color color = Colors.grey;
                    if (progress == 100) {
                      color = Colors.green;
                    } else if (progress > 0) {
                      color = Colors.orange;
                    }

                    return Positioned(
                      bottom: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                        width: 8.0,
                        height: 8.0,
                      ),
                    );
                  },
                  defaultBuilder: (context, day, focusedDay) {
                    final normalizedDay =
                        DateTime(day.year, day.month, day.day);
                    final entry = _history.entries.firstWhere(
                      (e) => isSameDay(e.key, normalizedDay),
                      orElse: () => MapEntry(normalizedDay, -1),
                    );

                    if (entry.value != -1) {
                      Color bgColor = Colors.transparent;
                      Color textColor =
                          Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;

                      if (entry.value == 100) {
                        bgColor = Colors.green.withValues(alpha: 0.2);
                        textColor = Colors.green;
                      } else if (entry.value > 0) {
                        bgColor = Colors.orange.withValues(alpha: 0.2);
                        textColor = Colors.orange;
                      }

                      return Container(
                        margin: const EdgeInsets.all(4.0),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                              color: textColor, fontWeight: FontWeight.bold),
                        ),
                      );
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Wrap(
                  alignment: WrapAlignment.spaceAround,
                  spacing: 20,
                  runSpacing: 10,
                  children: [
                    _buildLegendItem(Colors.green, 'Perfect Day'),
                    _buildLegendItem(Colors.orange, 'In Progress'),
                    _buildLegendItem(Colors.grey, 'Missed'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
