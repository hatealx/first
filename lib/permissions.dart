import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';


Future<bool> storagePermission() async {
  final DeviceInfoPlugin info = DeviceInfoPlugin(); // import 'package:device_info_plus/device_info_plus.dart';
  final deviceInfo = await DeviceInfoPlugin().androidInfo;


  final AndroidDeviceInfo androidInfo = await info.androidInfo;
  debugPrint('releaseVersion : ${androidInfo.version.release}');
  print('#############');

  bool havePermission = false;
 

  // Here you can use android api level 
  // like android api level 33 = android 13
  // This way you can also find out how to request storage permission 

  if (deviceInfo.version.sdkInt > 32) {
      print('Requesting storage permission FOR ANDROID SDK > 33');
    final status1 = await Permission.manageExternalStorage.request();
    havePermission = status1.isGranted;
    if (!havePermission) {
      throw Exception('Permission denied on android 13 or above');
    }
  } else {
    print('Requesting storage permission FOR ANDROID SDK <= 32');
    final status = await Permission.storage.request();
    havePermission = status.isGranted;
    if (!havePermission) {
      throw Exception('Permission denied');
    }
  }

  if (!havePermission) {
    // if no permission then open app-setting
    await openAppSettings();
  }

  return havePermission;
}