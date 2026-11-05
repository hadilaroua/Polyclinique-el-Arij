import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../utils/theme.dart';

enum VoiceAgentState { idle, listening, thinking, speaking }

class AiVoiceAssistantScreen extends StatefulWidget {
  final String? initialPrompt;

  const AiVoiceAssistantScreen({super.key, this.initialPrompt});

  @override
  State<AiVoiceAssistantScreen> createState() => _AiVoiceAssistantScreenState();
}

class _AiVoiceAssistantScreenState extends State<AiVoiceAssistantScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _stateTimer;

  VoiceAgentState _currentState = VoiceAgentState.idle;
  String _userSpeech = '';
  String _aiResponse = '';
  String _userName = 'Dr. Karima';

  // Questions pré-configurées pour démonstration rapide
  final List<Map<String, String>> _quickActions = [
    {
      'label': 'État de garde',
      'user': '« Fais-moi le point sur ma garde du matin »',
      'reply': '« Tout est stable. 34 lits occupés, 4 alertes de constantes en cours et 2 bilans urgents au laboratoire. »',
    },
    {
      'label': 'Patients prioritaires',
      'user': '« Quels sont les patients à voir en priorité ? »',
      'reply': '« Priorité immédiate sur M. Trabelsi en Ch. 12 (dérive thermique à 39.1°C) et Mme Amor en Ch. 08 pour la SpO2. »',
    },
    {
      'label': 'Lits disponibles',
      'user': '« Y a-t-il des lits libres en réanimation ou continu ? »',
      'reply': '« Il reste 1 lit disponible en Soins Continus et 2 lits en Cardiologie A. »',
    },
  ];

  @override
  void initState() {
    super.initState();
    _resolveUserName();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Si un prompt initial est passé, déclencher automatiquement la simulation
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerSimulation(widget.initialPrompt!);
      });
    }
  }

  @override
  void dispose() {
    _stateTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _resolveUserName() {
    try {
      final user = ApiService().currentUser;
      if (user != null) {
        final role = (user['role'] ?? '').toString().toUpperCase();
        final fn = (user['firstName'] ?? '').toString().trim();
        final ln = (user['lastName'] ?? '').toString().trim();
        final fullName = '$fn $ln'.trim();

        if (role == 'DOCTOR' || role == 'MED') {
          _userName = fullName.isNotEmpty ? 'Dr. $fullName' : 'Docteur';
        } else if (role == 'MIDWIFE' || role == 'SFM') {
          _userName = fullName.isNotEmpty ? '$fullName (Sage-Femme)' : 'Sage-Femme';
        } else if (role == 'NURSE' || role == 'INF') {
          _userName = fullName.isNotEmpty ? '$fullName (Infirmier)' : 'Infirmier(e)';
        } else {
          _userName = fullName.isNotEmpty ? fullName : 'Soignant';
        }
      }
    } catch (_) {
      _userName = 'Dr. Karima';
    }
  }

  void _handleOrbTap() {
    HapticFeedback.mediumImpact();

    if (_currentState == VoiceAgentState.listening) {
      // L'utilisateur termine manuellement de parler
      _finishListening();
    } else if (_currentState == VoiceAgentState.speaking) {
      // Réinitialiser vers état d'attente
      setState(() {
        _currentState = VoiceAgentState.idle;
      });
    } else {
      // Démarrer l'écoute
      _startListening();
    }
  }

  void _startListening({String? simulatedUserSpeech}) {
    _stateTimer?.cancel();

    setState(() {
      _currentState = VoiceAgentState.listening;
      _userSpeech = simulatedUserSpeech ?? '« Posez votre question clinique... »';
      _aiResponse = '';
    });

    // Simule la fin automatique de parole après 2.5 secondes si l'utilisateur ne clique pas
    _stateTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted && _currentState == VoiceAgentState.listening) {
        _finishListening();
      }
    });
  }

  void _finishListening() {
    _stateTimer?.cancel();
    HapticFeedback.lightImpact();

    setState(() {
      _currentState = VoiceAgentState.thinking;
    });

    // Temps de réflexion de l'IA (800ms) puis réponse
    _stateTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();

      setState(() {
        _currentState = VoiceAgentState.speaking;
        _aiResponse = '« Bonjour $_userName, comment puis-je vous aider aujourd\'hui ? »';
      });
    });
  }

  void _triggerSimulation(String userText, {String? customReply}) {
    _stateTimer?.cancel();
    HapticFeedback.selectionClick();

    setState(() {
      _currentState = VoiceAgentState.listening;
      _userSpeech = userText;
      _aiResponse = '';
    });

    _stateTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _currentState = VoiceAgentState.thinking);

      _stateTimer = Timer(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        setState(() {
          _currentState = VoiceAgentState.speaking;
          _aiResponse = customReply ?? '« Bonjour $_userName, comment puis-je vous aider aujourd\'hui ? »';
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Fond sombre épuré ultra-luxueux pour faire ressortir l'orbe haptique
    const Color bgDeepDark = Color(0xFF041C15);
    const Color emeraldPrimary = Color(0xFF063D2E);
    const Color terracottaOrange = Color(0xFFD97746);
    const Color mintGreen = Color(0xFF10B981);

    return Scaffold(
      backgroundColor: bgDeepDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── TOP BAR ÉPURÉE ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                    tooltip: 'Retour',
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: emeraldPrimary.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: mintGreen.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentState == VoiceAgentState.listening
                                ? terracottaOrange
                                : mintGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getStatusTitle(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: Color(0xFFE1F6E7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.clear_circled_solid, color: Colors.white38, size: 22),
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 1),

            // ── ZONE CENTRALE : ORBE HAPTIQUE & ONDE ANIMÉE ─────────────────
            Center(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  final pulse = _animController.value;
                  final scale = _currentState == VoiceAgentState.listening
                      ? 1.0 + (pulse * 0.14)
                      : (_currentState == VoiceAgentState.speaking
                          ? 1.0 + (pulse * 0.08)
                          : 1.0 + (pulse * 0.03));

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Double Halo Ambiant Rayonnant
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 260 * scale,
                            height: 260 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _currentState == VoiceAgentState.listening
                                      ? terracottaOrange.withValues(alpha: 0.35)
                                      : mintGreen.withValues(alpha: 0.28),
                                  _currentState == VoiceAgentState.thinking
                                      ? const Color(0xFFFF9561).withValues(alpha: 0.2)
                                      : emeraldPrimary.withValues(alpha: 0.15),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),

                          // Halo Interne Pulsant
                          Container(
                            width: 190 * scale,
                            height: 190 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: (_currentState == VoiceAgentState.listening
                                        ? terracottaOrange
                                        : mintGreen)
                                    .withValues(alpha: 0.45 * (1.0 - pulse * 0.4)),
                                width: 2.5,
                              ),
                            ),
                          ),

                          // Orbe Central Tactile
                          GestureDetector(
                            key: const Key('voice_orb_button'),
                            onTap: _handleOrbTap,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: _currentState == VoiceAgentState.listening
                                      ? const [Color(0xFFD97746), Color(0xFF994619), Color(0xFF4A1E08)]
                                      : (_currentState == VoiceAgentState.thinking
                                          ? const [Color(0xFF23342A), Color(0xFF0E1F16)]
                                          : const [Color(0xFF0D5E47), Color(0xFF063D2E), Color(0xFF00261B)]),
                                ),
                                border: Border.all(
                                  color: _currentState == VoiceAgentState.listening
                                      ? const Color(0xFFFFB694)
                                      : const Color(0xFF6FFBBE),
                                  width: 2.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_currentState == VoiceAgentState.listening
                                            ? terracottaOrange
                                            : mintGreen)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 36,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _buildOrbContent(pulse),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 36),

            // ── BULLE ÉPURÉE DE RETOUR VOCAL (SANS SURCHARGE) ───────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildDialogueBox(),
              ),
            ),

            const Spacer(flex: 2),

            // ── SUGGESTIONS RAPIDES DISCRÈTES (PILLS) ────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Text(
                    _currentState == VoiceAgentState.idle
                        ? 'Touchez l\'orbe pour parler ou choisissez :'
                        : 'Suggestions rapides :',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white38,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _quickActions.map((action) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => _triggerSimulation(action['user']!, customReply: action['reply']),
                            borderRadius: BorderRadius.circular(100),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(CupertinoIcons.sparkles, size: 12, color: Color(0xFFBAEED8)),
                                  const SizedBox(width: 6),
                                  Text(
                                    action['label']!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFBAEED8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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

  Widget _buildOrbContent(double pulse) {
    if (_currentState == VoiceAgentState.listening) {
      // Ondes sonores qui réagissent à la voix
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildWaveBar(16 + (math.sin(pulse * math.pi) * 14)),
          const SizedBox(width: 4),
          _buildWaveBar(30 + (math.cos(pulse * math.pi) * 18)),
          const SizedBox(width: 4),
          _buildWaveBar(44 + (math.sin(pulse * math.pi * 1.5) * 16)),
          const SizedBox(width: 4),
          _buildWaveBar(26 + (math.cos(pulse * math.pi * 1.2) * 14)),
          const SizedBox(width: 4),
          _buildWaveBar(14 + (math.sin(pulse * math.pi) * 10)),
        ],
      );
    } else if (_currentState == VoiceAgentState.thinking) {
      return const CupertinoActivityIndicator(color: Colors.white, radius: 16);
    } else if (_currentState == VoiceAgentState.speaking) {
      return const Icon(CupertinoIcons.speaker_2_fill, color: Colors.white, size: 36);
    } else {
      return const Icon(Icons.mic_rounded, color: Colors.white, size: 44);
    }
  }

  Widget _buildWaveBar(double height) {
    return Container(
      width: 4.5,
      height: height.clamp(8.0, 52.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildDialogueBox() {
    if (_currentState == VoiceAgentState.listening) {
      return Column(
        key: const ValueKey('listening'),
        children: const [
          Text(
            'Écoute en cours...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFFB694),
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Parlez naturellement ou touchez l\'orbe pour valider',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
        ],
      );
    } else if (_currentState == VoiceAgentState.thinking) {
      return const Column(
        key: ValueKey('thinking'),
        children: [
          Text(
            'Analyse clinique Gemini...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFFBAEED8),
            ),
          ),
        ],
      );
    } else if (_currentState == VoiceAgentState.speaking) {
      return Container(
        key: const ValueKey('speaking'),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF063D2E).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.auto_awesome, color: Color(0xFF6FFBBE), size: 16),
                SizedBox(width: 6),
                Text(
                  'RÉPONSE VOCALE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF6FFBBE),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _aiResponse,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );
    } else {
      return Column(
        key: const ValueKey('idle'),
        children: [
          Text(
            'Bonjour $_userName',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Appuyez sur le micro pour poser une question médicale à l\'IA.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Colors.white60, height: 1.35),
          ),
        ],
      );
    }
  }

  String _getStatusTitle() {
    switch (_currentState) {
      case VoiceAgentState.listening:
        return 'MICROPHONE ACTIF';
      case VoiceAgentState.thinking:
        return 'TRAITEMENT GEMINI';
      case VoiceAgentState.speaking:
        return 'RÉPONSE EN COURS';
      case VoiceAgentState.idle:
        return 'ARIJ VOICE • EN LIGNE';
    }
  }
}
