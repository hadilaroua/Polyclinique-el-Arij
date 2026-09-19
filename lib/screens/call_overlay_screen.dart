import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/avatar_widget.dart';

class CallOverlayScreen extends StatefulWidget {
  final Map<String, dynamic> contact;
  final String callType; // 'AUDIO' ou 'VIDEO'
  final VoidCallback onEndCall;

  const CallOverlayScreen({
    super.key,
    required this.contact,
    required this.callType,
    required this.onEndCall,
  });

  @override
  State<CallOverlayScreen> createState() => _CallOverlayScreenState();
}

class _CallOverlayScreenState extends State<CallOverlayScreen> {
  bool isMuted = false;
  bool isSpeakerOn = true;
  bool isVideoEnabled = true;
  bool isConnected = false;

  int _callDurationSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    isVideoEnabled = widget.callType == 'VIDEO';

    // Simulation de décrochage après 2.5 secondes
    Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          isConnected = true;
        });
        _startTimer();
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _callDurationSeconds++;
        });
      }
    });
  }

  String _formatDuration(int totalSecs) {
    final mins = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSecs % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.contact['name'] ??
        '${widget.contact['firstName'] ?? ''} ${widget.contact['lastName'] ?? ''}'.trim();
    final role = widget.contact['role'] ?? 'Médecin';
    final avatarUrl = widget.contact['avatarUrl'];

    return Scaffold(
      backgroundColor: isVideoEnabled ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
      body: SafeArea(
        child: Stack(
          children: [
            // Arrière-plan pour appel vidéo
            if (isVideoEnabled && isConnected)
              Positioned.fill(
                child: Container(
                  color: Colors.black87,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam, size: 80, color: Colors.white.withValues(alpha: 0.3)),
                        const SizedBox(height: 10),
                        const Text(
                          'Flux Vidéo HD Crypté en Direct',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // En-tête avec détails du correspondant
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  AvatarWidget(
                    avatarUrl: avatarUrl,
                    name: name.isNotEmpty ? name : 'Soignant',
                    role: role,
                    radius: 50,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name.isNotEmpty ? name : 'Personnel Soignant',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role,
                    style: TextStyle(
                      color: Colors.cyanAccent.shade100,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isConnected ? Icons.fiber_manual_record : Icons.phone_forwarded,
                          size: 12,
                          color: isConnected ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isConnected
                              ? _formatDuration(_callDurationSeconds)
                              : 'Connexion en cours...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Vignette vidéo locale (pour appel vidéo)
            if (isVideoEnabled && isConnected)
              Positioned(
                top: 20,
                right: 20,
                width: 100,
                height: 140,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white30, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.person, color: Colors.white54, size: 40),
                  ),
                ),
              ),

            // Commandes d'appel en bas
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Micro Mute
                      _callActionButton(
                        icon: isMuted ? Icons.mic_off : Icons.mic,
                        label: isMuted ? 'Mute ON' : 'Micro',
                        color: isMuted ? Colors.amber : Colors.white24,
                        iconColor: isMuted ? Colors.black : Colors.white,
                        onTap: () => setState(() => isMuted = !isMuted),
                      ),

                      // Haut-parleur / Speaker
                      _callActionButton(
                        icon: isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                        label: 'Haut-parleur',
                        color: isSpeakerOn ? Colors.white : Colors.white24,
                        iconColor: isSpeakerOn ? Colors.black : Colors.white,
                        onTap: () => setState(() => isSpeakerOn = !isSpeakerOn),
                      ),

                      // Vidéo Toggle
                      if (widget.callType == 'VIDEO')
                        _callActionButton(
                          icon: isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                          label: 'Caméra',
                          color: isVideoEnabled ? Colors.white : Colors.white24,
                          iconColor: isVideoEnabled ? Colors.black : Colors.white,
                          onTap: () => setState(() => isVideoEnabled = !isVideoEnabled),
                        ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Bouton Raccrocher (Rouge)
                  FloatingActionButton.large(
                    heroTag: 'end_call_fab',
                    backgroundColor: Colors.red,
                    onPressed: widget.onEndCall,
                    child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _callActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
