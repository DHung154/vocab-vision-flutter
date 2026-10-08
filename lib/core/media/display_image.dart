import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decode only the pixels needed by the current display. Quantized dimensions
/// let near-identical layouts share a cache entry; the source file is untouched.
ImageProvider<Object> imageForDisplay(
  ImageProvider<Object> image,
  Size logicalSize,
  double pixelRatio, {
  BoxFit fit = BoxFit.contain,
}) {
  int dimension(double value) =>
      ((value * pixelRatio / 64).ceil() * 64).clamp(64, 2048);
  final width = dimension(logicalSize.width);
  final height = dimension(logicalSize.height);
  final cover = fit == BoxFit.cover;
  return ResizeImage(
    image,
    width: cover ? math.max(width, height) : width,
    height: cover ? math.max(width, height) : height,
    policy: ResizeImagePolicy.fit,
    allowUpscaling: false,
  );
}

class DisplayImage extends StatelessWidget {
  const DisplayImage({
    super.key,
    required this.image,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.errorBuilder,
    this.semanticLabel,
  });

  final ImageProvider<Object> image;
  final double? width;
  final double? height;
  final BoxFit fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final screen = MediaQuery.sizeOf(context);
        final size = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : screen.width,
          constraints.hasBoundedHeight ? constraints.maxHeight : screen.height,
        );
        return Image(
          image: imageForDisplay(
            image,
            size,
            MediaQuery.devicePixelRatioOf(context),
            fit: fit,
          ),
          fit: fit,
          errorBuilder: errorBuilder,
          semanticLabel: semanticLabel,
        );
      },
    ),
  );
}
