import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import '../../utils/app_logger.dart';
import '../../utils/default_patients.dart';
import '../../widgets/figma_header.dart';
import '../../widgets/ios_bottom_nav_bar.dart';
import 'clinical_event_detail_modal.dart';
import 'new_clinical_event_modal.dart';

enum CalendarViewType { hour, day, month, year }

class ClinicalCalendarScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onLogout;

  const ClinicalCalendarScreen({super.key, this.onBack, this.onLogout});

  @override
  State<ClinicalCalendarScreen> createState() => _ClinicalCalendarScreenState();
}

class _ClinicalCalendarScreenState extends State<ClinicalCalendarScreen> {
  final _api = ApiService();
  CalendarViewType _currentView = CalendarViewType.day;

  DateTime _selectedDate = DateTime.now();
  List<dynamic> _events = [];
  bool _isLoading = true;

  // Search State
  bool _isSearching = false;
  String _searchQuery = '';

  Timer? _nowTimer;
  DateTime _nowTime = DateTime.now();
  bool _isZoomingHandled = false;

  final List<String> _timeSlots = [
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
  ];

  final List<String> _hourSubSlots = [
    '08:00', '08:30',
    '09:00', '09:30',
    '10:00', '10:30',
    '11:00', '11:30',
    '12:00', '12:30',
    '13:00', '13:30',
    '14:00', '14:30',
    '15:00', '15:30',
    '16:00', '16:30',
    '17:00', '17:30',
    '18:00',
  ];

  @override
  void initState() {
    super.initState();
    AppLogger.logInterface('Calendrier Clinique', fileName: 'clinical_calendar_screen.dart', details: 'Ouverture du calendrier clinique');
    _loadEvents();
    _startNowTimer();
  }

  @override
  void dispose() {
    _nowTimer?.cancel();
    super.dispose();
  }

  void _startNowTimer() {
    _nowTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _nowTime = DateTime.now());
    });
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final list = await _api.getClinicalEvents();
      if (mounted) {
        setState(() {
          _events = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return months[(month - 1) % 12];
  }

  String _getDayName(int weekday) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days[(weekday - 1) % 7];
  }

  String _formatDateStr(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  int _parseMinutes(String timeStr) {
    if (timeStr.isEmpty) return 0;
    final parts = timeStr.trim().split(':');
    if (parts.length < 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  String _minutesToTimeStr(int totalMinutes) {
    final h = (totalMinutes ~/ 60).clamp(0, 23);
    final m = (totalMinutes % 60).clamp(0, 59);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _getPatientName(Map<String, dynamic> ev) {
    if (ev['patientId'] is Map) {
      final pat = ev['patientId'] as Map<String, dynamic>;
      final name = '${pat['firstName'] ?? ''} ${pat['lastName'] ?? ''}'.trim();
      if (name.isNotEmpty) return name;
    }
    if (ev['patient'] is Map) {
      final pat = ev['patient'] as Map<String, dynamic>;
      final name = '${pat['firstName'] ?? ''} ${pat['lastName'] ?? ''}'.trim();
      if (name.isNotEmpty) return name;
    }
    final searchId = (ev['patientId'] ?? ev['patient'])?.toString() ?? '';
    for (final p in DefaultPatients.getAll()) {
      if (p['_id'] == searchId || p['dossierNumber'] == searchId || p['cin'] == searchId) {
        return '${p['firstName']} ${p['lastName']}'.trim();
      }
    }
    return ev['patientName']?.toString().isNotEmpty == true ? ev['patientName'].toString() : 'Mme Hadil Aroua';
  }

  List<dynamic> get _filteredEvents {
    return _events.where((ev) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = (ev['procedureTitle'] ?? '').toString().toLowerCase();
        final room = (ev['roomId'] ?? '').toString().toLowerCase();
        final pat = _getPatientName(ev).toLowerCase();
        if (!title.contains(q) && !room.contains(q) && !pat.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // Reschedule & Drag and Drop Event Handler
  Future<void> _onEventDropped(
    Map<String, dynamic> ev, {
    String? newDateStr,
    String? newStartTimeStr,
  }) async {
    final rawId = (ev['_id'] ?? ev['id'])?.toString();

    final oldDate = ev['date']?.toString() ?? _formatDateStr(_selectedDate);
    final oldStart = ev['startTime']?.toString() ?? '09:00';
    final oldEnd = ev['endTime']?.toString() ?? '10:30';
    final startMin = _parseMinutes(oldStart);
    final endMin = _parseMinutes(oldEnd);
    final durationMin = (endMin - startMin).clamp(15, 480);

    final updatedDate = newDateStr ?? oldDate;
    String updatedStart = oldStart;
    String updatedEnd = oldEnd;

    if (newStartTimeStr != null) {
      updatedStart = newStartTimeStr;
      final newStartMin = _parseMinutes(newStartTimeStr);
      final newEndMin = newStartMin + durationMin;
      updatedEnd = _minutesToTimeStr(newEndMin);
    }

    if (updatedDate == oldDate && updatedStart == oldStart && updatedEnd == oldEnd) {
      return;
    }

    setState(() {
      ev['date'] = updatedDate;
      ev['startTime'] = updatedStart;
      ev['endTime'] = updatedEnd;
    });

    HapticFeedback.mediumImpact();

    if (rawId != null && rawId.isNotEmpty) {
      await _api.updateClinicalEvent(rawId, {
        'date': updatedDate,
        'startTime': updatedStart,
        'endTime': updatedEnd,
      });
    }

    if (mounted) {
      final patName = _getPatientName(ev);
      final title = ev['procedureTitle'] ?? 'Intervention';
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.darkSurface,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: [
              const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Colors.greenAccent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '📅 $title ($patName) déplacé à $updatedStart le $updatedDate',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _zoomIn() {
    HapticFeedback.selectionClick();
    setState(() {
      switch (_currentView) {
        case CalendarViewType.year:
          _currentView = CalendarViewType.month;
          break;
        case CalendarViewType.month:
          _currentView = CalendarViewType.day;
          break;
        case CalendarViewType.day:
        case CalendarViewType.hour:
          _currentView = CalendarViewType.hour;
          break;
      }
    });
  }

  void _zoomOut() {
    HapticFeedback.selectionClick();
    setState(() {
      switch (_currentView) {
        case CalendarViewType.hour:
          _currentView = CalendarViewType.day;
          break;
        case CalendarViewType.day:
          _currentView = CalendarViewType.month;
          break;
        case CalendarViewType.month:
        case CalendarViewType.year:
          _currentView = CalendarViewType.year;
          break;
      }
    });
  }

  void _openNewEventModal([String? initialDateStr]) {
    NewClinicalEventModal.show(
      context,
      initialDate: initialDateStr ?? _formatDateStr(_selectedDate),
      onSuccess: (createdEvent) async {
        if (createdEvent != null && createdEvent['date'] != null) {
          try {
            final evDate = DateTime.parse(createdEvent['date']);
            setState(() {
              _selectedDate = evDate;
            });
          } catch (_) {}
        }
        await _loadEvents();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final user = _api.currentUser;
    final role = user?['role'] ?? 'DOCTOR';
    final firstName = user?['firstName'] ?? '';
    final lastName = user?['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      body: Column(
        children: [
          // 1. TOP APP BAR
          FigmaHeader(
            roleName: AppTheme.getRoleLabel(role),
            roleColor: AppTheme.getRoleColor(role),
            onMenuPressed: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            onNotificationsPressed: () {},
            unreadNotifications: 0,
            profileImageUrl: user?['avatarUrl'],
            userName: fullName,
          ),

          // 2. CALENDAR SUB-HEADER
          _buildCalendarHeader(isDark),

          // Search Bar Overlay
          if (_isSearching) _buildSearchBar(isDark),

          const SizedBox(height: 8),

          // 3. VIEW CAPSULE SWITCHER (Heure / Jour / Mois / Année)
          _buildViewCapsuleSwitcher(isDark),

          const SizedBox(height: 10),

          // 4. MAIN CALENDAR BODY (With Direct View Switching & Pinch-to-Zoom)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onScaleStart: (_) => _isZoomingHandled = false,
                    onScaleUpdate: (details) {
                      if (_isZoomingHandled) return;
                      if (details.scale > 1.25) {
                        _isZoomingHandled = true;
                        _zoomIn();
                      } else if (details.scale < 0.78) {
                        _isZoomingHandled = true;
                        _zoomOut();
                      }
                    },
                    onScaleEnd: (_) => _isZoomingHandled = false,
                    child: _buildCurrentViewWidget(isDark),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: IosBottomNavBar(
        selectedIndex: 2,
        onItemSelected: (idx) {
          if (widget.onBack != null) {
            widget.onBack!();
          } else if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
        activeColor: AppTheme.evergreen,
        items: const [
          IosBottomNavItem(
            icon: CupertinoIcons.house,
            selectedIcon: CupertinoIcons.house_fill,
            label: 'Accueil',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.folder,
            selectedIcon: CupertinoIcons.folder_fill,
            label: 'Dossiers Patients',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.calendar,
            selectedIcon: CupertinoIcons.calendar_today,
            label: 'Calendrier',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.lab_flask,
            selectedIcon: CupertinoIcons.lab_flask_solid,
            label: 'Examens',
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 75),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppTheme.pastelOrange.withOpacity(0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () => _openNewEventModal(),
            backgroundColor: AppTheme.pastelOrange,
            elevation: 0,
            icon: const Icon(CupertinoIcons.calendar_badge_plus, color: Colors.white, size: 20),
            label: const Text(
              '+ Événement',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentViewWidget(bool isDark) {
    switch (_currentView) {
      case CalendarViewType.hour:
        return _buildHourView(isDark);
      case CalendarViewType.day:
        return _buildDayView(isDark);
      case CalendarViewType.month:
        return _buildMonthView(isDark);
      case CalendarViewType.year:
        return _buildYearView(isDark);
    }
  }

  Widget _buildCalendarHeader(bool isDark) {
    final monthYear = '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 4),
      child: Row(
        children: [
          // SIMPLE ICON RETOUR
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.evergreen, size: 22),
            onPressed: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 4),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calendrier',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppTheme.evergreen,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                monthYear,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.dustGrey,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Search Toggle Button
          IconButton(
            icon: Icon(_isSearching ? CupertinoIcons.xmark : CupertinoIcons.search, color: AppTheme.evergreen, size: 21),
            onPressed: () => setState(() => _isSearching = !_isSearching),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : AppTheme.textMain),
        decoration: InputDecoration(
          hintText: 'Rechercher intervention, patient, salle...',
          prefixIcon: const Icon(CupertinoIcons.search, color: AppTheme.evergreen, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(CupertinoIcons.clear_circled_solid, size: 16, color: AppTheme.dustGrey),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: isDark ? AppTheme.darkSurface : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppTheme.dustGrey.withValues(alpha: 0.3)),
          ),
        ),
      ),
    );
  }

  Widget _buildViewCapsuleSwitcher(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.evergreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          _buildCapsuleSegment('Heure', CalendarViewType.hour, isDark),
          _buildCapsuleSegment('Jour', CalendarViewType.day, isDark),
          _buildCapsuleSegment('Mois', CalendarViewType.month, isDark),
          _buildCapsuleSegment('Année', CalendarViewType.year, isDark),
        ],
      ),
    );
  }

  Widget _buildCapsuleSegment(String label, CalendarViewType type, bool isDark) {
    final isSelected = _currentView == type;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _currentView = type);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.evergreen : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppTheme.textMain),
            ),
          ),
        ),
      ),
    );
  }

  // --- VUE HEURE (Grille Réglable Ultra Précise) ---
  Widget _buildHourView(bool isDark) {
    final selectedDateStr = _formatDateStr(_selectedDate);
    final dayEvents = _filteredEvents.where((e) => e['date'] == selectedDateStr).toList();

    return Column(
      children: [
        // Subheader Date & Total
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              const Icon(CupertinoIcons.clock_fill, size: 16, color: AppTheme.evergreen),
              const SizedBox(width: 8),
              Text(
                'Vue Détaillée par Heure — ${_selectedDate.day} ${_getMonthName(_selectedDate.month)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.evergreen),
              ),
              const Spacer(),
              Text(
                '${dayEvents.length} intervention(s)',
                style: const TextStyle(fontSize: 12, color: AppTheme.dustGrey, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Stack(
              children: [
                // 1. Time Sub-Slots Grid Lines (30 mins precision)
                Column(
                  children: _hourSubSlots.map((timeSlot) {
                    return DragTarget<Map<String, dynamic>>(
                      onWillAcceptWithDetails: (_) => true,
                      onAcceptWithDetails: (details) => _onEventDropped(details.data, newStartTimeStr: timeSlot),
                      builder: (context, candidateData, rejectedData) {
                        final isHovered = candidateData.isNotEmpty;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 55,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isHovered
                                ? AppTheme.evergreen.withValues(alpha: 0.15)
                                : Colors.transparent,
                            border: Border(
                              top: BorderSide(
                                color: timeSlot.endsWith(':00')
                                    ? AppTheme.dustGrey.withValues(alpha: 0.25)
                                    : AppTheme.dustGrey.withValues(alpha: 0.08),
                                width: timeSlot.endsWith(':00') ? 1.2 : 0.8,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 55,
                                child: Text(
                                  timeSlot,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: timeSlot.endsWith(':00') ? FontWeight.w800 : FontWeight.w500,
                                    color: timeSlot.endsWith(':00') ? AppTheme.evergreen : AppTheme.dustGrey,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  height: 1,
                                  color: AppTheme.dustGrey.withValues(alpha: 0.08),
                                  child: isHovered
                                      ? Center(
                                          child: Text(
                                            '🎯 Déposer l\'événement à $timeSlot',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.evergreen,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),

                // 2. Current Time Line Indicator
                if (_selectedDate.year == DateTime.now().year &&
                    _selectedDate.month == DateTime.now().month &&
                    _selectedDate.day == DateTime.now().day)
                  Positioned(
                    top: _getHourViewOffset(_formatTimeOfDay(TimeOfDay.fromDateTime(_nowTime))),
                    left: 55,
                    right: 0,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppTheme.alertRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: AppTheme.alertRed,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.alertRed,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _formatTimeOfDay(TimeOfDay.fromDateTime(_nowTime)),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 3. Positioned Draggable Event Cards
                ...dayEvents.map((ev) {
                  final startMin = _parseMinutes(ev['startTime']?.toString() ?? '09:00');
                  final endMin = _parseMinutes(ev['endTime']?.toString() ?? '10:30');
                  final topOffset = ((startMin - 480) / 30) * 55; // 08:00 start (55px per 30 mins)
                  final durationMin = (endMin - startMin).clamp(20, 240);
                  final cardHeight = ((durationMin / 30) * 55).clamp(45.0, 300.0);

                  return Positioned(
                    top: topOffset.toDouble(),
                    left: 65,
                    right: 16,
                    height: cardHeight.toDouble(),
                    child: _buildDraggableEventCard(ev, isDark),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- VUE JOUR ---
  Widget _buildDayView(bool isDark) {
    final selectedDateStr = _formatDateStr(_selectedDate);
    final dayEvents = _filteredEvents.where((e) => e['date'] == selectedDateStr).toList();

    return Column(
      children: [
        // Date Pill Selector Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.dustGrey.withValues(alpha: 0.2))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppTheme.evergreen),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                  });
                },
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_getDayName(_selectedDate.weekday)} ${_selectedDate.day} ${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: isDark ? Colors.white : AppTheme.evergreen,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.evergreen),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 1));
                  });
                },
              ),
            ],
          ),
        ),

        // Vertical Time Grid Scroll Area with DragTargets
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Stack(
              children: [
                Column(
                  children: _timeSlots.map((time) {
                    return DragTarget<Map<String, dynamic>>(
                      onWillAcceptWithDetails: (_) => true,
                      onAcceptWithDetails: (details) => _onEventDropped(details.data, newStartTimeStr: time),
                      builder: (context, candidateData, rejectedData) {
                        final isHovered = candidateData.isNotEmpty;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 70,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isHovered ? AppTheme.evergreen.withValues(alpha: 0.15) : Colors.transparent,
                            border: Border(top: BorderSide(color: AppTheme.dustGrey.withOpacity(0.15))),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 50,
                                child: Text(
                                  time,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isHovered ? AppTheme.evergreen : AppTheme.dustGrey,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  height: 1,
                                  color: AppTheme.dustGrey.withOpacity(0.1),
                                  child: isHovered
                                      ? const Center(
                                          child: Text(
                                            '🎯 Déposer l\'événement à cet horaire',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.evergreen,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),

                // Current Time Line Indicator
                if (_selectedDate.year == DateTime.now().year &&
                    _selectedDate.month == DateTime.now().month &&
                    _selectedDate.day == DateTime.now().day)
                  Positioned(
                    top: _getMinuteOffset(_formatTimeOfDay(TimeOfDay.fromDateTime(_nowTime))),
                    left: 50,
                    right: 0,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppTheme.alertRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: AppTheme.alertRed,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.alertRed,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _formatTimeOfDay(TimeOfDay.fromDateTime(_nowTime)),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Event Cards Positioned by Real Time
                ...dayEvents.map((ev) {
                  final startMin = _parseMinutes(ev['startTime']?.toString() ?? '09:00');
                  final endMin = _parseMinutes(ev['endTime']?.toString() ?? '10:30');
                  final topOffset = ((startMin - 480) / 60) * 70;
                  final durationMin = (endMin - startMin).clamp(30, 240);
                  final cardHeight = (durationMin / 60) * 70;

                  return Positioned(
                    top: topOffset.toDouble(),
                    left: 60,
                    right: 16,
                    height: cardHeight.toDouble(),
                    child: _buildDraggableEventCard(ev, isDark),
                  );
                }),

                if (dayEvents.isEmpty)
                  Positioned.fill(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Column(
                          children: [
                            const Icon(CupertinoIcons.calendar_badge_plus, size: 40, color: AppTheme.dustGrey),
                            const SizedBox(height: 10),
                            const Text(
                              'Aucune intervention programmée pour ce jour',
                              style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.dustGrey),
                            ),
                            const SizedBox(height: 8),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              color: AppTheme.evergreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              onPressed: () => _openNewEventModal(selectedDateStr),
                              child: const Text(
                                '+ Programmer un événement',
                                style: TextStyle(color: AppTheme.evergreen, fontWeight: FontWeight.w700, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- VUE MOIS ---
  Widget _buildMonthView(bool isDark) {
    final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);
    final startWeekday = firstDayOfMonth.weekday; // 1 = Lun

    return Column(
      children: [
        // Days of Week Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['L', 'M', 'M', 'J', 'V', 'S', 'D'].map((d) {
              return Text(d, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.dustGrey, fontSize: 13));
            }).toList(),
          ),
        ),

        // Grid Calendar with Drag Targets
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
            ),
            itemCount: (startWeekday - 1) + daysInMonth,
            itemBuilder: (ctx, index) {
              if (index < (startWeekday - 1)) {
                return const SizedBox();
              }
              final dayNum = index - (startWeekday - 1) + 1;
              final currentDt = DateTime(_selectedDate.year, _selectedDate.month, dayNum);
              final dateStr = _formatDateStr(currentDt);
              final eventsForDay = _filteredEvents.where((e) => e['date'] == dateStr).toList();
              final isSelected = dayNum == _selectedDate.day;

              return DragTarget<Map<String, dynamic>>(
                onWillAcceptWithDetails: (_) => true,
                onAcceptWithDetails: (details) => _onEventDropped(details.data, newDateStr: dateStr),
                builder: (context, candidateData, rejectedData) {
                  final isHovered = candidateData.isNotEmpty;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = currentDt;
                        _currentView = CalendarViewType.day;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isHovered
                            ? AppTheme.pastelOrange
                            : (isSelected
                                ? AppTheme.evergreen
                                : (isDark ? AppTheme.darkSurface : Colors.white)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isHovered
                              ? Colors.white
                              : (isSelected ? AppTheme.evergreen : AppTheme.dustGrey.withOpacity(0.2)),
                          width: isHovered ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: (isSelected || isHovered) ? Colors.white : (isDark ? Colors.white : AppTheme.textMain),
                            ),
                          ),
                          if (eventsForDay.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: eventsForDay.take(3).map((ev) {
                                return LongPressDraggable<Map<String, dynamic>>(
                                  data: ev is Map<String, dynamic> ? ev : Map<String, dynamic>.from(ev),
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.evergreen,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        ev['procedureTitle'] ?? 'Événement',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: (isSelected || isHovered) ? Colors.white : AppTheme.pastelOrange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- VUE ANNÉE (12 Mois 3x4 Grid) ---
  Widget _buildYearView(bool isDark) {
    final months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];

    final year = _selectedDate.year;

    return Column(
      children: [
        // Year Header with Prev/Next Navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.evergreen, size: 18),
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(year - 1, _selectedDate.month, 1);
                  });
                },
              ),
              Expanded(
                child: Text(
                  'Année $year',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.evergreen,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.evergreen, size: 18),
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(year + 1, _selectedDate.month, 1);
                  });
                },
              ),
            ],
          ),
        ),

        // 12 Months Grid (3x4)
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.95,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: 12,
            itemBuilder: (ctx, idx) {
              final monthNum = idx + 1;
              final isCurrentMonth = DateTime.now().year == year && DateTime.now().month == monthNum;
              final isSelectedMonth = _selectedDate.month == monthNum;

              final monthPrefix = '$year-${monthNum.toString().padLeft(2, '0')}';
              final eventsInMonth = _filteredEvents.where((e) => (e['date']?.toString() ?? '').startsWith(monthPrefix)).length;

              return DragTarget<Map<String, dynamic>>(
                onWillAcceptWithDetails: (_) => true,
                onAcceptWithDetails: (details) {
                  final newDateStr = '$year-${monthNum.toString().padLeft(2, '0')}-01';
                  _onEventDropped(details.data, newDateStr: newDateStr);
                },
                builder: (context, candidateData, rejectedData) {
                  final isHovered = candidateData.isNotEmpty;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedDate = DateTime(year, monthNum, 1);
                        _currentView = CalendarViewType.month;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isHovered
                            ? AppTheme.pastelOrange
                            : (isSelectedMonth
                                ? AppTheme.evergreen
                                : (isDark ? AppTheme.darkSurface : Colors.white)),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isHovered
                              ? Colors.white
                              : (isCurrentMonth
                                  ? AppTheme.evergreen
                                  : AppTheme.dustGrey.withValues(alpha: 0.2)),
                          width: (isCurrentMonth || isHovered) ? 2.0 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            months[idx],
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: (isSelectedMonth || isHovered)
                                  ? Colors.white
                                  : (isDark ? Colors.white : AppTheme.textMain),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isSelectedMonth || isHovered)
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : AppTheme.evergreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              eventsInMonth > 0 ? '$eventsInMonth évén.' : 'Libre',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: (isSelectedMonth || isHovered)
                                    ? Colors.white
                                    : AppTheme.evergreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDraggableEventCard(dynamic ev, bool isDark) {
    final mapEv = ev is Map<String, dynamic> ? ev : Map<String, dynamic>.from(ev as Map);

    return LongPressDraggable<Map<String, dynamic>>(
      data: mapEv,
      delay: const Duration(milliseconds: 160),
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 290, maxHeight: 95),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.evergreen,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.hand_draw_fill, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mapEv['procedureTitle'] ?? 'Intervention',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Déplacement de l\'événement...',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _buildEventCard(mapEv, isDark),
      ),
      child: GestureDetector(
        onTap: () => ClinicalEventDetailModal.show(context, mapEv, onUpdated: _loadEvents),
        child: _buildEventCard(mapEv, isDark),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> ev, bool isDark) {
    final title = ev['procedureTitle'] ?? 'Intervention';
    final patName = _getPatientName(ev);

    final room = ev['roomId'] ?? 'Bloc 1';
    final startTime = ev['startTime'] ?? '09:00';
    final endTime = ev['endTime'] ?? '10:30';
    final status = ev['status']?.toString() ?? 'SCHEDULED';
    final isCancelled = status == 'CANCELLED';

    Color cardColor = isDark ? AppTheme.darkSurface : Colors.white;
    Color accentColor = AppTheme.evergreen;

    if (ev['procedureType'] == 'CESAREAN') {
      accentColor = const Color(0xFF007AFF);
    } else if (ev['procedureType'] == 'SURGERY') {
      accentColor = AppTheme.pastelOrange;
    } else if (ev['procedureType'] == 'DELIVERY') {
      accentColor = const Color(0xFFFF2D55);
    }

    if (isCancelled) accentColor = AppTheme.alertRed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: accentColor, width: 4.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isCancelled ? AppTheme.alertRed : (isDark ? Colors.white : AppTheme.textMain),
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$startTime — $endTime',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(CupertinoIcons.person_fill, size: 12, color: AppTheme.dustGrey),
              const SizedBox(width: 4),
              Text(
                patName,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.dustGrey),
              ),
              const Spacer(),
              const Icon(CupertinoIcons.building_2_fill, size: 12, color: AppTheme.dustGrey),
              const SizedBox(width: 4),
              Text(
                room,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.dustGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _getMinuteOffset(String timeStr) {
    final mins = _parseMinutes(timeStr);
    return (((mins - 480) / 60) * 70).clamp(0.0, 700.0);
  }

  double _getHourViewOffset(String timeStr) {
    final mins = _parseMinutes(timeStr);
    return (((mins - 480) / 30) * 55).clamp(0.0, 1200.0);
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    return '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';
  }
}
