import 'dart:async';
import 'dart:math';

import 'package:classipod/core/constants/app_palette.dart';
import 'package:classipod/core/constants/assets.dart';
import 'package:classipod/core/widgets/artwork_image.dart';
import 'package:classipod/core/widgets/hero_flight_content.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AlbumReflectiveArt extends ConsumerStatefulWidget {
  final String? thumbnailPath;
  final bool isOnDevice;
  final double reflectedImageHeight;
  final double? imageWidth;
  final String heroTag;
  final bool tiltedImage;
  final bool showReflection;

  const AlbumReflectiveArt({
    super.key,
    this.thumbnailPath,
    this.isOnDevice = true,
    this.reflectedImageHeight = 50,
    this.imageWidth,
    required this.heroTag,
    this.tiltedImage = false,
    this.showReflection = true,
  });

  @override
  ConsumerState<AlbumReflectiveArt> createState() => _AlbumReflectiveArtState();
}

class _AlbumReflectiveArtState extends ConsumerState<AlbumReflectiveArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    unawaited(_controller.forward());
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 3D tilt settings: tweak these to taste.
    const tiltAngle = -0.35; // rotation in radians (0 = frontal)
    const tiltPerspective = 0.002; // higher = stronger perspective
    const tiltScale = 0.94; // keeps the tilted cover inside its box

    late final Matrix4 transform;
    if (widget.tiltedImage) {
      transform = Matrix4.identity()
        ..setEntry(3, 2, tiltPerspective)
        ..rotateY(tiltAngle)
        ..multiply(Matrix4.diagonal3Values(tiltScale, tiltScale, 1));
    } else {
      transform = Matrix4.identity();
    }

    final isDarkTheme =
        CupertinoTheme.of(context).brightness == Brightness.dark;
    final overlayTopColor = isDarkTheme
        ? AppPalette.darkReflectionOverlayColor1
        : const Color(0x66FFFFFF);
    final overlayBottomColor = isDarkTheme
        ? AppPalette.darkReflectionOverlayColor2
        : const Color(0xFFFFFFFF);
    final overlayBorderColor = isDarkTheme
        ? CupertinoColors.black
        : CupertinoColors.white;

    return Hero(
      tag: widget.heroTag,
      flightShuttleBuilder:
          (
            flightContext,
            animation,
            flightDirection,
            fromHeroContext,
            toHeroContext,
          ) {
            late final Widget sourceWidget;
            late final Widget destinationWidget;
            switch (flightDirection) {
              case HeroFlightDirection.push:
                sourceWidget = HeroFlightContent.preview(fromHeroContext);
                destinationWidget = HeroFlightContent.preview(toHeroContext);
              case HeroFlightDirection.pop:
                sourceWidget = HeroFlightContent.preview(toHeroContext);
                destinationWidget = HeroFlightContent.preview(fromHeroContext);
            }
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                if (animation.value < 0.01 || animation.value > 0.999) {
                  unawaited(_controller.forward());
                } else if (animation.isAnimating) {
                  _controller.reset();
                }
                return Transform(
                  transform: Matrix4.identity()..rotateY(animation.value * pi),
                  alignment: Alignment.center,
                  child: (animation.value > 0.5)
                      ? Transform.flip(flipX: true, child: destinationWidget)
                      : child,
                );
              },
              child: sourceWidget,
            );
          },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = min(
            widget.imageWidth ?? constraints.maxWidth,
            constraints.maxWidth,
          );
          final height = min(
            widget.imageWidth ?? constraints.maxHeight,
            max(0.0, constraints.maxHeight - widget.reflectedImageHeight),
          );

          Widget artwork() => Image(
            image: artworkImage(ref, widget.thumbnailPath),
            width: width,
            height: height,
            alignment: Alignment.bottomCenter,
            fit: BoxFit.scaleDown,
            errorBuilder: (_, _, _) => Image.asset(
              Assets.defaultAlbumCoverImage,
              width: width,
              height: height,
              alignment: Alignment.bottomCenter,
              fit: BoxFit.scaleDown,
            ),
          );

          // Pivot the tilt on the center of the cover, so the top and bottom
          // edges converge symmetrically (true perspective).
          final tiltAlignment =
              constraints.maxHeight.isFinite && constraints.maxHeight > 0
              ? Alignment(0, height / constraints.maxHeight - 1)
              : Alignment.center;

          return Transform(
            transform: transform,
            alignment: tiltAlignment,
            child: Column(
              children: [
                artwork(),
                if (widget.showReflection)
                  FadeTransition(
                    opacity: _animation,
                    child: SizedBox(
                      width: width,
                      height: widget.reflectedImageHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.topCenter,
                              minHeight: height,
                              maxHeight: height,
                              child: Transform.flip(
                                flipY: true,
                                child: artwork(),
                              ),
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: overlayBorderColor,
                                  width: 0,
                                ),
                                right: BorderSide(
                                  color: overlayBorderColor,
                                  width: 0,
                                ),
                                bottom: BorderSide(
                                  color: overlayBorderColor,
                                  width: 0,
                                ),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [overlayTopColor, overlayBottomColor],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
