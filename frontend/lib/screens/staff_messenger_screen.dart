import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
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
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                      color: AppTheme.purpleColor(context)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                  labelText: 'Description (optionnelle)',
                  prefixIcon: Icon(Icons.description_outlined,
                      color: AppTheme.purpleColor(context)),
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
                      activeColor: AppTheme.purpleColor(context),
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
                color: AppTheme.purpleColor(context),
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
                  const BorderRadius.vertical(top: Radius.circular(28)),
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
                      color: AppTheme.purpleColor(context).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.group_add_rounded,
                        color: AppTheme.purpleColor(context), size: 22),
                  ),
                  title: Text(
                    'Nouveau groupe d\'équipe',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.purpleColor(context),
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
    final currentUserId = api.currentUser?['id'] ?? api.currentUser?['_id'];
    final user = api.currentUser;
    final userRole = user?['role'];
    final fullName =
        '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'.trim();
    final roleColor = AppTheme.getRoleColor(userRole);

    // Filter logic
    List<dynamic> filteredConversations;
    if (_filter == 'Non lus') {
      filteredConversations = conversations.where((c) {
        final unreadMap = c['unreadCounts'] as Map<String, dynamic>?;
        final unread = currentUserId != null && unreadMap != null
            ? (unreadMap[currentUserId.toString()] ?? 0)
            : 0;
        return unread > 0;
      }).toList();
    } else if (_filter == 'Équipes') {
      filteredConversations = [];
    } else {
      filteredConversations = conversations;
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredConversations = filteredConversations.where((c) {
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
    }

    // ── Sort conversations ──────────────────────────────────────
    if (_sortMode == 'A-Z') {
      filteredConversations.sort((a, b) {
        String nameOf(dynamic conv) {
          final parts = (conv['participants'] as List?) ?? [];
          for (var p in parts) {
            if (p is Map) {
              final pid = (p['_id'] ?? p['id'])?.toString();
              if (pid != null && pid != currentUserId?.toString()) {
                return '${p['lastName'] ?? ''} ${p['firstName'] ?? ''}'.trim();
              }
            }
          }
          return '';
        }
        return nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase());
      });
    } else if (_sortMode == 'Par rôle') {
      const roleOrder = ['DOCTOR', 'NURSE', 'MIDWIFE', 'TECHNICIAN'];
      filteredConversations.sort((a, b) {
        String roleOf(dynamic conv) {
          final parts = (conv['participants'] as List?) ?? [];
          for (var p in parts) {
            if (p is Map) {
              final pid = (p['_id'] ?? p['id'])?.toString();
              if (pid != null && pid != currentUserId?.toString()) {
                return (p['role'] ?? '').toString();
              }
            }
          }
          return '';
        }
        final ia = roleOrder.indexOf(roleOf(a));
        final ib = roleOrder.indexOf(roleOf(b));
        return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
      });
    }
    // 'Récents' keeps server order (already sorted by lastMessageAt)

    final showGroups = _filter == 'Tous' || _filter == 'Équipes';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.backgroundColor(context),
      drawer: AppDrawer(
        onSelectTab: (_) {},
        onOpenProfile: _openProfile,
        onLogout: widget.onLogout,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Figma Header ─────────────────────────────────────────────
            FigmaHeader(
              roleName: 'MESSAGES',
              roleColor: roleColor,
              onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
              onThemeToggle: AppTheme.toggleTheme,
              onNotificationsPressed: () {},
              profileImageUrl: user?['avatarUrl'],
              userName: fullName,
            ),

            // ── Page title ────────────────────────────────────────────────
            // ── Page title & Action ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Boîte de réception',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor(context),
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showSelectContactModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryBondi,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.secondaryBondi.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Nouveau',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Search bar & Filter Dropdown ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderColor(context)),
                      ),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.search, size: 18, color: AppTheme.subtextColor(context)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) => setState(() => _searchQuery = val),
                              style: TextStyle(fontSize: 14, color: AppTheme.textColor(context)),
                              decoration: InputDecoration(
                                hintText: 'Rechercher une conversation...',
                                hintStyle: TextStyle(fontSize: 14, color: AppTheme.subtextColor(context)),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: Icon(Icons.close_rounded, size: 18, color: AppTheme.subtextColor(context)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Dropdown Filter Button
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      setState(() {
                        if (val.startsWith('filter:')) {
                          _filter = val.replaceFirst('filter:', '');
                        } else if (val.startsWith('sort:')) {
                          _sortMode = val.replaceFirst('sort:', '');
                        }
                      });
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: AppTheme.isDarkMode(context) ? AppTheme.darkCard : Colors.white,
                    elevation: 8,
                    itemBuilder: (ctx) => [
                      PopupMenuItem<String>(
                        enabled: false,
                        height: 28,
                        child: Text(
                          'FILTRE DE LECTURE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.subtextColor(context),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      _buildPopupOption('filter:Tous', 'Toutes les discussions', _filter == 'Tous', CupertinoIcons.chat_bubble_2_fill),
                      _buildPopupOption('filter:Non lus', 'Messages non lus', _filter == 'Non lus', CupertinoIcons.bell_fill),
                      _buildPopupOption('filter:Équipes', 'Canaux d\'équipe uniquement', _filter == 'Équipes', CupertinoIcons.person_3_fill),
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        enabled: false,
                        height: 28,
                        child: Text(
                          'ORDRE DE TRI',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.subtextColor(context),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      _buildPopupOption('sort:Récents', 'Plus récents d\'abord', _sortMode == 'Récents', CupertinoIcons.clock_fill),
                      _buildPopupOption('sort:A-Z', 'Nom alphabétique (A-Z)', _sortMode == 'A-Z', CupertinoIcons.textformat_abc),
                      _buildPopupOption('sort:Par rôle', 'Par profession / rôle', _sortMode == 'Par rôle', CupertinoIcons.briefcase_fill),
                    ],
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: (_filter != 'Tous' || _sortMode != 'Récents')
                            ? AppTheme.secondaryBondi.withValues(alpha: 0.12)
                            : AppTheme.surfaceColor(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: (_filter != 'Tous' || _sortMode != 'Récents')
                              ? AppTheme.secondaryBondi
                              : AppTheme.borderColor(context),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.slider_horizontal_3,
                            size: 18,
                            color: (_filter != 'Tous' || _sortMode != 'Récents')
                                ? AppTheme.secondaryBondi
                                : AppTheme.textColor(context),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _filter == 'Tous' ? _sortMode : _filter,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: (_filter != 'Tous' || _sortMode != 'Récents')
                                  ? AppTheme.secondaryBondi
                                  : AppTheme.textColor(context),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: (_filter != 'Tous' || _sortMode != 'Récents')
                                ? AppTheme.secondaryBondi
                                : AppTheme.subtextColor(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Active filter tag (if not default) ──────────────────────────
            if (_filter != 'Tous' || _sortMode != 'Récents')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryBondi.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.secondaryBondi.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Filtre : $_filter • Tri : $_sortMode',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.secondaryBondi,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() {
                              _filter = 'Tous';
                              _sortMode = 'Récents';
                            }),
                            child: const Icon(Icons.cancel_rounded, size: 14, color: AppTheme.secondaryBondi),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ── Conversation list ───────────────────────────────────────────
            Expanded(
              child: isLoading
                  ? const Center(child: CupertinoActivityIndicator(radius: 14))
                  : RefreshIndicator(
                      color: AppTheme.secondaryBondi,
                      onRefresh: _loadConversations,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          if (filteredConversations.isEmpty && _filter != 'Équipes')
                            Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: ArjUi.emptyState(
                                context,
                                icon: Icons.chat_bubble_outline_rounded,
                                title: 'Aucune conversation',
                                subtitle:
                                    'Démarrez une nouvelle discussion avec un collègue.',
                                action: GestureDetector(
                                  onTap: _showSelectContactModal,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondaryBondi,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Nouveau message',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Conversations
                          ...filteredConversations.map((c) =>
                              _buildConversationTile(
                                  c, currentUserId?.toString())),

                          // Groups section
                          if (showGroups && groups.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Text(
                                    'Canaux d\'équipe',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textColor(context),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: _showCreateGroupModal,
                                    child: Text(
                                      '+ Créer',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.secondaryBondi,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...groups.map((g) => _buildGroupTile(g)),
                          ],

                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: IosBottomNavBar(
        selectedIndex: 3,
        onItemSelected: (idx) {
          if (idx != 3) {
            Navigator.pop(context);
          }
        },
        activeColor: AppTheme.secondaryBondi,
        items: const [
          IosBottomNavItem(
            icon: CupertinoIcons.house,
            selectedIcon: CupertinoIcons.house_fill,
            label: 'Accueil',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.person_2,
            selectedIcon: CupertinoIcons.person_2_fill,
            label: 'Patients',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.doc_text,
            selectedIcon: CupertinoIcons.doc_text_fill,
            label: 'Activités',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.chat_bubble_2,
            selectedIcon: CupertinoIcons.chat_bubble_2_fill,
            label: 'Messages',
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupOption(
      String value, String label, bool isSelected, IconData icon) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? AppTheme.secondaryBondi : AppTheme.subtextColor(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.secondaryBondi : AppTheme.textColor(context),
              ),
            ),
          ),
          if (isSelected)
            const Icon(
              Icons.check_rounded,
              size: 18,
              color: AppTheme.secondaryBondi,
            ),
        ],
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
              ? AppTheme.secondaryBondi.withValues(alpha: 0.08)
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
                              ? AppTheme.secondaryBondi
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
                  color: AppTheme.secondaryBondi,
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
      themeCol = AppTheme.secondaryBondi;
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
