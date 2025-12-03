import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import 'package:flutter/services.dart';
import 'settings_screen.dart';
import 'history_screen.dart';
import 'checklist_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HomeScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentTheme;

  const HomeScreen({
    super.key,
    required this.onThemeChanged,
    required this.currentTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _notes = [];
  List<String> _categories = ['All', 'Work', 'Personal', 'Health'];
  String _selectedCategory = 'All';
  bool _isGridMode = true;
  int _streak = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadCategories();
    _loadViewMode();
    _checkStreak();
    NotificationService().requestPermissions();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGridMode = prefs.getBool('isGridMode') ?? true;
    });
  }

  Future<void> _saveViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isGridMode', _isGridMode);
  }

  Future<void> _checkStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final int streak = prefs.getInt('streak') ?? 0;
    final String? lastCompletionStr = prefs.getString('last_completion_date');

    if (lastCompletionStr != null) {
      try {
        final lastCompletionRaw = DateTime.parse(lastCompletionStr);
        // Normalize to midnight for fair comparison
        final lastCompletion = DateTime(lastCompletionRaw.year, lastCompletionRaw.month, lastCompletionRaw.day);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));

        if (lastCompletion.isBefore(yesterday)) {
        setState(() => _streak = 0);
        await prefs.setInt('streak', 0);
      } else {
        setState(() => _streak = streak);
        }
      } catch (e) {
        debugPrint('Error parsing last completion date: $e');
        setState(() => _streak = 0);
        await prefs.remove('last_completion_date');
      }
    } else {
      setState(() => _streak = 0);
    }
  }

  Future<void> _updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastCompletionStr = prefs.getString('last_completion_date');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lastCompletionStr != null) {
      try {
        final lastCompletionRaw = DateTime.parse(lastCompletionStr);
        final lastCompletion = DateTime(lastCompletionRaw.year, lastCompletionRaw.month, lastCompletionRaw.day);
        if (lastCompletion.isAtSameMomentAs(today)) {
          return;
        }
      } catch (e) {
        debugPrint('Error parsing last completion date in update: $e');
      }
    }

    setState(() {
      _streak++;
    });
    HapticFeedback.lightImpact();
    await prefs.setInt('streak', _streak);
    await prefs.setString('last_completion_date', today.toIso8601String());
    await WidgetService.updateStreak(_streak);

    final String? historyString = prefs.getString('history_log');
    Map<String, dynamic> history = {};
    if (historyString != null) {
      history = jsonDecode(historyString);
    }
    history[today.toIso8601String()] = 100;
    await prefs.setString('history_log', jsonEncode(history));
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesString = prefs.getString('notes');
    if (notesString != null) {
      try {
        setState(() {
          _notes = List<Map<String, dynamic>>.from(jsonDecode(notesString));
          _sortNotes();
        });

        bool anyCompleted = false;
        for (var note in _notes) {
          final items = note['items'];
          if (items != null && items is List && items.isNotEmpty) {
            final progress = _calculateProgress(items);
            if (progress == 1.0) {
              anyCompleted = true;
              break;
            }
          }
        }

        if (anyCompleted) {
          _updateStreak();
        }
      } catch (e) {
        debugPrint('Error loading notes: $e');
      }
    }
  }

  Future<void> _addNote() async {
    setState(() {
      _notes.add({
        'id': DateTime.now().microsecondsSinceEpoch,
        'title': 'New Routine',
        'items': [],
        'color': Colors.blue.toARGB32(),
        'isPinned': false,
        'category': _selectedCategory == 'All' ? 'Personal' : _selectedCategory,
      });
      _sortNotes();
    });
    _saveNotes();
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('notes', jsonEncode(_notes));
  }

  Future<void> _deleteNote(Map<String, dynamic> note,
      {bool confirm = false}) async {
    SystemSound.play(SystemSoundType.click);
    bool shouldDelete = confirm;

    if (!shouldDelete) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Routine?'),
          content: Text('Are you sure you want to delete "${note['title']}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      shouldDelete = result ?? false;
    }

    if (shouldDelete) {
      setState(() {
        _notes.removeWhere((n) => n['id'] == note['id']);
      });
      _saveNotes();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${note['title']}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              setState(() {
                _notes.add(note);
                _sortNotes();
              });
              _saveNotes();
            },
          ),
        ),
      );

      final items = note['items'];
      if (items != null && items is List) {
        for (var item in items) {
          if (item['notifyTime'] != null) {
            NotificationService().cancelNotification(item['id']);
          }
        }
      }
    }
  }

  void _sortNotes() {
    _notes.sort((a, b) {
      if (a['isPinned'] == true && b['isPinned'] != true) return -1;
      if (a['isPinned'] != true && b['isPinned'] == true) return 1;
      return 0;
    });
  }

  void _togglePin(Map<String, dynamic> note) {
    setState(() {
      note['isPinned'] = !(note['isPinned'] ?? false);
      _sortNotes();
    });
    _saveNotes();
  }

  void _changeColor(Map<String, dynamic> note, int colorValue) {
    setState(() {
      note['color'] = colorValue;
    });
    _saveNotes();
    Navigator.pop(context);
  }

  void _showEditSheet(Map<String, dynamic> note) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      note['title'],
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    note['isPinned'] == true
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20),
              ),
              title: Text(
                note['isPinned'] == true ? 'Unpin Routine' : 'Pin Routine',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _togglePin(note);
              },
            ),
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.category_outlined,
                    color: Colors.purple, size: 20),
              ),
              title: Text(
                'Change Category',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _showCategoryPicker(note);
              },
            ),
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.color_lens_outlined,
                    color: Colors.blue, size: 20),
              ),
              title: Text(
                'Change Color',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _showColorPicker(note);
              },
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 20),
              ),
              title: Text(
                'Delete Routine',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteNote(note);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(Map<String, dynamic> note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _categories.map((category) {
            return ListTile(
              title: Text(category),
              leading: Radio<String>(
                value: category,
                groupValue: note['category'] ?? 'All',
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      note['category'] = value;
                    });
                    _saveNotes();
                    Navigator.pop(context);
                  }
                },
              ),
              onTap: () {
                setState(() {
                  note['category'] = category;
                });
                _saveNotes();
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showColorPicker(Map<String, dynamic> note) {
    final colors = [
      Colors.blue.toARGB32(),
      Colors.red.toARGB32(),
      Colors.green.toARGB32(),
      Colors.orange.toARGB32(),
      Colors.purple.toARGB32(),
      Colors.teal.toARGB32(),
      Colors.pink.toARGB32(),
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a Color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((colorVal) {
            return GestureDetector(
              onTap: () => _changeColor(note, colorVal),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(colorVal),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: note['color'] == colorVal
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Category Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _categories.add(controller.text);
                });
                _saveCategories();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(String category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Delete "$category"? Routines will be moved to "All".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _categories.remove(category);
                if (_selectedCategory == category) {
                  _selectedCategory = 'All';
                }
                for (var note in _notes) {
                  if (note['category'] == category) {
                    note['category'] = 'All';
                  }
                }
              });
              _saveCategories();
              _saveNotes();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('categories', _categories);
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('categories');
    if (saved != null) {
      setState(() {
        _categories = saved;
      });
    }
  }

  double _calculateProgress(List items) {
    if (items.isEmpty) return 0.0;
    int checkedCount = items.where((item) => item['checked'] == true).length;
    return checkedCount / items.length;
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotes = _selectedCategory == 'All'
        ? _notes
        : _notes
            .where((n) => (n['category'] ?? 'All') == _selectedCategory)
            .toList();

    // KeyedSubtree allows the ReorderableBuilder to track widgets correctly
    final children = List.generate(filteredNotes.length, (index) {
      final note = filteredNotes[index];
      final items = note['items'];
      final progress = (items != null && items is List) ? _calculateProgress(items) : 0.0;
      final percent = (progress * 100).toInt();

      return KeyedSubtree(
        key: ValueKey(note['id']),
        child: _buildRoutineCard(note, progress, percent, _isGridMode),
      );
    });

    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/icon/icon.jpg',
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Orbit',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF00FFFF),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Stay on track',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF00FFFF),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_month),
                    title: const Text('History'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const HistoryScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Settings'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsScreen(
                            onThemeChanged: widget.onThemeChanged,
                            currentTheme: widget.currentTheme,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 32),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'CATEGORIES',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text('Add Category'),
                    onTap: () {
                      Navigator.pop(context);
                      _showAddCategoryDialog();
                    },
                  ),
                  ..._categories
                      .where((c) => c != 'All')
                      .map((category) => ListTile(
                            title: Text(category),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => _deleteCategory(category),
                            ),
                          )),
                ],
              ),
            ),
          ],
        ),
      ),
      body: ReorderableBuilder(
        // Key forces rebuild when switching view modes or categories
        key: ValueKey('${_isGridMode ? 'grid' : 'list'}_$_selectedCategory'),
        scrollController: _scrollController,
        longPressDelay: const Duration(milliseconds: 200),
        enableDraggable: true,
        children: children,
        onReorder: (reorderedListFunction) {
          try {
            setState(() {
              // Apply reordering to filteredNotes
              final reorderedResult =
                  (reorderedListFunction as dynamic)(filteredNotes);
              final reorderedVisibleNotes =
                  List<Map<String, dynamic>>.from(reorderedResult);

              if (_selectedCategory == 'All') {
                // Simple case: just replace the entire list
                _notes = reorderedVisibleNotes;
              } else {
                // Complex case: maintain the order of visible notes while preserving other notes
                // Build a map for quick lookup of new positions
                Map<int, int> idToNewIndex = {};
                for (int i = 0; i < reorderedVisibleNotes.length; i++) {
                  idToNewIndex[reorderedVisibleNotes[i]['id']] = i;
                }
                
                // Separate notes into current category and others
                List<Map<String, dynamic>> otherNotes = [];
                List<int> otherIndices = [];
                
                for (int i = 0; i < _notes.length; i++) {
                  if ((_notes[i]['category'] ?? 'All') != _selectedCategory) {
                    otherNotes.add(_notes[i]);
                    otherIndices.add(i);
                  }
                }
                
                // Rebuild the list
                List<Map<String, dynamic>> newNotes = [];
                int visibleIndex = 0;
                int otherIndex = 0;
                
                for (int i = 0; i < _notes.length; i++) {
                  // Check if we should insert from other notes at this position
                  if (otherIndex < otherIndices.length && otherIndices[otherIndex] == i) {
                    newNotes.add(otherNotes[otherIndex]);
                    otherIndex++;
                  } else if (visibleIndex < reorderedVisibleNotes.length) {
                    // Insert from reordered visible notes
                    newNotes.add(reorderedVisibleNotes[visibleIndex]);
                    visibleIndex++;
                  }
                }
                
                // Add any remaining items
                while (visibleIndex < reorderedVisibleNotes.length) {
                  newNotes.add(reorderedVisibleNotes[visibleIndex]);
                  visibleIndex++;
                }
                while (otherIndex < otherNotes.length) {
                  newNotes.add(otherNotes[otherIndex]);
                  otherIndex++;
                }
                
                _notes = newNotes;
              }
            });
            _saveNotes();
          } catch (e) {
            debugPrint("Reordering error: $e");
          }
        },
        builder: (generatedChildren) {
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                title: Text(
                  "My Routines",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: -0.2, end: 0),
                floating: true,
                snap: true,
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department,
                            color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          '$_streak',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      showSearch(
                          context: context,
                          delegate: RoutineSearchDelegate(_notes, (note) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChecklistScreen(
                                  noteId: note['id'],
                                  initialTitle: note['title'],
                                  initialItems: List<Map<String, dynamic>>.from(
                                      note['items']),
                                ),
                              ),
                            ).then((_) => _loadNotes());
                          }));
                    },
                  ),
                  IconButton(
                    icon: Icon(_isGridMode ? Icons.view_list : Icons.grid_view),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _isGridMode = !_isGridMode;
                      });
                      _saveViewMode();
                    },
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: _categories.asMap().entries.map((entry) {
                      final index = entry.key;
                      final category = entry.value;
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                        ),
                      )
                          .animate()
                          .fadeIn(delay: (100 * index).ms, duration: 400.ms)
                          .slideX(begin: 0.2, end: 0);
                    }).toList(),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: _notes.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.checklist_rtl,
                                  size: 64,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.5)),
                              const SizedBox(height: 16),
                              Text("No routines yet",
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              const Text("Tap + to create one",
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    : _isGridMode
                        ? SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => generatedChildren[index],
                              childCount: generatedChildren.length,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 200,
                              childAspectRatio: 0.85,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                          ).animate().fadeIn(duration: 500.ms)
                        : SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => generatedChildren[index],
                              childCount: generatedChildren.length,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 1,
                              mainAxisExtent: 140, // Height of card in list
                              mainAxisSpacing: 12, // Gap between cards
                              crossAxisSpacing: 12,
                            ),
                          ).animate().fadeIn(duration: 500.ms),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.selectionClick();
          _addNote();
        },
        icon: const Icon(Icons.add),
        label: const Text("New Routine"),
      ),
    );
  }

  Widget _buildRoutineCard(
      Map<String, dynamic> note, double progress, int percent, bool isGrid) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor =
        note['color'] != null ? Color(note['color']) : colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Content is separated so it can be wrapped optionally
    final cardContent = Container(
      // No outer margin/padding here! The GridDelegate handles it.
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: isDark ? 0.15 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () async {
            HapticFeedback.lightImpact();
            SystemSound.play(SystemSoundType.click);
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChecklistScreen(
                  noteId: note['id'],
                  initialTitle: note['title'],
                  initialItems: List<Map<String, dynamic>>.from(note['items']),
                ),
              ),
            );
            _loadNotes();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.wb_sunny_rounded,
                          color: cardColor, size: 20),
                    ),
                    if (note['isPinned'] == true)
                      const Icon(Icons.push_pin,
                          size: 18, color: Colors.orange),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _showEditSheet(note),
                      child: Icon(Icons.more_horiz,
                          color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                if (isGrid) const Spacer() else const SizedBox(height: 12),
                Text(
                  note['title'],
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: isGrid ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$percent% Done',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          () {
                            final items = note['items'];
                            if (items == null || items is! List) return '0/0';
                            final checked = items.where((i) => i['checked'] == true).length;
                            return '$checked/${items.length}';
                          }(),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: cardColor.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(cardColor),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Grid Mode: Return content directly
    if (isGrid) {
      return cardContent;
    }

    // List Mode: Return Dismissible directly (no extra padding wrapping it)
    return Dismissible(
      key: Key('dismissible_${note['id']}'), // Different key from parent KeyedSubtree
      background: Container(
        margin: const EdgeInsets.symmetric(
            vertical: 2), // Tiny vertical margin for visual polish
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Icon(Icons.push_pin, color: Colors.orange),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _togglePin(note);
          return false;
        } else {
          return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Routine?'),
              content:
                  Text('Are you sure you want to delete "${note['title']}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          _deleteNote(note, confirm: true);
        }
      },
      child: cardContent,
    );
  }
}

class RoutineSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> notes;
  final Function(Map<String, dynamic>) onNoteTap;

  RoutineSearchDelegate(this.notes, this.onNoteTap);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList();
  }

  Widget _buildList() {
    final results = notes.where((note) {
      final titleMatch =
          note['title'].toString().toLowerCase().contains(query.toLowerCase());
      final items = note['items'];
      final itemMatch = items != null && items is List && items.any((item) =>
          item['text'].toString().toLowerCase().contains(query.toLowerCase()));
      return titleMatch || itemMatch;
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final note = results[index];
        final items = note['items'];
        final taskCount = (items != null && items is List) ? items.length : 0;
        return ListTile(
          title: Text(note['title']),
          subtitle: Text("$taskCount tasks"),
          onTap: () {
            close(context, null);
            onNoteTap(note);
          },
        );
      },
    );
  }
}
