
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _setupFolders() async {
    List<Directory>? externalDirs = await getExternalStorageDirectories();
    if (externalDirs != null && externalDirs.isNotEmpty) {
      var baseDataPath = externalDirs.first.parent.parent.parent.parent.path;
      List<String> appDataFolders = [
        'appdata_sbc',
        'appdata_uke',
        'appdata_xmas'
      ];
      for (String folder in appDataFolders) {
        Directory appDataDir = Directory('$baseDataPath/$folder');
        await appDataDir.create(recursive: true);
        await Directory('${appDataDir.path}/library').create(recursive: true);
        await Directory('${appDataDir.path}/this_week').create(recursive: true);
      }
    } else {
      throw Exception("No external storage directories found.");
    }
  }

  
  