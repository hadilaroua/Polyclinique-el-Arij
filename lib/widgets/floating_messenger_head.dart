import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/call_overlay_screen.dart';
import '../screens/staff_messenger_screen.dart';
import '../services/api_service.dart';
import 'avatar_widget.dart';

class FloatingMessengerHead extends StatefulWidget {
  final Widget child;
  final VoidCallback onLogout;
  final bool showFloatingHead;

  const FloatingMessengerHead({
    super.key,
    required this.child,
    required this.onLogout,
    this.showFloatingHead = true,
  });

  @override
  State<FloatingMessengerHead> createState() => _FloatingMessengerHeadState();
}

class _FloatingMessengerHeadState extends State<FloatingMessengerHead> {
  final api = ApiService();
  double xPos = 20.0;
  double yPos = 120.0;
  bool isDragging = false;
  bool isCallModalOpen = false;
  Timer? _callCheckTimer;

  @override
  void initState() {
    super.initState();
    _startCallChecking();
  }

  @override
  void dispose() {
    _callCheckTimer?.cancel();
    super.dispose();
  }

  void _startCallChecking() {
    _callCheckTimer?.cancel();
    _callCheckTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) => _checkPendingCall());
  }

  Future<void> _checkPendingCall() async {
    if (isCallModalOpen || !api.isAuthenticated) return;
    try {
      final res = await api.getPendingCall();
      if (!mounted) return;

      if (res['hasPendingCall'] == true && !isCallModalOpen) {
        isCallModalOpen = true;
        final call = res['call'];
        final sender = call['sender'] ?? {};
        final callType = call['callType'] ?? 'AUDIO';
        final senderName = '${sender['firstName'] ?? ''} ${sender['lastName'] ?? ''}'.trim();
        final targetUserId = sender['_id'] ?? sender['id'] ?? call['senderId'];

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: const Color(0xFF0F172A),
            title: Row(
              children: [
                const Icon(Icons.phone_in_talk, color: Colors.greenAccent),
                const SizedBox(width: 10),
                Text(
                  'Appel $callType Entrant...',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvatarWidget(
                  avatarUrl: sender['avatarUrl'],
                  name: senderName.isNotEmpty ? senderName : 'Soignant',
                  role: sender['role'] ?? 'Médecin',
                  radius: 36,
                ),
                const SizedBox(height: 14),
                Text(
                  senderName.isNotEmpty ? senderName : 'Personnel Soignant',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  sender['role'] ?? 'Personnel Clinique',
                  style: TextStyle(color: Colors.cyanAccent.shade100, fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                icon: const Icon(Icons.call_end),
                label: const Text('Refuser'),
                onPressed: () {
                  api.sendCallSignal(
                    targetUserId: targetUserId.toString(),
                    callType: callType,
                    action: 'REJECT',
                  );
                  isCallModalOpen = false;
                  Navigator.pop(ctx);
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.call),
                label: const Text('Décrocher', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  api.sendCallSignal(
                    targetUserId: targetUserId.toString(),
                    callType: callType,
                    action: 'ACCEPT',
                  );
                  isCallModalOpen = false;
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CallOverlayScreen(
                        contact: sender,
                        callType: callType,
                        isCaller: false,
                        onEndCall: () => Navigator.pop(context),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ).then((_) => isCallModalOpen = false);
      }
    } catch (_) {}
  }


  void _openMessenger() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StaffMessengerScreen(onLogout: widget.onLogout),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        widget.child,
        if (widget.showFloatingHead)
          Positioned(
            left: xPos,
            top: yPos,
            child: GestureDetector(
              onPanStart: (_) => setState(() => isDragging = true),
              onPanUpdate: (details) {
                setState(() {
                  xPos = (xPos + details.delta.dx).clamp(10.0, screenSize.width - 70.0);
                  yPos = (yPos + details.delta.dy).clamp(50.0, screenSize.height - 120.0);
                });
              },
              onPanEnd: (_) {
                setState(() => isDragging = false);
                if (xPos < screenSize.width / 2) {
                  setState(() => xPos = 16.0);
                } else {
                  setState(() => xPos = screenSize.width - 72.0);
                }
              },
              onTap: _openMessenger,
              child: AnimatedScale(
                scale: isDragging ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.chat_bubble_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: const Center(
                            child: Text(
                              '1',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
