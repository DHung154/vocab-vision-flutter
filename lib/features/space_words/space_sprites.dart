import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'space_data.dart';

/// Crops AI artwork by layout only. No generated shapes or Canvas artwork.
/// Overrides can point any logical sprite at its own PNG without code changes.
class SpaceSprite extends StatelessWidget {
  const SpaceSprite(
    this.name, {
    super.key,
    required this.config,
    this.width = 64,
    this.height,
    this.opacity = 1,
  });
  final String name;
  final SpaceConfig config;
  final double width;
  final double? height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final index = config.spriteNames.indexOf(name);
    final override = config.overrides[name] as String?;
    if (index < 0) {
      final h = height ?? width;
      return SizedBox(
        width: width,
        height: h,
        child: Center(child: Text('Thiếu sprite: $name')),
      );
    }
    final rawRect = (config.json['spriteRects'][name] as List).cast<num>();
    var rx = rawRect[0].toDouble();
    var ry = rawRect[1].toDouble();
    var rw = rawRect[2].toDouble();
    var rh = rawRect[3].toDouble();

    // Prevent texture bleeding from tightly-packed neighboring sprites in the 1254x1254 atlas.
    // Pause button circle ends at x=975 (u=0.777), button left shadow starts at x=986 (u=0.786).
    if (name == 'pause') {
      // Inset right edge to x=980 (u=0.7815) in the transparent gap, completely eliminating
      // the button's shadow without clipping any of the pause circle.
      rw -= 0.0095;
    } else if (name == 'button') {
      // Inset left edge by ~1.5 atlas pixels away from pause.
      rx += 0.0015;
      rw -= 0.003;
    }

    final h = height ?? (width * rh / rw);
    final atlasWidth = width / rw;
    final atlasHeight = h / rh;

    final image = override != null
        ? Image.asset(override, width: width, height: h, fit: BoxFit.fill)
        : ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: atlasWidth,
              maxWidth: atlasWidth,
              minHeight: atlasHeight,
              maxHeight: atlasHeight,
              child: Transform.translate(
                offset: Offset(-rx * atlasWidth, -ry * atlasHeight),
                child: Image.asset(
                  '$spaceAssets${(config.json['spriteSheets'] as Map?)?[name] ?? 'sprite_atlas.png'}',
                  width: atlasWidth,
                  height: atlasHeight,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
          );
    return ExcludeSemantics(
      child: Opacity(
        opacity: opacity,
        child: SizedBox(width: width, height: h, child: image),
      ),
    );
  }
}

class SpaceButton extends StatefulWidget {
  const SpaceButton({
    super.key,
    required this.config,
    required this.label,
    this.onPressed,
    this.sprite = 'button',
    this.height = 58,
    this.selected = false,
    this.wrong = false,
    this.feedbackId = 0,
  });
  final SpaceConfig config;
  final String label, sprite;
  final VoidCallback? onPressed;
  final double height;
  final bool selected;
  final bool wrong;
  final int feedbackId;

  @override
  State<SpaceButton> createState() => _SpaceButtonState();
}

class _SpaceButtonState extends State<SpaceButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      selected: widget.selected,
      label: widget.label,
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(widget.wrong ? widget.feedbackId : -1),
          tween: Tween(begin: widget.wrong ? 1 : 0, end: 0),
          duration: const Duration(milliseconds: 350),
          builder: (context, value, child) => Transform.translate(
            offset: Offset(
              reduced ? 0 : math.sin(value * math.pi * 6) * value * 6,
              0,
            ),
            child: child,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.onPressed == null
                ? null
                : (_) => setState(() => _pressed = true),
            onTapUp: widget.onPressed == null
                ? null
                : (_) => setState(() => _pressed = false),
            onTapCancel: () {
              if (_pressed) setState(() => _pressed = false);
            },
            onTap: widget.onPressed,
            child: AnimatedScale(
              scale: _pressed && widget.onPressed != null && !reduced
                  ? 0.96
                  : 1.0,
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOutCubic,
              child: SizedBox(
                height: widget.height,
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    alignment: Alignment.center,
                    children: [
                      SpaceSprite(
                        widget.sprite,
                        config: widget.config,
                        width: constraints.maxWidth,
                        height: widget.height,
                        opacity: widget.onPressed == null ? .48 : 1,
                      ),
                      // Compensate for bottom 3D bevel/shadow (~4px) so text sits visually centered on the button face
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: Center(
                          child: Text(
                            widget.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF183047),
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              height: 1.25,
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
        ),
      ),
    );
  }
}

class SpacePanel extends StatelessWidget {
  const SpacePanel({
    super.key,
    required this.config,
    required this.child,
    this.padding,
    this.minHeight,
  });
  final SpaceConfig config;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? minHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) => SpaceSprite(
              'word_panel',
              config: config,
              width: box.maxWidth,
              height: box.maxHeight,
            ),
          ),
        ),
        Container(
          constraints: minHeight != null
              ? BoxConstraints(minHeight: minHeight!)
              : null,
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
              color: const Color(0xFF183047),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
            child: child,
          ),
        ),
      ],
    ),
  );
}
