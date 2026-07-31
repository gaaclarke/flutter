// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';

void main() {
  runApp(const AngleTestApp());
}

/// Standalone test app designed to exercise ANGLE (OpenGL ES to Direct3D 11)
/// rendering features on Windows, including custom shaders, backdrop blurs,
/// clipping paths, matrices, and offscreen render targets.
class AngleTestApp extends StatelessWidget {
  const AngleTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1E1E2E),
        body: Center(
          child: Container(
            key: const Key('angle_test_canvas'),
            width: 600,
            height: 400,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x88000000), blurRadius: 20, offset: Offset(0, 10)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: <Widget>[
                  // Background with linear gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color(0xFF00B4DB),
                          Color(0xFF0083B0),
                          Color(0xFF6B73FF),
                          Color(0xFF000DFF),
                        ],
                      ),
                    ),
                  ),
                  // Custom painter to exercise ANGLE path clipping, matrices, & radial gradients
                  CustomPaint(size: const Size(600, 400), painter: AngleGraphicsPainter()),
                  // Backdrop filter blur to exercise offscreen FBO blitting in ANGLE
                  Positioned(
                    bottom: 20,
                    right: 20,
                    width: 240,
                    height: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          color: const Color(0x33FFFFFF),
                          alignment: Alignment.center,
                          child: const Text(
                            'ANGLE Blur Test',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              shadows: <Shadow>[
                                Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(1, 2)),
                              ],
                            ),
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
    );
  }
}

/// Custom painter that draws geometry, radial gradients, overlapping paths,
/// and transformed shapes to test ANGLE pipeline compilation and rendering.
class AngleGraphicsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Radial gradient circle
    final radialPaint = Paint()
      ..shader = ui.Gradient.radial(Offset(size.width * 0.3, size.height * 0.4), 120, const <Color>[
        Color(0xFFFF7E5F),
        Color(0xFFFEB47B),
        Color(0x00FEB47B),
      ]);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.4), 120, radialPaint);

    // 2. Overlapping clipped star/polygon path (Even-Odd fill)
    final path1 = Path()..addRect(Rect.fromLTWH(size.width * 0.5, 40, 140, 140));
    final path2 = Path()..addOval(Rect.fromLTWH(size.width * 0.55, 70, 140, 140));
    final Path combinedPath = Path.combine(PathOperation.difference, path1, path2);

    final fillPaint = Paint()
      ..color = const Color(0xFFE91E63)
      ..style = PaintingStyle.fill;
    canvas.drawPath(combinedPath, fillPaint);

    // 3. Transformed rotated rectangle with stroke
    canvas.save();
    canvas.translate(size.width * 0.25, size.height * 0.75);
    canvas.rotate(0.45); // ~25 degrees
    final strokePaint = Paint()
      ..color = const Color(0xFFFFEB3B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 100, height: 60),
        const Radius.circular(10),
      ),
      strokePaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
