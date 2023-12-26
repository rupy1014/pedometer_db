// You have generated a new plugin project without specifying the `--platforms`
// flag. A plugin project with no platform support was generated. To add a
// platform, run `flutter create -t plugin --platforms <platforms> .` under the
// same directory. You can also find a detailed instruction on how to add
// platforms in the `pubspec.yaml` at
// https://flutter.dev/docs/development/packages-and-plugins/developing-packages#plugin-platforms.

import 'dart:io';

import 'package:pedometer_db/provider/step_provider.dart';

import 'package:flutter/services.dart';

import 'pedometer_db_method_channel.dart';

class PedometerDb {

  // static const EventChannel _iosChannel = const EventChannel('ios_step_count');

  MethodChannelPedometerDb? _channelPedometerDb;
  StepProvider? stepProvider;

  PedometerDb() {
    stepProvider = StepProvider();
    _channelPedometerDb = MethodChannelPedometerDb();
    stepProvider?.initDatabase();
    stepProvider?.initStepCountStream();
  }


  // initPlatformState() async {
  //   stepProvider = StepProvider();
  //   _channelPedometerDb = MethodChannelPedometerDb();
  //   await stepProvider?.initDatabase();
  //   await stepProvider?.initStepCountStream();
  // }

  Future<int> queryPedometerData(int startTime, int endTime) async {
    if(Platform.isIOS) {
      return await _channelPedometerDb?.queryPedometerDataFromOS(startTime, endTime) ?? 0;
    }
    return await stepProvider?.queryPedometerData(startTime, endTime) ?? 0;
  }
}
