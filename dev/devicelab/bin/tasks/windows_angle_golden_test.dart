// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_devicelab/framework/devices.dart';
import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/framework/task_result.dart';
import 'package:flutter_devicelab/framework/utils.dart';
import 'package:flutter_devicelab/tasks/integration_tests.dart';

/// Devicelab task that runs the Windows ANGLE integration test, renders snapshots,
/// and uploads/compares them with Skia Gold.
Future<TaskResult> run() async {
  deviceOperatingSystem = DeviceOperatingSystem.windows;

  final TaskFunction testTask = IntegrationTest(
    '${flutterDirectory.path}/dev/integration_tests/windows_angle_test',
    'integration_test/angle_snapshot_test.dart',
  ).call;

  return testTask();
}

Future<void> main() async {
  await task(run);
}
