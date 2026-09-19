import 'package:flutter/material.dart';
import '../screens/staff_messenger_screen.dart';

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
  double xPos = 20.0;
  double yPos = 120.0;
  bool isDragging = false;

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
