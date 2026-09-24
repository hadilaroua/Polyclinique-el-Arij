import 'package:flutter/material.dart';
import '../utils/theme.dart';

class NurseCareCalendarScreen extends StatefulWidget {
  const NurseCareCalendarScreen({super.key});

  @override
  State<NurseCareCalendarScreen> createState() => _NurseCareCalendarScreenState();
}

class _NurseCareCalendarScreenState extends State<NurseCareCalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  
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
        backgroundColor: Color(0xFFDC2626),
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
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textColor(context), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Journal & Planning des Soins',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textColor(context),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppTheme.tropicalTeal),
            onPressed: _addEvent,
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.borderColor(context)),
        ),
      ),
      body: Column(
        children: [
          // Basic horizontal date picker (1 week)
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                        color: isSelected ? AppTheme.tropicalTeal : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getShortWeekday(date.weekday),
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white70 : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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
                        Icon(Icons.event_available_rounded, size: 64, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun soin planifié pour cette date',
                          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.tropicalTeal,
        onPressed: _addEvent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final isDark = AppTheme.isDarkMode(context);
    final isVitals = event['type'] == 'Vitals';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                    color: isVitals ? const Color(0xFFEFF6FF) : const Color(0xFFFDF4FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    event['time'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isVitals ? const Color(0xFF2563EB) : const Color(0xFFC026D3),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _editEvent(event),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _deleteEvent(event['id']),
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
                const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  event['patient'],
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
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
