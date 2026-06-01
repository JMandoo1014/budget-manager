import 'package:flutter/material.dart';

class AppToast {
  static OverlayEntry? _current;

  static void show(BuildContext context, String message, {bool isError = false}) {
    _current?.remove();
    _current = null;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        isError: isError,
        onDismissed: () {
          entry.remove();
          if (_current == entry) _current = null;
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({required this.message, required this.isError, required this.onDismissed});

  final String message;
  final bool isError;
  final VoidCallback onDismissed;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut, reverseCurve: Curves.easeIn),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _animate();
  }

  Future<void> _animate() async {
    await _controller.forward();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      await _controller.reverse();
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isError ? const Color(0xFFE24B4A) : const Color(0xFF1D9E75);
    return Positioned(
      left: 24,
      right: 24,
      top: 60,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _opacity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
