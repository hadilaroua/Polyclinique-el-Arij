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
                      CustomPaint(
                        size: const Size(58, 58),
                        painter: MessengerBubblePainter(),
                      ),
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.danger,
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

class MessengerBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Messenger Blue Gradient Shader
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF00C6FF),
          Color(0xFF0078FF),
          Color(0xFF0055FF),
        ],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    // Outer speech bubble path (Circle with tail at bottom-left)
    final bubblePath = Path();
    final center = Offset(w * 0.5, h * 0.46);
    final radius = w * 0.44;

    bubblePath.addOval(Rect.fromCircle(center: center, radius: radius));

    // Tail at bottom left
    final tailPath = Path()
      ..moveTo(w * 0.22, h * 0.72)
      ..lineTo(w * 0.06, h * 0.94) // Pointer tip
      ..lineTo(w * 0.38, h * 0.86)
      ..close();

    final combinedPath = Path.combine(PathOperation.union, bubblePath, tailPath);

    // Subtle drop shadow
    canvas.drawShadow(combinedPath, Colors.black.withValues(alpha: 0.35), 8, true);

    // Draw main bubble body
    canvas.drawPath(combinedPath, paint);

    // Lightning bolt in white
    final boltPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final boltPath = Path();
    boltPath.moveTo(w * 0.66, h * 0.31);
    boltPath.lineTo(w * 0.41, h * 0.49);
    boltPath.lineTo(w * 0.52, h * 0.49);
    boltPath.lineTo(w * 0.32, h * 0.65);
    boltPath.lineTo(w * 0.57, h * 0.47);
    boltPath.lineTo(w * 0.46, h * 0.47);
    boltPath.close();

    canvas.drawPath(boltPath, boltPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
