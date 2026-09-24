import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../screens/patient_dossier_screen.dart';
import 'avatar_widget.dart';

/// Vue complète et interactive des Chambres et Lits de la clinique.
/// Permet à tous les soignants (Infirmiers, Médecins, Sages-femmes, Staff) :
/// 1. D'avoir une visibilité claire par numéro de chambre et de lits (chambres à 1, 2 ou plusieurs lits).
/// 2. D'affecter un patient à une chambre et un lit disponible.
/// 3. De libérer un lit / effectuer la sortie d'hospitalisation.
/// 4. D'accéder directement au dossier médical du patient hospitalisé.
class RoomsAndBedsView extends StatefulWidget {
  final VoidCallback? onRefreshParent;
  final String? initialServiceFilter;
  final bool isMidwifeView;

  const RoomsAndBedsView({
    super.key,
    this.onRefreshParent,
    this.initialServiceFilter,
    this.isMidwifeView = false,
  });

  @override
  State<RoomsAndBedsView> createState() => _RoomsAndBedsViewState();
}

class _RoomsAndBedsViewState extends State<RoomsAndBedsView> {
  final api = ApiService();
  bool isLoading = true;
  String _searchQuery = '';
  String _selectedService = 'ALL';
  String _selectedStatusFilter = 'ALL'; // ALL, HAS_AVAILABLE, FULL

  List<dynamic> rooms = [];
  List<dynamic> patients = [];
  List<dynamic> doctors = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialServiceFilter != null) {
      _selectedService = widget.initialServiceFilter!;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final fetchedRooms = await api.getRoomsWithBeds();
      final fetchedPatients = await api.getPatients();
      final fetchedDoctors = await api.getDoctors();

      if (mounted) {
        setState(() {
          rooms = fetchedRooms;
          patients = fetchedPatients;
          doctors = fetchedDoctors;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- STATS COMPUTATION ---
  int get totalBeds => rooms.fold<int>(0, (sum, r) => sum + (r['totalBeds'] as int? ?? (r['beds'] as List?)?.length ?? 0));
  int get occupiedBeds => rooms.fold<int>(0, (sum, r) => sum + (r['occupiedBeds'] as int? ?? 0));
  int get availableBeds => totalBeds - occupiedBeds;
  int get occupancyRate => totalBeds > 0 ? ((occupiedBeds / totalBeds) * 100).round() : 0;

  // --- FILTERING ---
  List<dynamic> get filteredRooms {
    return rooms.where((r) {
      final serv = (r['service'] ?? '').toString();
      final num = (r['number'] ?? '').toString().toLowerCase();
      final floor = (r['floor'] ?? '').toString().toLowerCase();
      final bedsList = (r['beds'] as List<dynamic>?) ?? [];

      // Service filter
      if (_selectedService != 'ALL' && !serv.toLowerCase().contains(_selectedService.toLowerCase())) {
        return false;
      }

      // Status filter
      final occCount = r['occupiedBeds'] as int? ?? 0;
      final totCount = r['totalBeds'] as int? ?? bedsList.length;
      if (_selectedStatusFilter == 'HAS_AVAILABLE' && occCount >= totCount) {
        return false;
      }
      if (_selectedStatusFilter == 'FULL' && occCount < totCount) {
        return false;
      }

      // Search query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchesRoom = num.contains(q) || floor.contains(q) || serv.toLowerCase().contains(q);
        final matchesPatientOrBed = bedsList.any((b) {
          final bNum = (b['number'] ?? '').toString().toLowerCase();
          final pat = b['currentPatient'];
          if (pat is Map) {
            final fn = (pat['firstName'] ?? '').toString().toLowerCase();
            final ln = (pat['lastName'] ?? '').toString().toLowerCase();
            final cin = (pat['cin'] ?? '').toString().toLowerCase();
            final dNum = (pat['dossierNumber'] ?? '').toString().toLowerCase();
            return bNum.contains(q) || fn.contains(q) || ln.contains(q) || cin.contains(q) || dNum.contains(q);
          }
          return bNum.contains(q);
        });
        if (!matchesRoom && !matchesPatientOrBed) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CupertinoActivityIndicator(radius: 14),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.tropicalTeal,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // ── KPI Summary Cards ─────────────────────────────────────────────
          _buildOccupancyHeader(isDark),

          const SizedBox(height: 16),

          // ── Search Bar ───────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher une chambre, un lit ou un patient...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(CupertinoIcons.search, size: 18, color: AppTheme.tropicalTeal),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          const SizedBox(height: 12),

          // ── Service Filter Chips ──────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildServiceChip('ALL', 'Tous les services'),
                const SizedBox(width: 8),
                _buildServiceChip('Maternité', 'Maternité'),
                const SizedBox(width: 8),
                _buildServiceChip('Chirurgie', 'Chirurgie'),
                const SizedBox(width: 8),
                _buildServiceChip('Réa', 'Soins Intensifs & Réa'),
                const SizedBox(width: 8),
                _buildServiceChip('Médecine', 'Médecine Interne'),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Status Filters & Count ────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredRooms.length} Chambre${filteredRooms.length > 1 ? 's' : ''} répertoriée${filteredRooms.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textColor(context),
                ),
              ),
              Row(
                children: [
                  _buildStatusPill('ALL', 'Toutes'),
                  const SizedBox(width: 6),
                  _buildStatusPill('HAS_AVAILABLE', 'Disponibles'),
                  const SizedBox(width: 6),
                  _buildStatusPill('FULL', 'Complètes'),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Room Cards List ───────────────────────────────────────────────
          if (filteredRooms.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(CupertinoIcons.bed_double, size: 48, color: AppTheme.subtextColor(context).withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text(
                    'Aucune chambre ne correspond à votre filtre.',
                    style: TextStyle(color: AppTheme.subtextColor(context), fontSize: 14),
                  ),
                ],
              ),
            )
          else
            ...filteredRooms.map((room) => _buildRoomCard(room, isDark)),
        ],
      ),
    );
  }

  // ── Header Occupancy Stats ────────────────────────────────────────────────
  Widget _buildOccupancyHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.tropicalTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.bed_double_fill, size: 20, color: AppTheme.tropicalTeal),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Occupation des Lits & Chambres',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                      Text(
                        'Polyclinique El Arij — Gestion en temps réel',
                        style: TextStyle(fontSize: 11, color: AppTheme.subtextColor(context)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: occupancyRate > 80
                      ? AppTheme.danger.withValues(alpha: 0.12)
                      : AppTheme.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$occupancyRate% Occupé',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: occupancyRate > 80 ? AppTheme.danger : const Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 3 Metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Total Lits',
                  value: '$totalBeds',
                  color: AppTheme.bondiBlue,
                  bg: AppTheme.bondiBlue.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Disponibles',
                  value: '$availableBeds',
                  color: AppTheme.emerald,
                  bg: AppTheme.emerald.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'Occupés',
                  value: '$occupiedBeds',
                  color: AppTheme.tropicalTeal,
                  bg: AppTheme.tropicalTeal.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  // ── Filter Chips ──────────────────────────────────────────────────────────
  Widget _buildServiceChip(String key, String label) {
    final isSelected = _selectedService == key;
    final isDark = AppTheme.isDarkMode(context);
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.tropicalTeal,
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isSelected ? AppTheme.tropicalTeal : AppTheme.borderColor(context)),
      ),
      onSelected: (_) => setState(() => _selectedService = key),
    );
  }

  Widget _buildStatusPill(String key, String label) {
    final isSelected = _selectedStatusFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatusFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.tropicalTeal.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.tropicalTeal : AppTheme.borderColor(context),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.tropicalTeal : AppTheme.subtextColor(context),
          ),
        ),
      ),
    );
  }

  // ── Single Room Card with grouped beds ────────────────────────────────────
  Widget _buildRoomCard(Map<String, dynamic> room, bool isDark) {
    final roomNum = room['number'] ?? 'CH-?';
    final service = room['service'] ?? 'Général';
    final floor = room['floor'] ?? 'Étage';
    final capacity = room['capacity'] ?? 1;
    final bedsList = (room['beds'] as List<dynamic>?) ?? [];
    final totalRoomBeds = bedsList.length;
    final occupiedRoomBeds = bedsList.where((b) => b['isOccupied'] == true).length;
    final isFull = totalRoomBeds > 0 && occupiedRoomBeds >= totalRoomBeds;

    Color serviceColor = AppTheme.tropicalTeal;
    if (service.toLowerCase().contains('mat')) serviceColor = AppTheme.oceanMist;
    if (service.toLowerCase().contains('chir')) serviceColor = AppTheme.bondiBlue;
    if (service.toLowerCase().contains('réa') || service.toLowerCase().contains('intensif')) {
      serviceColor = const Color(0xFF0284C7);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Room Header Bar ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151E2E) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: AppTheme.borderColor(context))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: serviceColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(CupertinoIcons.house_alt_fill, size: 18, color: serviceColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            roomNum,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textColor(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: serviceColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              service,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: serviceColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$floor • Capacité : $capacity lit${capacity > 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 12, color: AppTheme.subtextColor(context)),
                      ),
                    ],
                  ),
                ),
                // Room occupancy badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFull
                        ? AppTheme.danger.withValues(alpha: 0.1)
                        : (occupiedRoomBeds > 0
                            ? AppTheme.bondiBlue.withValues(alpha: 0.12)
                            : AppTheme.emerald.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isFull
                        ? 'Complet ($occupiedRoomBeds/$totalRoomBeds)'
                        : (occupiedRoomBeds > 0
                            ? '$occupiedRoomBeds/$totalRoomBeds Occupé'
                            : 'Disponible ($totalRoomBeds lits)'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isFull
                          ? AppTheme.danger
                          : (occupiedRoomBeds > 0 ? AppTheme.bondiBlue : const Color(0xFF047857)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Beds List in this Room ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: bedsList.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'Aucun lit configuré pour cette chambre.',
                        style: TextStyle(color: AppTheme.subtextColor(context), fontSize: 13),
                      ),
                    ),
                  )
                : Column(
                    children: bedsList.map((bed) => _buildBedItem(room, bed, isDark)).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Single Bed inside Room ────────────────────────────────────────────────
  Widget _buildBedItem(Map<String, dynamic> room, Map<String, dynamic> bed, bool isDark) {
    final bedNumber = bed['number'] ?? 'Lit';
    final isOccupied = bed['isOccupied'] == true || bed['status'] == 'OCCUPIED';
    final patient = bed['currentPatient'];
    final stay = bed['currentStay'];

    String patName = 'Patient Inconnu';
    String patCin = '—';
    String dossierNum = '—';
    if (patient is Map) {
      final fn = patient['firstName'] ?? '';
      final ln = patient['lastName'] ?? '';
      patName = '$fn $ln'.trim().isNotEmpty ? '$fn $ln'.trim() : 'Patient';
      patCin = patient['cin']?.toString() ?? '—';
      dossierNum = patient['dossierNumber']?.toString() ?? '—';
    }

    String admissionDateStr = '';
    if (stay is Map && stay['admissionDate'] != null) {
      final dt = DateTime.tryParse(stay['admissionDate'].toString());
      if (dt != null) {
        admissionDateStr = 'Admis le ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }
    final reason = stay is Map ? (stay['admissionReason'] ?? '') : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOccupied
            ? (isDark ? const Color(0xFF1A2634) : const Color(0xFFF0FDF4))
            : (isDark ? const Color(0xFF172033) : const Color(0xFFFAFAFA)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOccupied
              ? AppTheme.emerald.withValues(alpha: 0.3)
              : AppTheme.borderColor(context),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bed Number & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.bed_double,
                    size: 18,
                    color: isOccupied ? AppTheme.tropicalTeal : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    bedNumber,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOccupied
                      ? AppTheme.tropicalTeal.withValues(alpha: 0.15)
                      : AppTheme.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOccupied ? AppTheme.tropicalTeal : const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOccupied ? 'OCCUPÉ' : 'DISPONIBLE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isOccupied ? AppTheme.tropicalTeal : const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Bed Details: Occupied vs Available
          if (isOccupied) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AvatarWidget(
                  name: patName,
                  role: 'PATIENT',
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                      Text(
                        'CIN: $patCin | Dossier: $dossierNum',
                        style: TextStyle(fontSize: 11, color: AppTheme.subtextColor(context)),
                      ),
                      if (admissionDateStr.isNotEmpty)
                        Text(
                          admissionDateStr,
                          style: TextStyle(fontSize: 11, color: AppTheme.bondiBlue, fontWeight: FontWeight.w500),
                        ),
                      if (reason.toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Motif : $reason',
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.subtextColor(context)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Actions for Occupied Bed
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (patient is Map)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.bondiBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(CupertinoIcons.folder_fill, size: 15),
                    label: const Text('Dossier', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientDossierScreen(patient: Map<String, dynamic>.from(patient)),
                        ),
                      );
                    },
                  ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.danger, width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(CupertinoIcons.clear_circled_solid, size: 15, color: AppTheme.danger),
                  label: const Text('Libérer le lit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _confirmFreeBed(room, bed, patName),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Prêt à recevoir une admission',
                  style: TextStyle(fontSize: 12, color: AppTheme.subtextColor(context)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.tropicalTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(CupertinoIcons.person_badge_plus_fill, size: 16),
                  label: const Text('Affecter un Patient', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () => _showAdmitPatientModal(room, bed),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Modal : Affecter un patient à une chambre & lit ───────────────────────
  void _showAdmitPatientModal(Map<String, dynamic> room, Map<String, dynamic> bed) {
    String? selectedPatientId;
    String? selectedDoctorId;
    final reasonController = TextEditingController(
      text: room['service'] == 'Maternité'
          ? 'Surveillance obstétricale & suites de couches'
          : 'Hospitalisation & surveillance clinique',
    );
    String patientSearch = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final isDark = AppTheme.isDarkMode(context);
          final filteredPatients = patients.where((p) {
            if (patientSearch.trim().isEmpty) return true;
            final q = patientSearch.trim().toLowerCase();
            final fn = (p['firstName'] ?? '').toString().toLowerCase();
            final ln = (p['lastName'] ?? '').toString().toLowerCase();
            final cin = (p['cin'] ?? '').toString().toLowerCase();
            final dNum = (p['dossierNumber'] ?? '').toString().toLowerCase();
            return fn.contains(q) || ln.contains(q) || cin.contains(q) || dNum.contains(q);
          }).toList();

          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.tropicalTeal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(CupertinoIcons.bed_double_fill, color: AppTheme.tropicalTeal, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Affecter un Patient au Lit',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Chambre ${room['number']} (${room['service']}) — ${bed['number']}',
                              style: TextStyle(fontSize: 12, color: AppTheme.tropicalTeal, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search patient
                  const Text('Sélectionner le Patient *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor(context)),
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Filtrer par nom ou CIN...',
                        prefixIcon: Icon(CupertinoIcons.search, size: 16),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (val) => setModalState(() => patientSearch = val),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor(context)),
                    ),
                    child: filteredPatients.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: Text('Aucun patient trouvé')),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: filteredPatients.length,
                            separatorBuilder: (_, _) => Divider(height: 1, color: AppTheme.borderColor(context)),
                            itemBuilder: (ctx, idx) {
                              final p = filteredPatients[idx];
                              final pid = p['_id']?.toString() ?? p['id']?.toString();
                              final name = '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim();
                              final isSelected = selectedPatientId == pid;

                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: AppTheme.tropicalTeal.withValues(alpha: 0.12),
                                title: Text(name.isNotEmpty ? name : 'Patient', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('CIN: ${p['cin'] ?? '—'} | N°: ${p['dossierNumber'] ?? '—'}'),
                                trailing: isSelected
                                    ? const Icon(CupertinoIcons.checkmark_circle_fill, color: AppTheme.tropicalTeal, size: 20)
                                    : null,
                                onTap: () => setModalState(() => selectedPatientId = pid),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 14),

                  // Reason for admission
                  const Text('Motif d\'hospitalisation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText: 'Ex: Surveillance post-opératoire, accouchement...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Doctor assignment (optional)
                  if (doctors.isNotEmpty) ...[
                    const Text('Médecin référent (optionnel)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDoctorId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      hint: const Text('Sélectionner un médecin'),
                      items: doctors.map<DropdownMenuItem<String>>((d) {
                        final u = d['userId'] is Map ? d['userId'] : (d['user'] is Map ? d['user'] : null);
                        final name = 'Dr. ${d['firstName'] ?? u?['firstName'] ?? ''} ${d['lastName'] ?? u?['lastName'] ?? ''}'.trim();
                        return DropdownMenuItem<String>(
                          value: d['_id']?.toString(),
                          child: Text(name.isNotEmpty ? name : 'Médecin'),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedDoctorId = val),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(modalCtx),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.tropicalTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: selectedPatientId == null
                              ? null
                              : () async {
                                  Navigator.pop(modalCtx);
                                  await _executeAdmitPatient(
                                    patientId: selectedPatientId!,
                                    bedId: bed['_id'].toString(),
                                    service: room['service'] ?? 'Hospitalisation',
                                    reason: reasonController.text.trim(),
                                    doctorId: selectedDoctorId,
                                  );
                                },
                          child: const Text('Confirmer l\'affectation', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _executeAdmitPatient({
    required String patientId,
    required String bedId,
    required String service,
    required String reason,
    String? doctorId,
  }) async {
    try {
      await api.admitPatient(
        patientId: patientId,
        bedId: bedId,
        service: service,
        admissionReason: reason,
        doctorId: doctorId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF047857),
            content: Text(' Patient affecté à la chambre avec succès.'),
          ),
        );
      }
      await _loadData();
      widget.onRefreshParent?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Erreur : $e'),
          ),
        );
      }
    }
  }

  // ── Confirmation Dialogue : Libérer le Lit ────────────────────────────────
  Future<void> _confirmFreeBed(Map<String, dynamic> room, Map<String, dynamic> bed, String patName) async {
    final bedId = bed['_id']?.toString() ?? bed['id']?.toString() ?? '';
    final bedNum = bed['number'] ?? 'Lit';
    final roomNum = room['number'] ?? 'Chambre';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(CupertinoIcons.clear_circled_solid, color: AppTheme.danger, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Libérer le lit ?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'Voulez-vous libérer le lit $bedNum ($roomNum) actuellement occupé par $patName ?\n\nLe lit redeviendra immédiatement disponible pour une nouvelle admission.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: AppTheme.subtextColor(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Libérer le lit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await api.freeBed(bedId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF1E293B),
              content: Text('🛏️ $bedNum de la $roomNum libéré avec succès.'),
            ),
          );
        }
        await _loadData();
        widget.onRefreshParent?.call();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.danger,
              content: Text('Erreur : $e'),
            ),
          );
        }
      }
    }
  }
}
