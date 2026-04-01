import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum ToastType { success, error, info, warning }

class AppToast {
  /// Affiche un toast moderne en overlay, aligné sur le design system de l'app.
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.success,
    String? subtitle,
    Duration duration = const Duration(seconds: 5),
  }) {
    final overlay = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        subtitle: subtitle,
        type: type,
        duration: duration,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
    this.subtitle,
  });

  final String message;
  final String? subtitle;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    Future.delayed(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _ToastStyle get _style => _toastStyle(widget.type);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _slide,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _style.color.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: _style.color.withValues(alpha: 0.15),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    // Icône colorée — même style que _IconBoxButton du dashboard
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _style.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: FaIcon(
                          _style.icon,
                          color: _style.color,
                          size: 17,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.message,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Styles par type ───────────────────────────────────────────────────────────

class _ToastStyle {
  final Color color;
  final IconData icon;
  const _ToastStyle({required this.color, required this.icon});
}

_ToastStyle _toastStyle(ToastType type) {
  switch (type) {
    case ToastType.success:
      return const _ToastStyle(
        color: Color(0xFF28C76F),
        icon: FontAwesomeIcons.circleCheck,
      );
    case ToastType.error:
      return const _ToastStyle(
        color: Color(0xFFEA5455),
        icon: FontAwesomeIcons.circleXmark,
      );
    case ToastType.warning:
      return const _ToastStyle(
        color: Color(0xFFFF9F43),
        icon: FontAwesomeIcons.triangleExclamation,
      );
    case ToastType.info:
      return const _ToastStyle(
        color: Color(0xFF00CFE8),
        icon: FontAwesomeIcons.circleInfo,
      );
  }
}