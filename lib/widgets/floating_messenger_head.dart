import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../screens/call_overlay_screen.dart';
import '../screens/staff_messenger_screen.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
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
            backgroundColor: AppTheme.chocolatePlum,
            title: Row(
              children: [
                const Icon(CupertinoIcons.phone_fill_arrow_down_left, color: AppTheme.neonIce),
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
                  style: const TextStyle(color: AppTheme.pearlAqua, fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppTheme.burntRose),
                icon: const Icon(CupertinoIcons.phone_down_fill),
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
                  backgroundColor: AppTheme.mutedTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(CupertinoIcons.phone_fill),
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
                    CupertinoPageRoute(
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
      CupertinoPageRoute(
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
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF6E56EB),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6E56EB).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: CustomPaint(
                            size: const Size(28, 28),
                            painter: SpeechBubbleOutlinePainter(),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: const Center(
                            child: Text(
                              '1',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
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

class SpeechBubbleOutlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // Center of main circular bubble
    final cx = w * 0.52;
    final cy = h * 0.46;
    final r = w * 0.40;

    // Start arc at 2.6 radians (~150 deg), sweeping clockwise to 2.1 radians (~120 deg)
    path.addArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), 2.3, 5.0);

    // Smooth tail pointing to bottom left (as seen in Screenshot 2)
    path.lineTo(cx - r * 0.95, cy + r * 0.85); // tail tip
    path.quadraticBezierTo(cx - r * 0.4, cy + r * 0.75, cx - r * 0.2, cy + r * 0.96);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
