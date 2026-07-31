// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:windows_angle_test/main.dart';

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders Dart UI snapshot via ANGLE on Windows and uploads to Skia Gold', (
    WidgetTester tester,
  ) async {
    // Build the test app rendering ANGLE-stressing graphics.
    await tester.pumpWidget(const AngleTestApp());
    await tester.pumpAndSettle();

    // Ensure the first frame is fully rasterized by the GPU driver.
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();

    // 1. Take a screenshot of the specific test canvas widget.
    await expectLater(
      find.byKey(const Key('angle_test_canvas')),
      matchesGoldenFile('windows_angle_canvas_snapshot.png'),
    );

    // 2. Take a full screen screenshot and verify against golden / upload to Skia Gold.
    final List<int> fullScreenScreenshot = await binding.takeScreenshot(
      'windows_angle_full_screen',
    );
    await expectLater(fullScreenScreenshot, matchesGoldenFile('windows_angle_full_screen.png'));
  });
}
