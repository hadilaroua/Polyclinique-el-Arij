import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class SmartPatientMonitoringView extends StatefulWidget {
  final String patientId;
  final String patientName;
  final VoidCallback? onNavigateToTimeline;

  const SmartPatientMonitoringView({
    super.key,
    required this.patientId,
    required this.patientName,
    this.onNavigateToTimeline,
  });

  @override
  State<SmartPatientMonitoringView> createState() => _SmartPatientMonitoringViewState();
}

class _SmartPatientMonitoringViewState extends State<SmartPatientMonitoringView> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String _selectedPeriod = '24h';
  String _selectedMetric = 'temperature'; // 'temperature', 'oxygenSaturation', 'heartRate', 'bloodPressureSys'
  int? _selectedPointIndex;

  Map<String, dynamic>? _monitoringData;

  final List<Map<String, String>> _periodTabs = [
    {'id': '24h', 'label': '24 heures'},
    {'id': '7d', 'label': '7 jours'},
    {'id': '30d', 'label': '30 jours'},
  ];

  @override
  void initState() {
    super.initState();
    _loadMonitoring();
  }

  Future<void> _loadMonitoring() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getSmartPatientMonitoring(
        widget.patientId,
        period: _selectedPeriod,
      );
      if (mounted) {
        setState(() {
          _monitoringData = res;
          _selectedPointIndex = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _onPeriodChanged(String period) {
    if (_selectedPeriod == period) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedPeriod = period);
    _loadMonitoring();
  }

  void _selectMetric(String metricKey) {
    if (_selectedMetric == metricKey) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMetric = metricKey;
      _selectedPointIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return _loading
        ? const Center(child: CupertinoActivityIndicator(radius: 14))
        : RefreshIndicator(
            onRefresh: _loadMonitoring,
            color: AppTheme.bondiBlue,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── En-tête : Titre & Sélecteur de Période ─────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007EA7).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(CupertinoIcons.waveform_path_ecg, size: 20, color: Color(0xFF007EA7)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Surveillance du Patient',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textColor(context),
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Analyse continue des tendances & détection de variations',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.subtextColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Segment Période iOS (24h | 7j | 30j)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: _periodTabs.map((p) {
                        final isSelected = _selectedPeriod == p['id'];
                        return Expanded(
                          child: InkWell(
                            onTap: () => _onPeriodChanged(p['id']!),
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? const Color(0xFF0B2545) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                p['label']!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected
                                      ? AppTheme.bondiBlue
                                      : AppTheme.subtextColor(context),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Alertes & Variations à surveiller (si détectées) ───────
                  _buildAlertsSection(context, isDark),

                  // ── Cartes Synthétiques des 4 Constantes ───────────────────
                  _buildVitalCardsGrid(context, isDark),
                  const SizedBox(height: 20),

                  // ── Graphique Linéaire iOS Interactif ─────────────────────
                  _buildInteractiveChartCard(context, isDark),
                  const SizedBox(height: 16),

                  // ── Avertissement Légal & Non-Diagnostique ─────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B293C) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor(context)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(CupertinoIcons.shield_lefthalf_fill, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _monitoringData?['disclaimer'] ??
                                'Les indicateurs sont calculés selon des seuils de suivi paramétrés. Cet outil de visualisation ne constitue pas un diagnostic clinique et ne remplace pas l\'évaluation médicale.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: AppTheme.subtextColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
  }

  // ===========================================================================
  // ── SECTION ALERTES ET VARIATIONS ──────────────────────────────────────────
  // ===========================================================================

  Widget _buildAlertsSection(BuildContext context, bool isDark) {
    final alerts = (_monitoringData?['activeRulesAlerts'] as List<dynamic>?) ?? [];
    if (alerts.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.checkmark_shield_fill, size: 18, color: Color(0xFF10B981)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🟢 Constantes stables sur la période',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  Text(
                    'Aucune variation anormale détectée selon les règles de surveillance configurées.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: alerts.map((alert) {
        final severity = alert['severity'] ?? 'WARNING';
        final isCritical = severity == 'CRITICAL';
        final color = isCritical ? const Color(0xFFE11D48) : const Color(0xFFF59E0B);
        final title = alert['title'] ?? 'Variation détectée';
        final desc = alert['description'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isCritical ? CupertinoIcons.exclamationmark_octagon_fill : CupertinoIcons.exclamationmark_triangle_fill,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                        if (widget.onNavigateToTimeline != null)
                          InkWell(
                            onTap: widget.onNavigateToTimeline,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Timeline',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(CupertinoIcons.arrow_right, size: 10, color: color),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ===========================================================================
  // ── CARTES DES CONSTANTES ──────────────────────────────────────────────────
  // ===========================================================================

  Widget _buildVitalCardsGrid(BuildContext context, bool isDark) {
    final vitals = _monitoringData?['vitals'] as Map<String, dynamic>? ?? {};

    final temp = vitals['temperature'] as Map<String, dynamic>?;
    final spo2 = vitals['oxygenSaturation'] as Map<String, dynamic>?;
    final hr = vitals['heartRate'] as Map<String, dynamic>?;
    final bpSys = vitals['bloodPressureSys'] as Map<String, dynamic>?;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildVitalCard(
                context: context,
                isDark: isDark,
                metricKey: 'temperature',
                title: 'Température',
                currentValue: temp?['currentValue'] != null ? '${temp!['currentValue']} ${temp['unit']}' : '--',
                unit: temp?['unit'] ?? '°C',
                trendSequence: (temp?['trendSequence'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
                status: temp?['status'] ?? 'NORMAL',
                statusLabel: temp?['statusLabel'] ?? 'Normal',
                icon: CupertinoIcons.thermometer,
                color: const Color(0xFFE11D48),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildVitalCard(
                context: context,
                isDark: isDark,
                metricKey: 'oxygenSaturation',
                title: 'SpO₂',
                currentValue: spo2?['currentValue'] != null ? '${spo2!['currentValue']} ${spo2['unit']}' : '--',
                unit: spo2?['unit'] ?? '%',
                trendSequence: (spo2?['trendSequence'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
                status: spo2?['status'] ?? 'NORMAL',
                statusLabel: spo2?['statusLabel'] ?? 'Normal',
                icon: CupertinoIcons.wind,
                color: const Color(0xFF007EA7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildVitalCard(
                context: context,
                isDark: isDark,
                metricKey: 'heartRate',
                title: 'Fréquence Card.',
                currentValue: hr?['currentValue'] != null ? '${hr!['currentValue']} ${hr['unit']}' : '--',
                unit: hr?['unit'] ?? 'bpm',
                trendSequence: (hr?['trendSequence'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
                status: hr?['status'] ?? 'NORMAL',
                statusLabel: hr?['statusLabel'] ?? 'Normal',
                icon: CupertinoIcons.heart_fill,
                color: const Color(0xFF00A896),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildVitalCard(
                context: context,
                isDark: isDark,
                metricKey: 'bloodPressureSys',
                title: 'Tension Artér.',
                currentValue: bpSys?['currentValue'] != null ? '${bpSys!['currentValue']} ${bpSys['unit']}' : '--',
                unit: bpSys?['unit'] ?? 'mmHg',
                trendSequence: (bpSys?['trendSequence'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
                status: bpSys?['status'] ?? 'NORMAL',
                statusLabel: bpSys?['statusLabel'] ?? 'Normal',
                icon: CupertinoIcons.gauge,
                color: const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVitalCard({
    required BuildContext context,
    required bool isDark,
    required String metricKey,
    required String title,
    required String currentValue,
    required String unit,
    required List<String> trendSequence,
    required String status,
    required String statusLabel,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedMetric == metricKey;
    final isAlert = status == 'WARNING' || status == 'CRITICAL';
    final statusColor = status == 'CRITICAL'
        ? const Color(0xFFE11D48)
        : status == 'WARNING'
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    return InkWell(
      onTap: () => _selectMetric(metricKey),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B293C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : (isAlert ? statusColor.withValues(alpha: 0.5) : AppTheme.borderColor(context)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: isSelected ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre & Icône
            Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Valeur actuelle
            Text(
              currentValue,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textColor(context),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),

            // Séquence historique e.g. 37.1 → 37.3 → 37.8 → 38.1
            if (trendSequence.isNotEmpty)
              Text(
                trendSequence.join(' → '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isAlert ? statusColor : AppTheme.subtextColor(context),
                ),
              )
            else
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // ── GRAPHIQUE LINÉAIRE INTERACTIF ──────────────────────────────────────────
  // ===========================================================================

  Widget _buildInteractiveChartCard(BuildContext context, bool isDark) {
    final vitals = _monitoringData?['vitals'] as Map<String, dynamic>? ?? {};
    final currentMetricData = vitals[_selectedMetric] as Map<String, dynamic>?;

    final history = (currentMetricData?['history'] as List<dynamic>?) ?? [];
    final unit = currentMetricData?['unit'] ?? '';
    final metricName = _getMetricTitle(_selectedMetric);
    final metricColor = _getMetricColor(_selectedMetric);

    final selectedPoint = (_selectedPointIndex != null && _selectedPointIndex! < history.length)
        ? history[_selectedPointIndex!]
        : (history.isNotEmpty ? history.last : null);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B293C) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du graphique
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Évolution : $metricName',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                  if (selectedPoint != null)
                    Text(
                      'Mesure : ${selectedPoint['value']} $unit (${selectedPoint['timeFormatted'] ?? selectedPoint['timestamp']})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: metricColor,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              if (widget.onNavigateToTimeline != null)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: widget.onNavigateToTimeline,
                  child: Row(
                    children: [
                      const Text(
                        'Voir Timeline',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.bondiBlue,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(CupertinoIcons.chevron_right, size: 12, color: AppTheme.bondiBlue),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Zone Canvas du Graphique iOS
          SizedBox(
            height: 180,
            width: double.infinity,
            child: history.isEmpty
                ? Center(
                    child: Text(
                      'Aucune mesure enregistrée sur cette période',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.subtextColor(context),
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) {
                          _handleChartTouch(details.localPosition.dx, constraints.maxWidth, history.length);
                        },
                        onTapDown: (details) {
                          _handleChartTouch(details.localPosition.dx, constraints.maxWidth, history.length);
                        },
                        child: CustomPaint(
                          size: Size(constraints.maxWidth, 180),
                          painter: _IosLineChartPainter(
                            points: history,
                            color: metricColor,
                            isDark: isDark,
                            selectedIndex: _selectedPointIndex ?? (history.length - 1),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),

          // Instruction d'interaction
          Center(
            child: Text(
              'Touchez ou glissez sur la courbe pour inspecter chaque relevé horaire',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppTheme.subtextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleChartTouch(double dx, double width, int pointCount) {
    if (pointCount <= 1 || width <= 0) return;
    final step = width / (pointCount - 1);
    int index = (dx / step).round().clamp(0, pointCount - 1);
    if (_selectedPointIndex != index) {
      HapticFeedback.selectionClick();
      setState(() => _selectedPointIndex = index);
    }
  }

  String _getMetricTitle(String key) {
    switch (key) {
      case 'temperature':
        return 'Température Corporelle';
      case 'oxygenSaturation':
        return 'Saturation en Oxygène (SpO₂)';
      case 'heartRate':
        return 'Fréquence Cardiaque';
      case 'bloodPressureSys':
        return 'Tension Artérielle Systolique';
      default:
        return 'Constante';
    }
  }

  Color _getMetricColor(String key) {
    switch (key) {
      case 'temperature':
        return const Color(0xFFE11D48);
      case 'oxygenSaturation':
        return const Color(0xFF007EA7);
      case 'heartRate':
        return const Color(0xFF00A896);
      case 'bloodPressureSys':
        return const Color(0xFF8B5CF6);
      default:
        return AppTheme.bondiBlue;
    }
  }
}

// =============================================================================
// ── CUSTOM PAINTER GRAPHIQUE iOS ─────────────────────────────────────────────
// =============================================================================

class _IosLineChartPainter extends CustomPainter {
  final List<dynamic> points;
  final Color color;
  final bool isDark;
  final int selectedIndex;

  _IosLineChartPainter({
    required this.points,
    required this.color,
    required this.isDark,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final values = points.map((p) => (p['value'] as num).toDouble()).toList();
    double minY = values.reduce(math.min);
    double maxY = values.reduce(math.max);

    // Marge de respiration verticale
    if (minY == maxY) {
      minY -= 1.0;
      maxY += 1.0;
    } else {
      final pad = (maxY - minY) * 0.2;
      minY -= pad;
      maxY += pad;
    }

    final chartPaddingTop = 20.0;
    final chartPaddingBottom = 24.0;
    final chartHeight = size.height - chartPaddingTop - chartPaddingBottom;
    final width = size.width;

    // 1. Grille de fond discrète
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
      ..strokeWidth = 1;

    for (int i = 0; i <= 3; i++) {
      final y = chartPaddingTop + (chartHeight / 3) * i;
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    // 2. Calcul des coordonnées
    final offsets = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final x = points.length == 1 ? width / 2 : (width / (points.length - 1)) * i;
      final normalizedY = (values[i] - minY) / (maxY - minY);
      final y = chartPaddingTop + (1.0 - normalizedY) * chartHeight;
      offsets.add(Offset(x, y));
    }

    // 3. Remplissage avec dégradé fluide
    final fillPath = Path();
    fillPath.moveTo(offsets.first.dx, size.height - chartPaddingBottom);
    for (int i = 0; i < offsets.length; i++) {
      if (i == 0) {
        fillPath.lineTo(offsets[i].dx, offsets[i].dy);
      } else {
        // Courbe de Bézier cubique pour une fluidité style iOS Health
        final prev = offsets[i - 1];
        final curr = offsets[i];
        final cp1 = Offset(prev.dx + (curr.dx - prev.dx) / 2, prev.dy);
        final cp2 = Offset(prev.dx + (curr.dx - prev.dx) / 2, curr.dy);
        fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, curr.dx, curr.dy);
      }
    }
    fillPath.lineTo(offsets.last.dx, size.height - chartPaddingBottom);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.35),
          color.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, chartPaddingTop, width, chartHeight));
    canvas.drawPath(fillPath, fillPaint);

    // 4. Ligne de la courbe
    final strokePath = Path();
    for (int i = 0; i < offsets.length; i++) {
      if (i == 0) {
        strokePath.moveTo(offsets[i].dx, offsets[i].dy);
      } else {
        final prev = offsets[i - 1];
        final curr = offsets[i];
        final cp1 = Offset(prev.dx + (curr.dx - prev.dx) / 2, prev.dy);
        final cp2 = Offset(prev.dx + (curr.dx - prev.dx) / 2, curr.dy);
        strokePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, curr.dx, curr.dy);
      }
    }

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(strokePath, strokePaint);

    // 5. Points et Point sélectionné
    for (int i = 0; i < offsets.length; i++) {
      final isSel = i == selectedIndex;
      final pointOffset = offsets[i];

      if (isSel) {
        // Ligne verticale guide
        final guidePaint = Paint()
          ..color = color.withValues(alpha: 0.4)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(pointOffset.dx, chartPaddingTop),
          Offset(pointOffset.dx, size.height - chartPaddingBottom),
          guidePaint,
        );

        // Halo d'accentuation
        final haloPaint = Paint()
          ..color = color.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pointOffset, 9, haloPaint);

        // Nœud intérieur
        final selDotPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pointOffset, 5, selDotPaint);

        final whiteCenterPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pointOffset, 2.5, whiteCenterPaint);
      } else {
        final dotPaint = Paint()
          ..color = isDark ? const Color(0xFF1B293C) : Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pointOffset, 3.5, dotPaint);

        final borderPaint = Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(pointOffset, 3.5, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IosLineChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.isDark != isDark;
  }
}
