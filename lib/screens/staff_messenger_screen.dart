import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/app_logger.dart';
import '../utils/theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/arj_ui.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/figma_header.dart';
import '../widgets/ios_bottom_nav_bar.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filter = 'Tous'; // Tous, Non lus, Équipes
  String _sortMode = 'Récents'; // Récents, A-Z, Par rôle

  static const List<Map<String, String>> _initialDefaultGroups = [
    {'id': 'GARDE_URGENCES', 'name': 'Canal Urgences & Garde', 'description': 'Canal prioritaire de garde & urgences'},
    {'id': 'LABO_RADIO', 'name': 'Canal Plateau Technique', 'description': 'Transmission des résultats labo & imagerie'},
  ];

  List<dynamic> staffList = [];
  List<dynamic> conversations = [];
  List<dynamic> groups = List.from(_initialDefaultGroups);
  bool isLoading = false;

  Timer? _realtimeTimer;

  @override
  void initState() {
    super.initState();
    AppLogger.logInterface(
      'Messagerie Canaux Cliniques',
      fileName: 'staff_messenger_screen.dart',
      details: 'Chargement des canaux soignants',
    );
    _loadConversations();
    _startRealtimeSync();
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    _searchController.dispose();
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
          groups = (data['groups'] as List<dynamic>?) ?? [];
          conversations = (data['conversations'] as List<dynamic>?) ?? [];
        });
      } catch (_) {}
    });
  }

  final List<dynamic> _defaultGroups = const [
    {'id': 'GARDE_URGENCES', 'name': 'Canal Urgences & Garde', 'description': 'Canal prioritaire de garde & urgences'},
    {'id': 'LABO_RADIO', 'name': 'Canal Plateau Technique', 'description': 'Transmission des résultats labo & imagerie'},
  ];

  Future<void> _loadConversations() async {
    setState(() => isLoading = true);
    try {
      final data = await api.getConversations();
      if (mounted) {
        final apiGroups = (data['groups'] as List<dynamic>?) ?? [];
        setState(() {
          staffList = data['staffList'] ?? [];
          conversations = data['conversations'] ?? [];
          groups = apiGroups.isNotEmpty ? apiGroups : _defaultGroups;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          groups = _defaultGroups;
          isLoading = false;
        });
      }
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
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ArjUi.dragHandle(context),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Nouveau groupe',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: AppTheme.subtextColor(context)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nom du groupe',
                  prefixIcon: Icon(Icons.group_outlined,
                      color: AppTheme.evergreen),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                  labelText: 'Description (optionnelle)',
                  prefixIcon: Icon(Icons.description_outlined,
                      color: AppTheme.evergreen),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Membres',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: staffList.length,
                  itemBuilder: (context, i) {
                    final member = staffList[i];
                    final id = (member['_id'] ?? member['id'])?.toString();
                    if (id == null) return const SizedBox.shrink();
                    final fn = member['firstName'] ?? '';
                    final ln = member['lastName'] ?? '';
                    final name = '$fn $ln'.trim().isNotEmpty
                        ? '$fn $ln'.trim()
                        : 'Membre';
                    final role = member['role'] ?? 'STAFF';
                    final isChecked = selectedUserIds.contains(id);

                    return CheckboxListTile(
                      activeColor: AppTheme.evergreen,
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
                      title: Text(name,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppTheme.textColor(context))),
                      subtitle: Text(
                        AppTheme.getRoleLabel(role),
                        style: TextStyle(
                            color: AppTheme.getRoleColor(role),
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              ArjUi.primaryButton(
                context,
                label: 'Créer le groupe',
                icon: Icons.check_rounded,
                color: AppTheme.evergreen,
                onTap: () async {
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
            if (modalRoleFilter != 'ALL' && s['role'] != modalRoleFilter) {
              return false;
            }
            if (modalQuery.isNotEmpty) {
              final q = modalQuery.toLowerCase();
              final fn = (s['firstName'] ?? '').toString().toLowerCase();
              final ln = (s['lastName'] ?? '').toString().toLowerCase();
              if (!fn.contains(q) && !ln.contains(q)) return false;
            }
            return true;
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ArjUi.dragHandle(context),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Nouveau message',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: AppTheme.subtextColor(context)),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ArjUi.searchBar(
                  context,
                  hint: 'Rechercher un collègue...',
                  onChanged: (val) => setModalState(() => modalQuery = val),
                ),
                const SizedBox(height: 12),
                // Role filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        ['ALL', 'DOCTOR', 'NURSE', 'TECHNICIAN', 'MIDWIFE']
                            .map((r) {
                      final label = r == 'ALL'
                          ? 'Tous'
                          : AppTheme.getRoleLabel(r)
                              .split(' ')
                              .first;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ArjUi.filterChip(
                          label: label,
                          isSelected: modalRoleFilter == r,
                          onTap: () =>
                              setModalState(() => modalRoleFilter = r),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                // Create Group Button Option
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.evergreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.group_add_rounded,
                        color: AppTheme.evergreen, size: 22),
                  ),
                  title: Text(
                    'Nouveau groupe d\'équipe',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.evergreen,
                    ),
                  ),
                  subtitle: Text(
                    'Créer un canal de discussion à plusieurs',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.subtextColor(context),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(modalCtx);
                    _showCreateGroupModal();
                  },
                ),
                const Divider(height: 16),
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
                        borderRadius: BorderRadius.circular(16),
                        child: _buildStaffTile(
                            s, api.currentUser?['id']?.toString()),
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
    final isDark = AppTheme.isDarkMode(context);
    final currentUserId = api.currentUser?['id']?.toString() ?? api.currentUser?['_id']?.toString();

    // Channel items definition (removed mock data to eliminate redundancy)
    final priorityChannels = <Map<String, dynamic>>[];

    // Direct message items definition (removed mock data to eliminate redundancy)
    final directMessages = <Map<String, dynamic>>[];

    // Filter logic
    final filteredChannels = priorityChannels.where((c) {
      if (_filter == 'DIRECT') return false;
      if (_filter == 'URGENT' && c['isUrgent'] != true) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final title = (c['title'] as String).toLowerCase();
        final sub = (c['subtitle'] as String).toLowerCase();
        return title.contains(q) || sub.contains(q);
      }
      return true;
    }).toList();

    final filteredDirects = directMessages.where((d) {
      if (_filter == 'CHANNELS') return false;
      if (_filter == 'URGENT' && (d['unreadCount'] as int) == 0) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = (d['name'] as String).toLowerCase();
        final msg = (d['message'] as String).toLowerCase();
        return name.contains(q) || msg.contains(q);
      }
      return true;
    }).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.background,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'messenger_fab',
          backgroundColor: AppTheme.pastelOrange,
          onPressed: _showSelectContactModal,
          icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
          label: const Text('Nouveau Message', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête Méditerranéen Clinique (Evergreen & DarkTeal Gradient) ──
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top > 0 ? MediaQuery.of(context).padding.top + 6 : 12,
                16,
                12,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.evergreen, AppTheme.darkTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    tooltip: 'Retour',
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Messagerie Staff',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Polyclinique El Arij • Canaux & Discussions',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Search Bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkElevated : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 20, color: Color(0xFF6B7E72)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                        style: TextStyle(fontSize: 14, color: AppTheme.textColor(context)),
                        decoration: const InputDecoration(
                          hintText: 'Rechercher un canal, un collègue...',
                          hintStyle: TextStyle(fontSize: 13, color: Color(0xFF6B7E72)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),

            // ── Filter Pills ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterPill('Tous', 'Tous', isDark),
                    const SizedBox(width: 8),
                    _buildFilterPill('Urgences 🚨', 'URGENT', isDark),
                    const SizedBox(width: 8),
                    _buildFilterPill('Canaux 🔬', 'CHANNELS', isDark),
                    const SizedBox(width: 8),
                    _buildFilterPill('Discussions 💬', 'DIRECT', isDark),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── List of Channels, Direct Discussions & Staff ──────────────────
            Expanded(
              child: Builder(
                builder: (context) {
                  final filteredStaff = staffList.where((s) {
                    if (s is! Map) return false;
                    final fn = (s['firstName'] ?? '').toString().toLowerCase();
                    final ln = (s['lastName'] ?? '').toString().toLowerCase();
                    final role = (s['role'] ?? '').toString().toLowerCase();
                    final dept = (s['department'] ?? s['service'] ?? '').toString().toLowerCase();
                    final q = _searchQuery.toLowerCase();
                    return fn.contains(q) || ln.contains(q) || role.contains(q) || dept.contains(q) || '$fn $ln'.contains(q);
                  }).toList();

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      // ── Mode Recherche Active ──
                      if (_searchQuery.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            ' Personnel disponible (${filteredStaff.length})',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.subtextColor(context)),
                          ),
                        ),
                        if (filteredStaff.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text('Aucun soignant ne correspond à "$_searchQuery"', style: TextStyle(color: AppTheme.subtextColor(context))),
                            ),
                          )
                        else
                          ...filteredStaff.map((s) {
                            final sMap = Map<String, dynamic>.from(s);
                            return InkWell(
                              onTap: () => _openChat(sMap, isGroup: false),
                              borderRadius: BorderRadius.circular(16),
                              child: _buildStaffTile(sMap, currentUserId),
                            );
                          }),
                        const SizedBox(height: 16),
                      ],

                      // ── Groups / Channels ──
                      if (groups.isNotEmpty && _filter != 'DIRECT') ...[
                        ...groups.map((g) => _buildGroupTile(g)),
                      ],

                      // ── Active Conversations ──
                      if (conversations.isNotEmpty && _filter != 'CHANNELS') ...[
                        ...conversations.map((c) => _buildConversationTile(c, currentUserId)),
                      ],

                      // ── Tout le Personnel de la Clinique (Quand pas de recherche) ──
                      if (_searchQuery.isEmpty && staffList.isNotEmpty && _filter != 'CHANNELS') ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.people_alt_rounded, size: 16, color: AppTheme.evergreen),
                            const SizedBox(width: 6),
                            Text(
                              'Tout le personnel & Soignants (${staffList.length})',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.evergreen),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...staffList.map((s) {
                          if (s is! Map) return const SizedBox.shrink();
                          final sMap = Map<String, dynamic>.from(s);
                          return InkWell(
                            onTap: () => _openChat(sMap, isGroup: false),
                            borderRadius: BorderRadius.circular(16),
                            child: _buildStaffTile(sMap, currentUserId),
                          );
                        }),
                      ],

                      if (groups.isEmpty && conversations.isEmpty && staffList.isEmpty && !isLoading)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              'Aucune conversation.',
                              style: TextStyle(color: AppTheme.subtextColor(context)),
                            ),
                          ),
                        ),
                      const SizedBox(height: 30),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill(String label, String key, bool isDark) {
    final isSelected = _filter == key;
    return InkWell(
      onTap: () => setState(() => _filter = key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.darkTeal
              : (isDark ? AppTheme.darkElevated : const Color(0xFFEDF2EA)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.darkTeal : (isDark ? AppTheme.darkBorder : AppTheme.border),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? AppTheme.dustGrey : AppTheme.evergreen),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChannel({
    required bool isDark,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String time,
    required String subtitle,
    required Color tagColor,
    required Color tagTextColor,
    required String tagText,
    required bool hasDot,
    String? author,
    bool isUrgent = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUrgent
                ? AppTheme.alertRed.withValues(alpha: 0.3)
                : (isDark ? AppTheme.darkBorder : AppTheme.border),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textColor(context))),
                      Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7E72))),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: AppTheme.subtextColor(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            if (hasDot) ...[
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: isUrgent ? AppTheme.alertRed : tagTextColor, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                            ],
                            Text(tagText, style: TextStyle(fontSize: 11, color: tagTextColor)),
                          ],
                        ),
                      ),
                      if (author != null) ...[
                        const SizedBox(width: 8),
                        Text(author, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7E72))),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectMessage({
    required bool isDark,
    required String imageUrl,
    required String name,
    required String time,
    required String message,
    required int unreadCount,
    required Color statusColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.evergreen.withValues(alpha: 0.2),
                        alignment: Alignment.center,
                        child: Text(
                          name.isNotEmpty ? name[0] : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.evergreen, fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? AppTheme.darkSurface : Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textColor(context))),
                      Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7E72))),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(message, style: TextStyle(fontSize: 13, color: AppTheme.subtextColor(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 16),
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(color: AppTheme.evergreen, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(unreadCount.toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildConversationTile(
      Map<String, dynamic> conv, String? currentUserId) {
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

    final roleLabel = AppTheme.getRoleLabel(role).split(' ').first;
    final roleColor = AppTheme.getRoleColor(role);

    final lastMsg = conv['lastMessageContent'] ?? '';
    final lastTimeRaw = conv['lastMessageAt'];
    String timeStr = '';
    if (lastTimeRaw != null) {
      final dt = DateTime.tryParse(lastTimeRaw.toString());
      if (dt != null) {
        final local = dt.toLocal();
        final now = DateTime.now();
        if (local.day == now.day) {
          timeStr =
              '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
        } else {
          timeStr = 'Hier';
        }
      }
    }

    final unreadMap = conv['unreadCounts'] as Map<String, dynamic>?;
    final unreadCount = currentUserId != null && unreadMap != null
        ? (unreadMap[currentUserId] ?? 0)
        : 0;
    final hasUnread = unreadCount is int ? unreadCount > 0 : false;

    return GestureDetector(
      onTap: () => _openChat(other!, isGroup: false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasUnread
              ? AppTheme.evergreen.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Avatar with online dot
            Stack(
              children: [
                AvatarWidget(
                  avatarUrl: avatarUrl,
                  name: name,
                  role: role,
                  radius: 24,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.backgroundColor(context),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 12),

            // Name + message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: AppTheme.textColor(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUnread
                              ? AppTheme.evergreen
                              : AppTheme.subtextColor(context),
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          roleLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: roleColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lastMsg,
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread
                                ? AppTheme.textColor(context)
                                : AppTheme.subtextColor(context),
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Unread badge
            if (hasUnread) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: AppTheme.evergreen,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTile(Map<String, dynamic> group) {
    final groupName = group['name'] ?? 'Groupe';
    final groupDesc = group['description'] ?? '';
    final id = group['id'] ?? '';
    final isDark = AppTheme.isDarkMode(context);

    Color themeCol;
    IconData icon;
    String badgeText;

    if (id == 'GARDE_URGENCES') {
      themeCol = AppTheme.vitalEmergency;
      icon = CupertinoIcons.heart_fill;
      badgeText = 'Priorité Urgences';
    } else if (id == 'LABO_RADIO') {
      themeCol = AppTheme.evergreen;
      icon = CupertinoIcons.lab_flask_solid;
      badgeText = 'Plateau Tech.';
    } else {
      themeCol = AppTheme.tertiaryTeal;
      icon = CupertinoIcons.person_3_fill;
      badgeText = 'Corps Médical';
    }

    return GestureDetector(
      onTap: () => _openChat(group, isGroup: true),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: themeCol.withValues(alpha: isDark ? 0.12 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: themeCol.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: themeCol, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          groupName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textColor(context),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: themeCol.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: themeCol,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (groupDesc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      groupDesc,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.subtextColor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.subtextColor(context).withValues(alpha: 0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffTile(Map<String, dynamic> staff, String? currentUserId) {
    final fn = staff['firstName'] ?? '';
    final ln = staff['lastName'] ?? '';
    final name = '$fn $ln'.trim().isNotEmpty ? '$fn $ln'.trim() : 'Collègue';
    final role = staff['role'] ?? 'STAFF';
    final avatarUrl = staff['avatarUrl'];
    final roleLabel = AppTheme.getRoleLabel(role).split(' ').first;
    final roleColor = AppTheme.getRoleColor(role);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          AvatarWidget(
            avatarUrl: avatarUrl,
            name: name,
            role: role,
            radius: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  roleLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: roleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppTheme.subtextColor(context)),
        ],
      ),
    );
  }
}
