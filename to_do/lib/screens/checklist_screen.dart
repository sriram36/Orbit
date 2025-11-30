import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';

import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';

class ChecklistScreen extends StatefulWidget {
  final int noteId;
  final String initialTitle;
  final List<Map<String, dynamic>> initialItems;

  const ChecklistScreen(
      {super.key,
      required this.noteId,
      required this.initialTitle,
      required this.initialItems});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen>
    with WidgetsBindingObserver {
  late List<Map<String, dynamic>> _items;
  late String _title;
  late ConfettiController _confettiController;
  final TextEditingController _titleController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _items = widget.initialItems;
    _title = widget.initialTitle;
    _titleController.text = _title;
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _checkDailyReset();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confettiController.dispose();
    _titleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDailyReset();
    }
  }

  Future<void> _checkDailyReset() async {
    final prefs = await SharedPreferences.getInstance();
    final lastResetStr = prefs.getString('last_reset_${widget.noteId}');
    final now = DateTime.now();

    final int resetHour = prefs.getInt('reset_hour') ?? 3;
    final int resetMinute = prefs.getInt('reset_minute') ?? 0;

    final todayResetTime =
        DateTime(now.year, now.month, now.day, resetHour, resetMinute);

    if (now.isAfter(todayResetTime)) {
      bool shouldReset = false;

      if (lastResetStr == null) {
        shouldReset = true;
      } else {
        final lastReset = DateTime.parse(lastResetStr);
        if (lastReset.isBefore(todayResetTime)) {
          shouldReset = true;
        }
      }

      if (!mounted) return;

      if (shouldReset) {
        setState(() {
          for (var item in _items) {
            item['checked'] = false;
          }
        });
        await _saveData();
        if (!mounted) return;
        prefs.setString('last_reset_${widget.noteId}', now.toIso8601String());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Daily reset: Tasks unchecked'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesString = prefs.getString('notes');
    if (notesString != null) {
      List<dynamic> allNotes = jsonDecode(notesString);
      final index = allNotes.indexWhere((n) => n['id'] == widget.noteId);
      if (index != -1) {
        allNotes[index]['title'] = _title;
        allNotes[index]['checklistItems'] = _items;
        await prefs.setString('notes', jsonEncode(allNotes));
      }
    }
    if (mounted) {
      _checkCompletion();
    }
  }

  void _checkCompletion() {
    if (!mounted) return;
    if (_items.isNotEmpty && _items.every((item) => item['checked'] == true)) {
      _confettiController.play();
    }
  }

  void _addItem() {
    HapticFeedback.selectionClick();
    setState(() {
      _items.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'text': '',
        'checked': false,
        'isImportant': false,
      });
    });
    _saveData();
  }

  void _addSubtask(Map<String, dynamic> parentItem) {
    HapticFeedback.selectionClick();
    setState(() {
      if (parentItem['subtasks'] == null) {
        parentItem['subtasks'] = [];
      }
      (parentItem['subtasks'] as List).add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'text': 'New Step',
        'checked': false,
      });
    });
    _saveData();
  }

  void _toggleImportant(Map<String, dynamic> item) {
    setState(() {
      item['isImportant'] = !(item['isImportant'] ?? false);
      _sortItems();
    });
    _saveData();
  }

  void _sortItems() {
    _items.sort((a, b) {
      if (a['isImportant'] == true && b['isImportant'] != true) return -1;
      if (a['isImportant'] != true && b['isImportant'] == true) return 1;
      return 0;
    });
  }

  void _toggleTime(int index) async {
    final item = _items[index];
    if (item['notifyTime'] != null) {
      setState(() => item['notifyTime'] = null);
      NotificationService().cancelNotification(item['id']);
    } else {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 8, minute: 0),
      );
      if (picked != null) {
        if (!mounted) return;
        setState(() {
          item['notifyTime'] =
              '${picked.hour}:${picked.minute.toString().padLeft(2, '0')}';
        });
        NotificationService()
            .scheduleDailyNotification(item['id'], item['text'], picked);
      }
    }
    _saveData();
  }

  void _deleteItem(int index) {
    SystemSound.play(SystemSoundType.click);
    final item = _items[index];
    if (item['notifyTime'] != null) {
      NotificationService().cancelNotification(item['id']);
    }
    setState(() {
      _items.removeAt(index);
    });
    _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Task deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _items.insert(index, item);
            });
            _saveData();
            if (item['notifyTime'] != null) {
              // Re-schedule notification logic would go here, simplified for now
            }
          },
        ),
      ),
    );
  }

  Future<void> _deleteRoutine() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Routine?'),
        content: const Text('Are you sure you want to delete this routine?'),
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

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final String? notesString = prefs.getString('notes');
      if (notesString != null) {
        List<dynamic> allNotes = jsonDecode(notesString);
        allNotes.removeWhere((n) => n['id'] == widget.noteId);
        await prefs.setString('notes', jsonEncode(allNotes));

        // Cancel notifications
        for (var item in _items) {
          if (item['notifyTime'] != null) {
            NotificationService().cancelNotification(item['id']);
          }
        }

        if (mounted) {
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = _items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      return Dismissible(
        key: Key(item['id'].toString()),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.delete_outline, color: Colors.red.shade700),
        ),
        confirmDismiss: (direction) async {
          return await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("Delete Task?"),
                content:
                    const Text("Are you sure you want to delete this task?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text("Delete"),
                  ),
                ],
              );
            },
          );
        },
        onDismissed: (direction) => _deleteItem(index),
        child: ChecklistItem(
          item: item,
          index: index,
          onChecked: (val) {
            HapticFeedback.mediumImpact();
            setState(() {
              item['checked'] = val;
            });
            _saveData();
          },
          onTextChanged: (val) {
            item['text'] = val;
            _saveData();
          },
          onDelete: () => _deleteItem(index),
          onToggleTime: () => _toggleTime(index),
          onToggleImportant: () => _toggleImportant(item),
          onAddSubtask: () => _addSubtask(item),
          onSubtaskChecked: (subIndex, val) {
            setState(() {
              (item['subtasks'] as List)[subIndex]['checked'] = val;
            });
            _saveData();
          },
          onSubtaskTextChanged: (subIndex, val) {
            (item['subtasks'] as List)[subIndex]['text'] = val;
            _saveData();
          },
          onSubtaskDelete: (subIndex) {
            setState(() {
              (item['subtasks'] as List).removeAt(subIndex);
            });
            _saveData();
          },
          onFocusChange: (hasFocus) {
            // No-op: Focus change no longer affects reordering
          },
        ),
      );
    }).toList();

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ReorderableBuilder(
                  scrollController: _scrollController,
                  enableDraggable: true,
                  onReorder: (reorderedListFunction) {
                    setState(() {
                      _items = List<Map<String, dynamic>>.from(
                          (reorderedListFunction as dynamic)(_items));
                    });
                    _saveData();
                  },
                  children: children,
                  builder: (generatedChildren) {
                    return CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverAppBar(
                          expandedHeight: 120,
                          pinned: true,
                          actions: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: _deleteRoutine,
                            ),
                          ],
                          flexibleSpace: FlexibleSpaceBar(
                            titlePadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            title: Hero(
                              tag: 'routine_title_${widget.noteId}',
                              child: Material(
                                color: Colors.transparent,
                                child: TextField(
                                  controller: _titleController,
                                  style: GoogleFonts.outfit(
                                    color: Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                  decoration: const InputDecoration(
                                      border: InputBorder.none),
                                  onChanged: (val) {
                                    _title = val;
                                    _saveData();
                                  },
                                  onSubmitted: (val) {
                                    setState(() => _title = val);
                                    _saveData();
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          sliver: SliverList(
                            delegate:
                                SliverChildListDelegate(generatedChildren),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ChecklistItem extends StatefulWidget {
  final Map<String, dynamic> item;
  final int index;
  final Function(bool?) onChecked;
  final Function(String) onTextChanged;
  final VoidCallback onDelete;
  final VoidCallback onToggleTime;
  final VoidCallback onToggleImportant;
  final VoidCallback onAddSubtask;
  final Function(int, bool?) onSubtaskChecked;
  final Function(int, String) onSubtaskTextChanged;
  final Function(int) onSubtaskDelete;
  final Function(bool) onFocusChange;

  const ChecklistItem({
    super.key,
    required this.item,
    required this.index,
    required this.onChecked,
    required this.onTextChanged,
    required this.onDelete,
    required this.onToggleTime,
    required this.onToggleImportant,
    required this.onAddSubtask,
    required this.onSubtaskChecked,
    required this.onSubtaskTextChanged,
    required this.onSubtaskDelete,
    required this.onFocusChange,
  });

  @override
  State<ChecklistItem> createState() => _ChecklistItemState();
}

class _ChecklistItemState extends State<ChecklistItem> {
  late TextEditingController _controller;
  final Map<int, TextEditingController> _subtaskControllers = {};
  final Map<int, FocusNode> _subtaskFocusNodes = {};
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item['text']);
    _initializeSubtaskControllers();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    widget.onFocusChange(_focusNode.hasFocus);
    if (!_focusNode.hasFocus) {
      widget.onTextChanged(_controller.text);
    }
  }

  void _initializeSubtaskControllers() {
    if (widget.item['subtasks'] != null) {
      final subtasks = widget.item['subtasks'] as List;

      // Cleanup unused controllers and focus nodes
      _subtaskControllers.removeWhere((key, value) => key >= subtasks.length);
      _subtaskFocusNodes.removeWhere((key, value) {
        if (key >= subtasks.length) {
          value.dispose();
          return true;
        }
        return false;
      });

      for (int i = 0; i < subtasks.length; i++) {
        final text = subtasks[i]['text'];

        // Initialize Controller
        if (!_subtaskControllers.containsKey(i)) {
          _subtaskControllers[i] = TextEditingController(text: text);
        } else if (_subtaskControllers[i]!.text != text) {
          // Only update text if it's different to avoid cursor jumping
          // But be careful not to overwrite user typing if they are focused
          if (!_subtaskFocusNodes.containsKey(i) ||
              !_subtaskFocusNodes[i]!.hasFocus) {
            _subtaskControllers[i]!.text = text;
          }
        }

        // Initialize FocusNode
        if (!_subtaskFocusNodes.containsKey(i)) {
          final fn = FocusNode();
          fn.addListener(() {
            if (!fn.hasFocus) {
              // Auto-save subtask on focus loss
              if (_subtaskControllers.containsKey(i)) {
                widget.onSubtaskTextChanged(i, _subtaskControllers[i]!.text);
              }
            }
          });
          _subtaskFocusNodes[i] = fn;
        }
      }
    } else {
      _subtaskControllers.clear();
      for (var fn in _subtaskFocusNodes.values) {
        fn.dispose();
      }
      _subtaskFocusNodes.clear();
    }
  }

  @override
  void didUpdateWidget(ChecklistItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item['text'] != widget.item['text']) {
      if (_controller.text != widget.item['text']) {
        if (!_focusNode.hasFocus) {
          _controller.text = widget.item['text'];
        }
      }
    }
    _initializeSubtaskControllers();
  }

  @override
  void dispose() {
    // Auto-save on dispose if text changed
    if (_controller.text != widget.item['text']) {
      widget.onTextChanged(_controller.text);
    }
    // Auto-save subtasks on dispose
    for (var i in _subtaskControllers.keys) {
      if (widget.item['subtasks'] != null &&
          i < (widget.item['subtasks'] as List).length) {
        if (_subtaskControllers[i]!.text !=
            widget.item['subtasks'][i]['text']) {
          widget.onSubtaskTextChanged(i, _subtaskControllers[i]!.text);
        }
      }
    }

    _controller.dispose();
    for (var c in _subtaskControllers.values) {
      c.dispose();
    }
    for (var fn in _subtaskFocusNodes.values) {
      fn.dispose();
    }
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasTime = item['notifyTime'] != null;
    final isChecked = item['checked'] == true;

    return RepaintBoundary(
      child: Column(
        children: [
          Container(
            color: isChecked
                ? Theme.of(context)
                    .scaffoldBackgroundColor
                    .withValues(alpha: 0.5)
                : Theme.of(context).scaffoldBackgroundColor,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.drag_indicator,
                        color: Colors.grey, size: 20),
                  ),
                  Transform.scale(
                    scale: 1.1,
                    child: Checkbox(
                      value: isChecked,
                      shape: const CircleBorder(),
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (val) {
                        if (val == true) {
                          HapticFeedback.lightImpact();
                          SystemSound.play(SystemSoundType.click);
                        }
                        widget.onChecked(val);
                      },
                    ),
                  ),
                ],
              ),
              title: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Add a task',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                style: TextStyle(
                  fontSize: 16,
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                  color: isChecked ? Colors.grey : null,
                  fontWeight: item['isImportant'] == true
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                onSubmitted: widget.onTextChanged,
              ),
              subtitle: hasTime
                  ? Row(
                      children: [
                        Icon(Icons.alarm,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(item['notifyTime'],
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary)),
                      ],
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item['isImportant'] == true)
                    IconButton(
                      icon: const Icon(Icons.star, color: Colors.orange),
                      onPressed: widget.onToggleImportant,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (value) {
                      switch (value) {
                        case 'important':
                          widget.onToggleImportant();
                          break;
                        case 'reminder':
                          widget.onToggleTime();
                          break;
                        case 'subtask':
                          widget.onAddSubtask();
                          break;
                        case 'delete':
                          widget.onDelete();
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'important',
                        child: Row(
                          children: [
                            Icon(
                              item['isImportant'] == true
                                  ? Icons.star
                                  : Icons.star_border,
                              color: item['isImportant'] == true
                                  ? Colors.orange
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(item['isImportant'] == true
                                ? 'Remove Importance'
                                : 'Mark as Important'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'reminder',
                        child: Row(
                          children: [
                            Icon(
                              hasTime ? Icons.alarm_off : Icons.alarm_add,
                              color: hasTime
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(hasTime ? 'Remove Reminder' : 'Set Reminder'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'subtask',
                        child: Row(
                          children: [
                            Icon(Icons.subdirectory_arrow_right,
                                color: Colors.grey),
                            SizedBox(width: 8),
                            Text('Add Step'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete Task',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (item['subtasks'] != null && (item['subtasks'] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 52.0, bottom: 8),
              child: Column(
                children:
                    (item['subtasks'] as List).asMap().entries.map((entry) {
                  final subIndex = entry.key;
                  final subtask = entry.value;

                  if (!_subtaskControllers.containsKey(subIndex)) {
                    _subtaskControllers[subIndex] =
                        TextEditingController(text: subtask['text']);
                  }

                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: EdgeInsets.zero,
                    leading: Checkbox(
                      value: subtask['checked'] ?? false,
                      onChanged: (val) =>
                          widget.onSubtaskChecked(subIndex, val),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    title: TextField(
                      controller: _subtaskControllers[subIndex],
                      focusNode: _subtaskFocusNodes[subIndex],
                      decoration: const InputDecoration(
                          border: InputBorder.none, isDense: true),
                      style: TextStyle(
                        fontSize: 14,
                        decoration: subtask['checked'] == true
                            ? TextDecoration.lineThrough
                            : null,
                        color: subtask['checked'] == true ? Colors.grey : null,
                      ),
                      onSubmitted: (val) =>
                          widget.onSubtaskTextChanged(subIndex, val),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => widget.onSubtaskDelete(subIndex),
                    ),
                  );
                }).toList(),
              ),
            ),
          const Divider(height: 1, indent: 16, endIndent: 16),
        ],
      ),
    );
  }
}
