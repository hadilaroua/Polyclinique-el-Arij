import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/theme_toggle_button.dart';
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
      CupertinoPageRoute(
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
      CupertinoPageRoute(
        builder: (_) => ChatConversationScreen(
          target: target,
          isGroup: isGroup,
        ),
      ),
    ).then((_) => _loadConversations());
  }

  void _showCreateGroupModal() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final selectedUserIds = <String>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(context).viewInsets.bottom + 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Créer un Groupe de Discussion',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.chocolatePlum),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppTheme.taupeGrey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nom du Groupe (ex: Équipe Garde Nuit)',
                  prefixIcon: const Icon(CupertinoIcons.group_solid, color: AppTheme.burntRose),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                  labelText: 'Description optionnelle',
                  prefixIcon: const Icon(CupertinoIcons.doc_text, color: AppTheme.burntRose),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Sélectionner les Membres :',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.chocolatePlum),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.builder(
                  itemCount: staffList.length,
                  itemBuilder: (context, i) {
                    final member = staffList[i];
                    final id = (member['_id'] ?? member['id'])?.toString();
                    if (id == null) return const SizedBox.shrink();
                    final fn = member['firstName'] ?? '';
                    final ln = member['lastName'] ?? '';
                    final name = '$fn $ln'.trim().isNotEmpty ? '$fn $ln'.trim() : 'Membre';
                    final role = member['role'] ?? 'STAFF';
                    final isChecked = selectedUserIds.contains(id);

                    return CheckboxListTile(
                      activeColor: AppTheme.burntRose,
                      value: isChecked,
                      onChanged: (val) {
                        setModalState(() {
                          if (val == true) {
                            selectedUserIds.add(id);
                          } else {
                            selectedUserIds.remove(id);
                          }
                        });
                      },
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.chocolatePlum)),
                      subtitle: Text(AppTheme.getRoleLabel(role), style: TextStyle(color: AppTheme.getRoleColor(role), fontSize: 11, fontWeight: FontWeight.w600)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: Colors.white),
                  label: const Text('Créer le Groupe', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.burntRose,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    if (selectedUserIds.isEmpty) return;
                    Navigator.pop(context);
                    final res = await api.createCustomGroup(
                      name: nameCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      memberIds: selectedUserIds.toList(),
                    );
                    if (res['success'] == true) {
                      _loadConversations();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSelectContactModal() {
    String modalQuery = '';
    String modalRoleFilter = 'ALL';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final modalFiltered = staffList.where((s) {
            if (modalRoleFilter != 'ALL' && s['role'] != modalRoleFilter) return false;
            if (modalQuery.isNotEmpty) {
              final q = modalQuery.toLowerCase();
              final fn = (s['firstName'] ?? '').toString().toLowerCase();
              final ln = (s['lastName'] ?? '').toString().toLowerCase();
              if (!fn.contains(q) && !ln.contains(q)) return false;
            }
            return true;
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.82,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.taupeGrey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '👥 Répertoire du Personnel Staff',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.chocolatePlum),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppTheme.taupeGrey),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un médecin, soignant, technicien...',
                    prefixIcon: const Icon(CupertinoIcons.search, color: AppTheme.taupeGrey),
                    filled: true,
                    fillColor: const Color(0xFFFAF7F7),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    isDense: true,
                  ),
                  onChanged: (val) => setModalState(() => modalQuery = val),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['ALL', 'DOCTOR', 'NURSE', 'TECHNICIAN', 'MIDWIFE'].map((r) {
                      final isSel = modalRoleFilter == r;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          selectedColor: AppTheme.burntRose,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : AppTheme.chocolatePlum,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          label: Text(r == 'ALL' ? 'Tous' : AppTheme.getRoleLabel(r)),
                          selected: isSel,
                          onSelected: (_) => setModalState(() => modalRoleFilter = r),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: modalFiltered.length,
                    itemBuilder: (context, idx) {
                      final s = modalFiltered[idx];
                      return InkWell(
                        onTap: () {
                          Navigator.pop(modalCtx);
                          _openChat(s, isGroup: false);
                        },
                        child: _buildStaffTile(s, api.currentUser?['id']?.toString()),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = api.currentUser?['id'] ?? api.currentUser?['_id'];

    final filteredConversations = conversations.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final lastMsg = (c['lastMessageContent'] ?? '').toString().toLowerCase();
      final participants = (c['participants'] as List?) ?? [];
      final hasMatch = participants.any((p) {
        if (p is Map) {
          final fn = (p['firstName'] ?? '').toString().toLowerCase();
          final ln = (p['lastName'] ?? '').toString().toLowerCase();
          return fn.contains(q) || ln.contains(q);
        }
        return false;
      });
      return hasMatch || lastMsg.contains(q);
    }).toList();

    final userRole = api.currentUser?['role'];
    final headerColor = AppTheme.getRoleColor(userRole);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: headerColor,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_back, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Row(
          children: [
            Icon(CupertinoIcons.chat_bubble_2_fill, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Messagerie Staff Clinique',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'Nouveau Groupe',
            icon: const Icon(CupertinoIcons.person_3_fill, color: AppTheme.pearlAqua),
            onPressed: _showCreateGroupModal,
          ),
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(CupertinoIcons.refresh_thick, color: Colors.white70, size: 20),
            onPressed: _loadConversations,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.burntRose,
        foregroundColor: Colors.white,
        icon: const Icon(CupertinoIcons.pencil_outline, size: 20),
        label: const Text('Nouvelle discussion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        onPressed: _showSelectContactModal,
      ),
      drawer: AppDrawer(
        onSelectTab: (_) {},
        onOpenProfile: _openProfile,
        onLogout: widget.onLogout,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: AppTheme.chocolatePlum,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher une discussion ou un groupe...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                prefixIcon: Icon(CupertinoIcons.search, color: Colors.white.withValues(alpha: 0.6), size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Main Content
          Expanded(
            child: isLoading
                ? const Center(child: CupertinoActivityIndicator(radius: 14))
                : RefreshIndicator(
                    color: AppTheme.burntRose,
                    onRefresh: _loadConversations,
                    child: ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        // Section 1: Discussions Récentes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '💬 Discussions Récentes',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.chocolatePlum),
                            ),
                            Text(
                              '${conversations.length} discussions',
                              style: const TextStyle(fontSize: 12, color: AppTheme.taupeGrey, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (filteredConversations.isEmpty)
                          Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: const Padding(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Icon(CupertinoIcons.chat_bubble_text, size: 42, color: AppTheme.taupeGrey),
                                  SizedBox(height: 10),
                                  Text('Aucune discussion récente.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.chocolatePlum)),
                                  SizedBox(height: 4),
                                  Text('Appuyez sur "+ Nouvelle discussion" pour contacter un collègue.', style: TextStyle(fontSize: 12, color: AppTheme.taupeGrey), textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                          )
                        else
                          ...filteredConversations.map((c) => _buildConversationTile(c, currentUserId?.toString())),

                        const SizedBox(height: 18),

                        // Section 2: Canaux de Garde
                        const Text(
                          '📢 Canaux de Garde & Équipes',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.chocolatePlum),
                        ),
                        const SizedBox(height: 8),
                        ...groups.map((g) => _buildGroupTile(g)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conv, String? currentUserId) {
    final participants = (conv['participants'] as List<dynamic>?) ?? [];
    Map<String, dynamic>? other;
    for (var p in participants) {
      if (p is Map<String, dynamic>) {
        final pid = (p['_id'] ?? p['id'])?.toString();
        if (pid != null && pid != currentUserId) {
          other = p;
          break;
        }
      }
    }

    if (other == null) return const SizedBox.shrink();

    final fn = other['firstName'] ?? '';
    final ln = other['lastName'] ?? '';
    final name = '$fn $ln'.trim().isNotEmpty ? '$fn $ln'.trim() : 'Collègue';
    final role = other['role'] ?? 'STAFF';
    final avatarUrl = other['avatarUrl'];

    final roleLabel = AppTheme.getRoleLabel(role);
    final roleColor = AppTheme.getRoleColor(role);

    final lastMsg = conv['lastMessageContent'] ?? '';
    final lastTimeRaw = conv['lastMessageAt'];
    String timeStr = '';
    if (lastTimeRaw != null) {
      final dt = DateTime.tryParse(lastTimeRaw.toString());
      if (dt != null) {
        final local = dt.toLocal();
        timeStr = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      }
    }

    final unreadMap = conv['unreadCounts'] as Map<String, dynamic>?;
    final unreadCount = currentUserId != null && unreadMap != null ? (unreadMap[currentUserId] ?? 0) : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: unreadCount > 0
            ? const BorderSide(color: AppTheme.burntRose, width: 1.5)
            : BorderSide(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        onTap: () => _openChat(other!, isGroup: false),
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
                  color: AppTheme.mutedTeal,
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
                style: TextStyle(
                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.chocolatePlum,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                roleLabel,
                style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                lastMsg,
                style: TextStyle(
                  fontSize: 12,
                  color: unreadCount > 0 ? AppTheme.burntRose : AppTheme.taupeGrey,
                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (timeStr.isNotEmpty)
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 10,
                  color: unreadCount > 0 ? AppTheme.burntRose : AppTheme.taupeGrey,
                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
          ],
        ),
        trailing: unreadCount > 0
            ? Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppTheme.burntRose,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              )
            : const Icon(CupertinoIcons.chevron_right, size: 16, color: AppTheme.taupeGrey),
      ),
    );
  }

  Widget _buildGroupTile(Map<String, dynamic> group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        onTap: () => _openChat(group, isGroup: true),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.pearlAqua.withValues(alpha: 0.25),
          child: Icon(
            group['id'] == 'GARDE_URGENCES'
                ? CupertinoIcons.heart_fill
                : group['id'] == 'LABO_RADIO'
                    ? CupertinoIcons.lab_flask_solid
                    : CupertinoIcons.person_3_fill,
            color: AppTheme.burntRose,
          ),
        ),
        title: Text(
          group['name'] ?? 'Groupe',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.chocolatePlum),
        ),
        subtitle: Text(
          group['description'] ?? '',
          style: const TextStyle(fontSize: 12, color: AppTheme.taupeGrey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(CupertinoIcons.chevron_right, size: 16, color: AppTheme.taupeGrey),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
      ),
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
                  color: AppTheme.mutedTeal,
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.chocolatePlum),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                roleLabel,
                style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: const Text(
          'Appuyer pour démarrer la discussion',
          style: TextStyle(fontSize: 12, color: AppTheme.taupeGrey),
        ),
        trailing: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.chat_bubble_fill, size: 18, color: AppTheme.burntRose),
            SizedBox(width: 6),
            Icon(CupertinoIcons.phone_fill, size: 18, color: AppTheme.mutedTeal),
          ],
        ),
      ),
    );
  }
}
