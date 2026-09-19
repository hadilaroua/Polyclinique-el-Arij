import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/avatar_widget.dart';
import 'chat_conversation_screen.dart';
import 'profile_screen.dart';

class StaffMessengerScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const StaffMessengerScreen({super.key, required this.onLogout});

  @override
  State<StaffMessengerScreen> createState() => _StaffMessengerScreenState();
}

class _StaffMessengerScreenState extends State<StaffMessengerScreen> {
  final api = ApiService();
  String _searchQuery = '';
  String _selectedRoleFilter = 'ALL';

  List<dynamic> staffList = [];
  List<dynamic> conversations = [];
  List<dynamic> groups = [];
  bool isLoading = true;

  Timer? _realtimeTimer;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _startRealtimeSync();
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
  }

  void _startRealtimeSync() {
    _realtimeTimer?.cancel();
    _realtimeTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) async {
      if (!mounted) return;
      try {
        final data = await api.getConversations();
        if (!mounted) return;
        setState(() {
          staffList = data['staffList'] ?? [];
          conversations = data['conversations'] ?? [];
          groups = data['groups'] ?? [];
        });
      } catch (_) {}
    });
  }

  Future<void> _loadConversations() async {
    setState(() => isLoading = true);
    try {
      final data = await api.getConversations();
      if (mounted) {
        setState(() {
          staffList = data['staffList'] ?? [];
          conversations = data['conversations'] ?? [];
          groups = data['groups'] ?? [];
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          onProfileUpdated: () => setState(() {}),
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  void _openChat(Map<String, dynamic> target, {bool isGroup = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          target: target,
          isGroup: isGroup,
        ),
      ),
    ).then((_) => _loadConversations());
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = api.currentUser?['id'] ?? api.currentUser?['_id'];

    // Filtrage des membres du personnel
    final filteredStaff = staffList.where((s) {
      if (_selectedRoleFilter != 'ALL' && s['role'] != _selectedRoleFilter) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final fn = (s['firstName'] ?? '').toString().toLowerCase();
        final ln = (s['lastName'] ?? '').toString().toLowerCase();
        final role = (s['role'] ?? '').toString().toLowerCase();
        if (!fn.contains(q) && !ln.contains(q) && !role.contains(q)) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        title: const Row(
          children: [
            Icon(Icons.forum, color: Colors.cyanAccent, size: 24),
            SizedBox(width: 10),
            Text(
              'Messagerie Staff Clinique',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadConversations,
          ),
        ],
      ),
      drawer: AppDrawer(
        onSelectTab: (_) {},
        onOpenProfile: _openProfile,
        onLogout: widget.onLogout,
      ),
      body: Column(
        children: [
          // Barre de Recherche & Filtres Rapides
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              children: [
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un collègue, un médecin, un technicien...',
                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: Colors.white12,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildRoleFilterChip('ALL', '🌐 Tous'),
                      const SizedBox(width: 8),
                      _buildRoleFilterChip('DOCTOR', '🩺 Médecins'),
                      const SizedBox(width: 8),
                      _buildRoleFilterChip('NURSE', '💉 Infirmiers'),
                      const SizedBox(width: 8),
                      _buildRoleFilterChip('TECHNICIAN', '🩻 Techniciens'),
                      const SizedBox(width: 8),
                      _buildRoleFilterChip('MIDWIFE', '🤰 Sages-femmes'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Contenu principal
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadConversations,
                    child: ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        // Section Canaux & Groupes de Garde
                        const Text(
                          '📢 Canaux de Garde & Équipes',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 8),
                        ...groups.map((g) => _buildGroupTile(g)),

                        const SizedBox(height: 18),

                        // Section Discussions Directes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '💬 Personnel Soignant & Employés',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155)),
                            ),
                            Text(
                              '${filteredStaff.length} membres',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (filteredStaff.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text('Aucun membre trouvé.', style: TextStyle(color: Color(0xFF94A3B8))),
                            ),
                          )
                        else
                          ...filteredStaff.map((staff) => _buildStaffTile(staff, currentUserId)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilterChip(String key, String label) {
    final isSelected = _selectedRoleFilter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
      selected: isSelected,
      selectedColor: Colors.cyanAccent,
      backgroundColor: Colors.white12,
      onSelected: (_) => setState(() => _selectedRoleFilter = key),
    );
  }

  Widget _buildGroupTile(Map<String, dynamic> group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _openChat(group, isGroup: true),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFFE0F2FE),
          child: Icon(
            group['id'] == 'GARDE_URGENCES'
                ? Icons.medical_services
                : group['id'] == 'LABO_RADIO'
                    ? Icons.science
                    : Icons.groups,
            color: const Color(0xFF0284C7),
          ),
        ),
        title: Text(
          group['name'] ?? 'Groupe',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          group['description'] ?? '',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
      ),
    );
  }

  Widget _buildStaffTile(Map<String, dynamic> staff, String? currentUserId) {
    final fn = staff['firstName'] ?? '';
    final ln = staff['lastName'] ?? '';
    final name = '$fn $ln'.trim().isNotEmpty ? '$fn $ln'.trim() : 'Collègue';
    final role = staff['role'] ?? 'STAFF';
    final avatarUrl = staff['avatarUrl'];

    final roleLabel = AppTheme.getRoleLabel(role);
    final roleColor = AppTheme.getRoleColor(role);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _openChat(staff, isGroup: false),
        leading: Stack(
          children: [
            AvatarWidget(
              avatarUrl: avatarUrl,
              name: name,
              role: role,
              radius: 22,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                roleLabel,
                style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Text(
          'Appuyer pour démarrer la discussion',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        trailing: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF0284C7)),
            SizedBox(width: 4),
            Icon(Icons.phone_outlined, size: 18, color: Color(0xFF059669)),
          ],
        ),
      ),
    );
  }
}
