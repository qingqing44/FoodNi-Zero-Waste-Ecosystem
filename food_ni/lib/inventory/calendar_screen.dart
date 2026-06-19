import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../notifications/expiry_notification_service.dart';
import 'food_status_utils.dart';
import 'inventory_details_screen.dart';

class InventoryCalendarScreen extends StatefulWidget {
  const InventoryCalendarScreen({super.key});

  @override
  State<InventoryCalendarScreen> createState() =>
      _InventoryCalendarScreenState();
}

class _InventoryCalendarScreenState extends State<InventoryCalendarScreen> {
  DateTime _selectedDate = FoodStatusUtils.malaysiaTodayDateOnly();
  DateTime _focusedDate = FoodStatusUtils.malaysiaTodayDateOnly();
  final _noteController = TextEditingController();
  bool _isSavingNote = false;
  String _currentNoteDate = '';
  Stream<QuerySnapshot>? _foodItemsStream;

  Stream<QuerySnapshot>? get _stream {
    if (_foodItemsStream == null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _foodItemsStream = FirebaseFirestore.instance
            .collection('foodItems')
            .where('userId', isEqualTo: user.uid)
            .snapshots();
      }
    }
    return _foodItemsStream;
  }

  @override
  void initState() {
    super.initState();
    _loadNoteForDate(_selectedDate);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // Helper to load note when selecting a new date
  void _loadNoteForDate(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    _currentNoteDate = dateKey;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('calendarNotes')
          .doc('${user.uid}_$dateKey')
          .get();

      if (_currentNoteDate == dateKey) {
        if (doc.exists) {
          _noteController.text = doc.data()?['note'] as String? ?? '';
        } else {
          _noteController.clear();
        }
      }
    } catch (_) {
      if (_currentNoteDate == dateKey) {
        _noteController.clear();
      }
    }
  }

  Future<void> _saveNote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSavingNote = true;
    });

    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final noteText = _noteController.text.trim();

    try {
      final docRef = FirebaseFirestore.instance
          .collection('calendarNotes')
          .doc('${user.uid}_$dateKey');

      if (noteText.isEmpty) {
        await docRef.delete();
      } else {
        await docRef.set({
          'userId': user.uid,
          'date': dateKey,
          'note': noteText,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Note saved successfully'),
              ],
            ),
            backgroundColor: Color(0xFF34A853),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save note: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingNote = false;
        });
      }
    }
  }

  int _getDaysInMonth(int year, int month) {
    if (month == 0) {
      month = 12;
      year -= 1;
    } else if (month == 13) {
      month = 1;
      year += 1;
    }

    if (month == DateTime.february) {
      final isLeapYear =
          (year % 4 == 0) && (year % 100 != 0 || year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const daysInMonth = [31, -1, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return daysInMonth[month - 1];
  }

  List<DateTime> _buildCalendarDays() {
    final list = <DateTime>[];
    final firstDay = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final offset = firstDay.weekday % 7; // Sunday is index 0

    // Prev month padding
    final prevMonth = DateTime(_focusedDate.year, _focusedDate.month - 1, 1);
    final daysInPrev = _getDaysInMonth(prevMonth.year, prevMonth.month);
    for (int i = offset - 1; i >= 0; i--) {
      list.add(DateTime(prevMonth.year, prevMonth.month, daysInPrev - i));
    }

    // Current month days
    final daysInCurr = _getDaysInMonth(_focusedDate.year, _focusedDate.month);
    for (int i = 1; i <= daysInCurr; i++) {
      list.add(DateTime(_focusedDate.year, _focusedDate.month, i));
    }

    // Next month padding
    final nextMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 1);
    int nextDaysCount = 42 - list.length;
    for (int i = 1; i <= nextDaysCount; i++) {
      list.add(DateTime(nextMonth.year, nextMonth.month, i));
    }

    return list;
  }

  void _nextMonth() {
    setState(() {
      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1, 1);
    });
  }

  void _prevMonth() {
    setState(() {
      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1, 1);
    });
  }

  // Opens a bottom sheet selection of items to schedule on selectedDate
  void _showScheduleBottomSheet(List<QueryDocumentSnapshot> allItems) {
    final scheduledIds = allItems
        .where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dateStr = DateFormat('MMM dd, yyyy').format(_selectedDate);
          return data['consumeDate'] == dateStr;
        })
        .map((doc) => doc.id)
        .toSet();

    final availableItems = allItems
        .where((doc) => !scheduledIds.contains(doc.id))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ScheduleBottomSheetContent(
          availableItems: availableItems,
          selectedDate: _selectedDate,
          onSchedule: _scheduleItem,
          buildThumbnail: _buildThumbnail,
        );
      },
    );
  }

  Future<void> _scheduleItem(DocumentReference docRef, DateTime date) async {
    final formattedDate = DateFormat('MMM dd, yyyy').format(date);
    try {
      await docRef.update({'consumeDate': formattedDate});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scheduled item for $formattedDate'),
            backgroundColor: const Color(0xFF34A853),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error scheduling item: $e')));
      }
    }
  }

  Future<void> _unscheduleItem(DocumentReference docRef) async {
    try {
      await docRef.update({'consumeDate': FieldValue.delete()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed item plan from calendar'),
            backgroundColor: Color(0xFF052A1E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error unscheduling item: $e')));
      }
    }
  }

  Future<void> _markAsConsumed(DocumentReference docRef) async {
    try {
      await ExpiryNotificationService.instance.cancelReminder(docRef.id);
      // Deleting the item is consistent with current deletion actions in inventory
      await docRef.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item marked as consumed and removed'),
            backgroundColor: Color(0xFF34A853),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating item: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF052A1E);
    const accentGreen = Color(0xFF34A853);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view calendar')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: brandColor),
        title: const Text(
          'Food Calendar',
          style: TextStyle(color: brandColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: brandColor),
            );
          }

          final allDocs = snapshot.data?.docs ?? [];
          final calendarDays = _buildCalendarDays();

          // Organize food items by expiry and planned dates
          final Map<String, List<QueryDocumentSnapshot>> expiringMap = {};
          final Map<String, List<QueryDocumentSnapshot>> scheduledMap = {};

          for (final doc in allDocs) {
            final data = doc.data() as Map<String, dynamic>;

            // Expiry Date Mapping
            final expiryStr = data['expiryDate'] as String?;
            if (expiryStr != null && expiryStr != 'N/A') {
              try {
                final dateParsed = DateFormat('MMM dd, yyyy').parse(expiryStr);
                final canonicalKey = DateFormat(
                  'yyyy-MM-dd',
                ).format(dateParsed);
                expiringMap.putIfAbsent(canonicalKey, () => []).add(doc);
              } catch (_) {}
            }

            // Scheduled Consume Date Mapping
            final consumeStr = data['consumeDate'] as String?;
            if (consumeStr != null) {
              try {
                final dateParsed = DateFormat('MMM dd, yyyy').parse(consumeStr);
                final canonicalKey = DateFormat(
                  'yyyy-MM-dd',
                ).format(dateParsed);
                scheduledMap.putIfAbsent(canonicalKey, () => []).add(doc);
              } catch (_) {}
            }
          }

          final selectedKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
          final expiringToday = expiringMap[selectedKey] ?? [];
          final scheduledToday = scheduledMap[selectedKey] ?? [];

          return Column(
            children: [
              // Premium Calendar Widget
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF0F0F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Month & Year header selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_left,
                            color: brandColor,
                            size: 20,
                          ),
                          onPressed: _prevMonth,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(_focusedDate),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: brandColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_right,
                            color: brandColor,
                            size: 20,
                          ),
                          onPressed: _nextMonth,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Weekdays header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map((
                        day,
                      ) {
                        return Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    // Calendar grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                          ),
                      itemCount: 42,
                      itemBuilder: (context, index) {
                        final date = calendarDays[index];
                        final isSelected = DateUtils.isSameDay(
                          date,
                          _selectedDate,
                        );
                        final isToday = DateUtils.isSameDay(
                          date,
                          FoodStatusUtils.malaysiaTodayDateOnly(),
                        );
                        final isCurrentMonth = date.month == _focusedDate.month;

                        final canonicalDateKey = DateFormat(
                          'yyyy-MM-dd',
                        ).format(date);
                        final dayExpirations =
                            expiringMap[canonicalDateKey] ?? [];
                        final dayScheduled =
                            scheduledMap[canonicalDateKey] ?? [];

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDate = date;
                            });
                            _loadNoteForDate(date);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? brandColor
                                  : (isToday
                                        ? const Color(0xFFE8F3EF)
                                        : Colors.transparent),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : (isToday
                                          ? accentGreen
                                          : Colors.transparent),
                                width: 1.2,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      date.day.toString(),
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : (isCurrentMonth
                                                  ? brandColor
                                                  : Colors.grey[400]),
                                        fontWeight: (isSelected || isToday)
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    // Row of dot indicators
                                    if (dayExpirations.isNotEmpty)
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: dayExpirations.take(3).map((
                                          doc,
                                        ) {
                                          final data =
                                              doc.data()
                                                  as Map<String, dynamic>;
                                          final status =
                                              FoodStatusUtils.statusFromItemData(
                                                data,
                                              );
                                          final dotColor =
                                              FoodStatusUtils.statusColor(
                                                status,
                                              );
                                          return Container(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 1,
                                            ),
                                            width: 4,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Colors.white
                                                  : dotColor,
                                              shape: BoxShape.circle,
                                            ),
                                          );
                                        }).toList(),
                                      )
                                    else
                                      const SizedBox(height: 4),
                                  ],
                                ),
                                // Scheduled consume icon badge
                                if (dayScheduled.isNotEmpty)
                                  Positioned(
                                    top: 1,
                                    right: 1,
                                    child: Icon(
                                      Icons.restaurant,
                                      size: 8,
                                      color: isSelected
                                          ? accentGreen
                                          : brandColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Details Section
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 16,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Selected Date Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('EEEE, MMMM dd').format(_selectedDate),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: brandColor,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: brandColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedDate =
                                      FoodStatusUtils.malaysiaTodayDateOnly();
                                  _focusedDate =
                                      FoodStatusUtils.malaysiaTodayDateOnly();
                                });
                                _loadNoteForDate(
                                  FoodStatusUtils.malaysiaTodayDateOnly(),
                                );
                              },
                              tooltip: 'Go to Today',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Markdown Note Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F8F4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF0F0F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.edit_note,
                                    color: accentGreen,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Daily Markdown Notes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: brandColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_isSavingNote)
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: brandColor,
                                      ),
                                    )
                                  else
                                    GestureDetector(
                                      onTap: _saveNote,
                                      child: const Text(
                                        'Save Note',
                                        style: TextStyle(
                                          color: accentGreen,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _noteController,
                                maxLines: 2,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF4A4A4A),
                                ),
                                decoration: const InputDecoration(
                                  hintText:
                                      'Mark down meal plans, groceries, or notes...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  fillColor: Colors.transparent,
                                  filled: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Expiring Food Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Expiring Today (${expiringToday.length})',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: brandColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (expiringToday.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No food items expiring on this day.',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          ...expiringToday.map(
                            (doc) => _buildEventItemCard(doc, isExpiry: true),
                          ),

                        const SizedBox(height: 24),

                        // Planned Consumption Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Planned Consumption (${scheduledToday.length})',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: brandColor,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  _showScheduleBottomSheet(allDocs),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text(
                                'Schedule',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: accentGreen,
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (scheduledToday.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No food items planned for this day.',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          ...scheduledToday.map(
                            (doc) => _buildEventItemCard(doc, isExpiry: false),
                          ),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEventItemCard(
    QueryDocumentSnapshot doc, {
    required bool isExpiry,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final foodName = data['foodName'] as String? ?? 'Unknown Item';
    final quantity = data['quantity'] as String? ?? '1 unit';
    final freshnessStatus = FoodStatusUtils.statusFromItemData(data);
    final thumbPath =
        (data['thumbnailPath'] as String?) ??
        (data['localImagePath'] as String?);

    final statusColor = FoodStatusUtils.statusColor(freshnessStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InventoryDetailsScreen(item: doc),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _buildThumbnail(thumbPath, size: 54),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InventoryDetailsScreen(item: doc),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    foodName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF052A1E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        quantity,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      if (freshnessStatus.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            freshnessStatus,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Action Buttons
          if (isExpiry) ...[
            IconButton(
              icon: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF34A853),
                size: 20,
              ),
              onPressed: () => _markAsConsumed(doc.reference),
              tooltip: 'Mark as Consumed',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(
                Icons.remove_circle_outline,
                color: Colors.redAccent,
                size: 20,
              ),
              onPressed: () => _unscheduleItem(doc.reference),
              tooltip: 'Remove Plan',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThumbnail(String? path, {double size = 54}) {
    if (path != null &&
        (path.startsWith('http') ||
            path.startsWith('data:') ||
            path.startsWith('blob:'))) {
      return Image.network(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(size),
      );
    }
    if (path != null && !kIsWeb) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(size),
        );
      }
      return FutureBuilder<Directory>(
        future: getApplicationDocumentsDirectory(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final appDir = snapshot.data!;
            String? filename;
            if (path.contains('food_images')) {
              filename = path.substring(path.indexOf('food_images'));
            } else {
              filename = p.join('food_images', p.basename(path));
            }
            final resolvedFile = File(p.join(appDir.path, filename));
            if (resolvedFile.existsSync()) {
              return Image.file(
                resolvedFile,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(size),
              );
            }
          }
          return _placeholder(size);
        },
      );
    }
    return _placeholder(size);
  }

  Widget _placeholder(double size) => Container(
    width: size,
    height: size,
    color: Colors.grey[200],
    child: const Icon(Icons.fastfood, color: Colors.grey, size: 20),
  );
}

class _ScheduleBottomSheetContent extends StatefulWidget {
  final List<QueryDocumentSnapshot> availableItems;
  final DateTime selectedDate;
  final Future<void> Function(DocumentReference, DateTime) onSchedule;
  final Widget Function(String?, {double size}) buildThumbnail;

  const _ScheduleBottomSheetContent({
    required this.availableItems,
    required this.selectedDate,
    required this.onSchedule,
    required this.buildThumbnail,
  });

  @override
  State<_ScheduleBottomSheetContent> createState() =>
      _ScheduleBottomSheetContentState();
}

class _ScheduleBottomSheetContentState
    extends State<_ScheduleBottomSheetContent> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              ...ScrollConfiguration.of(context).dragDevices,
              PointerDeviceKind.mouse,
            },
          ),
          child: Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                final delta = pointerSignal.scrollDelta.dy;
                final currentSize = _sheetController.size;
                if (delta > 0 && currentSize < 0.95) {
                  double targetSize = (currentSize + 0.08).clamp(0.3, 0.95);
                  _sheetController.jumpTo(targetSize);
                } else if (delta < 0 && currentSize > 0.6) {
                  if (scrollController.hasClients &&
                      scrollController.offset <= 0) {
                    double targetSize = (currentSize - 0.08).clamp(0.6, 0.95);
                    _sheetController.jumpTo(targetSize);
                  }
                }
              }
            },
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Schedule Food Consumption',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF052A1E),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        Text(
                          'Plan to consume these food items on ${DateFormat('MMMM dd, yyyy').format(widget.selectedDate)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  if (widget.availableItems.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.kitchen_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No available food items to schedule.',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final doc = widget.availableItems[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final foodName =
                            data['foodName'] as String? ?? 'Unknown';
                        final qty = data['quantity'] as String? ?? '1 unit';
                        final thumb =
                            data['thumbnailPath'] as String? ??
                            data['localImagePath'] as String?;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 4,
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: widget.buildThumbnail(thumb, size: 48),
                          ),
                          title: Text(
                            foodName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF052A1E),
                            ),
                          ),
                          subtitle: Text(qty),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Color(0xFF34A853),
                            ),
                            onPressed: () async {
                              Navigator.pop(context);
                              await widget.onSchedule(
                                doc.reference,
                                widget.selectedDate,
                              );
                            },
                          ),
                        );
                      }, childCount: widget.availableItems.length),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
