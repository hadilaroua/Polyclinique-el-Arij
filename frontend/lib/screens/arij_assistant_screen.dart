import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class ArijAssistantScreen extends StatefulWidget {
  final String? initialPatientId;
  final String? initialPatientName;

  const ArijAssistantScreen({
    super.key,
    this.initialPatientId,
    this.initialPatientName,
  });

  @override
  State<ArijAssistantScreen> createState() => _ArijAssistantScreenState();
}

class _ArijAssistantScreenState extends State<ArijAssistantScreen> {
  final ApiService api = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _isBriefingLoading = false;
  Map<String, dynamic>? _dailyBriefingData;
  String? _sessionId;
  String? _activePatientId;
  String? _activePatientName;

  @override
  void initState() {
    super.initState();
    _activePatientId = widget.initialPatientId;
    _activePatientName = widget.initialPatientName;

    // Message d'accueil personnalisé avec civilité (M. / Mme)
    final salutation = _getUserSalutation();
    _addSystemMessage(
      "Bonjour $salutation ! Comment puis-je vous aider aujourd'hui ?\n\n"
      "Je suis **Arij Assistant**, votre assistant clinique IA intelligent. Vous pouvez me poser votre question directement ou sélectionner une des requêtes rapides ci-dessous.",
    );

    _loadDailyBriefing();

    if (_activePatientId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _requestPatientSummary();
      });
    }
  }

  String _getUserSalutation() {
    final user = api.currentUser;
    final profile = api.currentProfile;

    final gender = (user?['gender'] ?? profile?['gender'] ?? user?['sexe'] ?? profile?['sexe'] ?? '').toString().toUpperCase();
    final role = (user?['role'] ?? '').toString().toUpperCase();

    String honorific = 'M.';
    if (gender == 'F' || gender == 'FEMALE' || gender == 'WOMAN' || gender == 'FEMININ' || role == 'MIDWIFE') {
      honorific = 'Mme';
    }

    final lastName = (user?['lastName'] ?? profile?['lastName'] ?? '').toString().trim();
    final firstName = (user?['firstName'] ?? profile?['firstName'] ?? '').toString().trim();

    final name = lastName.isNotEmpty ? lastName : firstName;
    return name.isNotEmpty ? "$honorific $name" : honorific;
  }

  void _addSystemMessage(String text) {
    setState(() {
      _messages.add({
        'sender': 'assistant',
        'text': text,
        'time': _formattedTime(),
      });
    });
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add({
        'sender': 'user',
        'text': text,
        'time': _formattedTime(),
      });
    });
    _scrollToBottom();
  }

  String _formattedTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadDailyBriefing() async {
    setState(() => _isBriefingLoading = true);
    final briefing = await api.getDailyBriefing();
    if (mounted) {
      setState(() {
        _dailyBriefingData = briefing;
        _isBriefingLoading = false;
      });
    }
  }

  Future<void> _sendMessage([String? customText]) async {
    final text = customText ?? _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (customText == null) {
      _messageController.clear();
    }

    _addUserMessage(text);

    setState(() => _isLoading = true);

    final response = await api.chatWithAi(
      text,
      patientId: _activePatientId,
      sessionId: _sessionId,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      final aiReply = response['reply'] ?? response['response'];
      if (aiReply != null) {
        _sessionId = response['sessionId'] ?? _sessionId;
        setState(() {
          _messages.add({
            'sender': 'assistant',
            'text': aiReply.toString(),
            'time': _formattedTime(),
          });
        });
        _scrollToBottom();
      } else {
        final errorMsg = response['message'] ?? "Désolé, une erreur s'est produite lors du traitement de votre demande.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _requestPatientSummary() async {
    if (_activePatientId == null) return;

    _addUserMessage("Générer le résumé intelligent de ce patient.");

    setState(() => _isLoading = true);

    final res = await api.getPatientSummary(_activePatientId!);

    if (mounted) {
      setState(() => _isLoading = false);
      if (res['summary'] != null) {
        setState(() {
          _messages.add({
            'sender': 'assistant',
            'text': res['summary'],
            'time': _formattedTime(),
          });
        });
        _scrollToBottom();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Erreur lors du résumé'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final user = api.currentUser;
    final role = user?['role'] ?? 'STAFF';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.border, height: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Arij Assistant',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Assistant Clinique IA • ${AppTheme.getRoleLabel(role)}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser le briefing',
            icon: const Icon(Icons.refresh, color: AppTheme.textMuted),
            onPressed: _loadDailyBriefing,
          ),
        ],
      ),
      body: Column(
        children: [
          // Contexte patient actif si disponible
          if (_activePatientName != null) _buildPatientContextBar(),

          // Carte Daily Briefing (Synthèse IA)
          _buildBriefingCard(),

          // Chips de suggestions de prompts rapides (Personnalisés par Rôle)
          _buildPromptSuggestions(role),

          // Flux de conversation Chat
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                return _buildMessageBubble(msg, isUser);
              },
            ),
          ),

          // Indicateur de chargement IA
          if (_isLoading) _buildLoadingIndicator(),

          // Zone d'écriture et envoi
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildPatientContextBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.primaryLight,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.person_pin_outlined, color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Patient actif: ${_activePatientName!}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryDark),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _requestPatientSummary,
            icon: const Icon(Icons.auto_awesome, size: 14),
            label: const Text('Résumer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
            onPressed: () {
              setState(() {
                _activePatientId = null;
                _activePatientName = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBriefingCard() {
    if (_isBriefingLoading) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
            SizedBox(width: 10),
            Text("Chargement de la synthèse clinique...", style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    if (_dailyBriefingData == null) return const SizedBox.shrink();

    final activeStays = _dailyBriefingData!['hospitalized'] ?? _dailyBriefingData!['activeStays'] ?? 0;
    final pendingExams = _dailyBriefingData!['pendingExams'] ?? _dailyBriefingData!['availableResults'] ?? 0;
    final urgentAlerts = _dailyBriefingData!['activeAlerts'] ?? _dailyBriefingData!['urgentAlerts'] ?? 0;
    final priorities = (_dailyBriefingData!['priorities'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: AppTheme.primary, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Synthèse & Métriques Cliniques',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textMain),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Temps réel', style: TextStyle(fontSize: 10, color: AppTheme.primaryDark, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBriefingStatItem('Hospitalisés', '$activeStays', Icons.single_bed_outlined, AppTheme.accent),
              _buildBriefingStatItem('Bilans en attente', '$pendingExams', Icons.science_outlined, AppTheme.warning),
              _buildBriefingStatItem('Alertes urgentes', '$urgentAlerts', Icons.warning_amber_rounded, AppTheme.danger),
            ],
          ),
          if (priorities.isNotEmpty) ...[
            const Divider(height: 16, color: AppTheme.border),
            const Text(
              '🎯 Priorités clinique suggérées :',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMain),
            ),
            const SizedBox(height: 4),
            ...priorities.take(3).map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_right_rounded, size: 18, color: AppTheme.primary),
                      Expanded(
                        child: Text(
                          '$p',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMain),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildBriefingStatItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
      ],
    );
  }

  Widget _buildPromptSuggestions(String role) {
    List<Map<String, dynamic>> prompts = [];

    switch (role.toUpperCase()) {
      case 'DOCTOR':
        prompts = [
          {'icon': Icons.bolt, 'text': '⚡ Priorités de la garde'},
          {'icon': Icons.warning_amber_rounded, 'text': '🚨 Alertes médicales'},
          {'icon': Icons.single_bed_outlined, 'text': '🏥 Patients hospitalisés'},
          {'icon': Icons.science_outlined, 'text': '🔬 Bilans en attente'},
        ];
        break;

      case 'NURSE':
        prompts = [
          {'icon': Icons.favorite_outline, 'text': '💉 Constantes à relever'},
          {'icon': Icons.single_bed_outlined, 'text': '🏥 Patients du service'},
          {'icon': Icons.warning_amber_rounded, 'text': '🚨 Alertes vitales'},
          {'icon': Icons.assignment_outlined, 'text': '📋 Transmissions du jour'},
        ];
        break;

      case 'MIDWIFE':
        prompts = [
          {'icon': Icons.child_care_outlined, 'text': '👶 Suivis de grossesse'},
          {'icon': Icons.single_bed_outlined, 'text': '🏥 Patients hospitalisés'},
          {'icon': Icons.warning_amber_rounded, 'text': '🚨 Alertes obstétricales'},
          {'icon': Icons.science_outlined, 'text': '🔬 Examens en attente'},
        ];
        break;

      case 'TECHNICIAN':
        prompts = [
          {'icon': Icons.biotech_outlined, 'text': '🔬 Examens à traiter'},
          {'icon': Icons.task_alt_outlined, 'text': '✅ Examens récents complétés'},
          {'icon': Icons.bar_chart_outlined, 'text': '📊 Rapport d\'activité plateau'},
          {'icon': Icons.warning_amber_rounded, 'text': '⚠️ Urgences bilans'},
        ];
        break;

      default:
        prompts = [
          {'icon': Icons.analytics_outlined, 'text': '📊 Synthèse clinique'},
          {'icon': Icons.single_bed_outlined, 'text': '🏥 Admissions actives'},
          {'icon': Icons.science_outlined, 'text': '🔬 Activité examens'},
          {'icon': Icons.warning_amber_rounded, 'text': '🚨 Alertes non résolues'},
        ];
        break;
    }

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: prompts.length,
        itemBuilder: (context, index) {
          final p = prompts[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: Icon(p['icon'] as IconData, size: 14, color: AppTheme.primary),
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppTheme.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              label: Text(
                p['text'] as String,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMain, fontWeight: FontWeight.w500),
              ),
              onPressed: () => _sendMessage(p['text'] as String),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, String> msg, bool isUser) {
    final text = msg['text'] ?? '';
    final time = msg['time'] ?? '';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.84),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 2),
            bottomRight: Radius.circular(isUser ? 2 : 16),
          ),
          border: isUser ? null : Border.all(color: AppTheme.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUser ? Icons.person_outline : Icons.smart_toy_outlined,
                    size: 14,
                    color: isUser ? Colors.white70 : AppTheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isUser ? 'Vous' : 'Arij Assistant',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isUser ? Colors.white70 : AppTheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser ? Colors.white60 : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _renderFormattedText(text, isUser),
              if (!isUser) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Réponse copiée !'), duration: Duration(seconds: 1)),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.copy_rounded, size: 12, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        const Text('Copier', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _renderFormattedText(String text, bool isUser) {
    final textColor = isUser ? Colors.white : AppTheme.textMain;

    final lines = text.split('\n');
    List<Widget> widgets = [];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 4));
        continue;
      }

      if (trimmed.startsWith('### ')) {
        widgets.add(Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isUser ? Colors.white.withValues(alpha: 0.15) : AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: isUser ? Colors.white : AppTheme.primary, width: 3)),
          ),
          child: Text(
            trimmed.replaceFirst('### ', ''),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: isUser ? Colors.white : AppTheme.primaryDark,
            ),
          ),
        ));
      } else if (trimmed.startsWith('## ') || trimmed.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(
            trimmed.replaceFirst(RegExp(r'#+\s*'), ''),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isUser ? Colors.white : AppTheme.primaryDark,
            ),
          ),
        ));
      } else if (trimmed.startsWith('* ') || trimmed.startsWith('- ') || trimmed.startsWith('• ')) {
        final bulletText = trimmed.replaceFirst(RegExp(r'^[\*\-\•]\s*'), '');
        final isAlert = bulletText.contains('🚨') || bulletText.contains('⚠️');

        widgets.add(Container(
          margin: const EdgeInsets.only(left: 2, top: 3, bottom: 3),
          padding: isAlert && !isUser ? const EdgeInsets.all(8) : EdgeInsets.zero,
          decoration: isAlert && !isUser
              ? BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                )
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isAlert)
                Text("• ", style: TextStyle(color: isUser ? Colors.white : AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
              Expanded(child: _buildRichInlineText(bulletText, textColor)),
            ],
          ),
        ));
      } else if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        final match = RegExp(r'^(\d+\.)\s*(.*)').firstMatch(trimmed);
        final numPrefix = match?.group(1) ?? '•';
        final content = match?.group(2) ?? trimmed;

        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 3, bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("$numPrefix ", style: TextStyle(color: isUser ? Colors.white : AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
              Expanded(child: _buildRichInlineText(content, textColor)),
            ],
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _buildRichInlineText(trimmed, textColor),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildRichInlineText(String text, Color baseColor) {
    final parts = text.split('**');
    List<TextSpan> spans = [];

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        spans.add(TextSpan(
          text: parts[i],
          style: TextStyle(fontWeight: FontWeight.bold, color: baseColor),
        ));
      } else {
        spans.add(TextSpan(
          text: parts[i],
          style: TextStyle(color: baseColor, fontSize: 13, height: 1.35),
        ));
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
          ),
          SizedBox(width: 10),
          Text(
            'Arij Assistant analyse les données cliniques...',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Posez votre question à Arij Assistant...',
                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              onPressed: () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }
}
