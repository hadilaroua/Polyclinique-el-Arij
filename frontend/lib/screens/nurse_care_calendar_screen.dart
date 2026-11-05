import 'package:flutter/material.dart';
import '../utils/app_logger.dart';
import '../utils/theme.dart';

class NurseCareCalendarScreen extends StatefulWidget {
  const NurseCareCalendarScreen({super.key});

  @override
  State<NurseCareCalendarScreen> createState() => _NurseCareCalendarScreenState();
}

class _NurseCareCalendarScreenState extends State<NurseCareCalendarScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    AppLogger.logInterface(
      'Planning des Soins de Nuit',
      fileName: 'nurse_care_calendar_screen.dart',
      details: 'Tournée soignante',
    );
  }
  
  // Dummy data for the calendar
  final List<Map<String, dynamic>> _events = [
    {
      'id': '1',
      'title': 'Administration traitement IV',
      'patient': 'Leila Bouaziz',
      'time': '11:00',
      'date': DateTime.now(),
      'type': 'Treatment'
    },
    {
      'id': '2',
      'title': 'Prise de constantes - Tension & SpO2',
      'patient': 'Yassine Khelil',
      'time': '14:30',
      'date': DateTime.now(),
      'type': 'Vitals'
    }
  ];

  void _addEvent() {
    // In a real app, open a modal to add a new event
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité d\'ajout de soin à venir')),
    );
  }

  void _deleteEvent(String id) {
    setState(() {
      _events.removeWhere((e) => e['id'] == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.alertRed,
        content: Text('Soin supprimé du calendrier'),
      ),
    );
  }

  void _editEvent(Map<String, dynamic> event) {
    // Edit logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité de modification à venir')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final todayEvents = _events.where((e) => isSameDay(e['date'] as DateTime, _selectedDate)).toList();

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.evergreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Journal & Planning des Soins',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: _addEvent,
          )
        ],
      ),
      body: Column(
        children: [
          // Basic horizontal date picker (1 week)
          Container(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 14,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final date = DateTime.now().add(Duration(days: index - 3));
                  final isSelected = isSameDay(date, _selectedDate);
                  
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDate = date),
                    child: Container(
                      width: 55,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.evergreen : (isDark ? AppTheme.darkElevated : AppTheme.background),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getShortWeekday(date.weekday),
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white70 : (isDark ? AppTheme.drySage : const Color(0xFF6B7E72)),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 16,
                              color: isSelected ? Colors.white : AppTheme.textColor(context),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          Expanded(
            child: todayEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available_rounded, size: 64, color: isDark ? AppTheme.darkElevated : AppTheme.dustGrey),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun soin planifié pour cette date',
                          style: TextStyle(color: isDark ? AppTheme.drySage : const Color(0xFF6B7E72)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: todayEvents.length,
                    itemBuilder: (context, index) {
                      final event = todayEvents[index];
                      return _buildEventCard(event);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'nurse_care_fab',
        backgroundColor: AppTheme.pastelOrange,
        onPressed: _addEvent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final isDark = AppTheme.isDarkMode(context);
    final isVitals = event['type'] == 'Vitals';
    
    return Dismissible(
      key: Key(event['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.alertRed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_forever, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => _deleteEvent(event['id']),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isVitals ? AppTheme.background : const Color(0xFFFDF4FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    event['time'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isVitals ? AppTheme.evergreen : const Color(0xFFC026D3),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF6B7E72)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _editEvent(event),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              event['title'],
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor(context),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF6B7E72)),
                const SizedBox(width: 4),
                Text(
                  event['patient'],
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7E72),
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

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
  
  String _getShortWeekday(int weekday) {
    switch (weekday) {
      case 1: return 'LUN';
      case 2: return 'MAR';
      case 3: return 'MER';
      case 4: return 'JEU';
      case 5: return 'VEN';
      case 6: return 'SAM';
      case 7: return 'DIM';
      default: return '';
    }
  }
}
