import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';

enum PlayfulButtonVariant {
  primary,
  success,
  sky,
  gold,
  neutral,
  danger,
}

/// A tactile, playful 3D button inspired by modern gamified learning apps.
/// Features a chunky 4-5dp bevel edge and press-down displacement for satisfying feedback.
class PlayfulButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final String? text;
  final IconData? icon;
  final PlayfulButtonVariant variant;
  final double height;
  final double? width;
  final double bevelHeight;
  final double borderRadius;
  final bool isLoading;
  final String? semanticLabel;

  const PlayfulButton({
    super.key,
    required this.onPressed,
    this.child,
    this.text,
    this.icon,
    this.variant = PlayfulButtonVariant.primary,
    this.height = 54.0,
    this.width,
    this.bevelHeight = 4.0,
    this.borderRadius = 16.0,
    this.isLoading = false,
    this.semanticLabel,
  }) : assert(child != null || text != null, 'Either child or text must be provided');

  @override
  State<PlayfulButton> createState() => _PlayfulButtonState();
}

class _PlayfulButtonState extends State<PlayfulButton> {
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  void _onTapDown(TapDownDetails details) {
    if (!_isEnabled) return;
    setState(() => _isPressed = true);
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails details) {
    if (!_isEnabled) return;
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    if (!_isEnabled) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    Color faceColor;
    Color bevelColor;
    Color textColor;
    Border? border;

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    switch (widget.variant) {
      case PlayfulButtonVariant.primary:
        faceColor = AppColors.blue; // #2A7BE4
        bevelColor = AppColors.blueEdge; // #1B57AE
        textColor = Colors.white;
        break;
      case PlayfulButtonVariant.success:
        faceColor = AppColors.green; // #4CCB57
        bevelColor = AppColors.greenEdge; // #2F9A3B
        textColor = Colors.white;
        break;
      case PlayfulButtonVariant.sky:
        faceColor = AppColors.blue;
        bevelColor = AppColors.blueEdge;
        textColor = Colors.white;
        break;
      case PlayfulButtonVariant.gold:
        faceColor = AppColors.gold; // #FFC83D
        bevelColor = AppColors.goldEdge; // #D9950F
        textColor = AppColors.goldInk; // #3A2600
        break;
      case PlayfulButtonVariant.danger:
        faceColor = AppColors.coral; // #FF5A5F
        bevelColor = AppColors.coralEdge; // #C93A40
        textColor = Colors.white;
        break;
      case PlayfulButtonVariant.neutral:
        faceColor = AppColors.surface; // #1B2A35
        bevelColor = AppColors.cardEdge; // #0E171E
        textColor = AppColors.text; // #FFFFFF
        border = Border.all(color: AppColors.cardBorder, width: 2); // #2C3E4C
        break;
    }

    if (!_isEnabled) {
      faceColor = AppColors.surface;
      bevelColor = AppColors.cardEdge;
      textColor = AppColors.locked; // #4A5D6B
      border = Border.all(color: AppColors.cardBorder, width: 2);
    }

    // On press: edge collapses and button moves down 3dp
    final double effectiveDisplacement = _isPressed ? (widget.bevelHeight - 1.0).clamp(0.0, 3.0) : 0.0;
    final double currentBevel = _isPressed ? 1.0 : widget.bevelHeight;

    final content = widget.isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: textColor, size: 22),
                const SizedBox(width: 8),
              ],
              if (widget.child != null)
                widget.child!
              else if (widget.text != null)
                Flexible(
                  child: Text(
                    widget.text!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700, // buttons weight 700
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
            ],
          );

    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: widget.semanticLabel ?? widget.text,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: _isEnabled ? widget.onPressed : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Bottom Bevel (depth base)
              Positioned(
                top: widget.bevelHeight,
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: bevelColor,
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                  ),
                ),
              ),

              // Button Face (moves down upon press)
              AnimatedPositioned(
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 100),
                curve: Curves.easeOutCubic,
                top: effectiveDisplacement,
                bottom: currentBevel,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: faceColor,
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    border: border,
                  ),
                  alignment: Alignment.center,
                  child: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
