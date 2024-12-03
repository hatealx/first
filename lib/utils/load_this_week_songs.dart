
import 'dart:convert';
import 'dart:io';


Future<List<Map<String, dynamic>>> loadThisWeekSongs(String appdatapath) async {
    try {
  
      Directory thisWeekDir = Directory('$appdatapath/this_week');
          print('This week directory: ${thisWeekDir.path}');
      if (!await thisWeekDir.exists()) {
        print("This week directory does not exist");
      }

      Map<String, List<String>> songImages = {};

      // First pass: Identify valid songs and their initial images
      List<FileSystemEntity> files = await thisWeekDir.list().toList();
      for (FileSystemEntity entity in files) {
        if (entity is File && entity.path.endsWith('.jpg')) {
          String fileName = entity.path.split('/').last;
          String songName = fileName.split('.').first;
          File validFile = File('$appdatapath/library/$songName.txt');
          if (await validFile.exists()) {
            songImages.putIfAbsent(songName, () => []).add(entity.path);
          }
        }
      }

      // Second pass: Gather all images for each identified song
      for (String songName in songImages.keys) {
        for (FileSystemEntity entity in files) {
          if (entity is File &&
              entity.path.endsWith('.jpg') &&
              entity.path.split('/').last.contains(songName)) {
            if (!songImages[songName]!.contains(entity.path)) {
              songImages[songName]!.add(entity.path);
            }
          }
        }

        // Sort the images list for the song
        songImages[songName]!.sort((a, b) {
          return _extractNumberFromFilename(a).compareTo(_extractNumberFromFilename(b));
        });
      }

      // Create song objects
      List<Map<String, dynamic>> songs = songImages.entries.map((entry) {
        return {
          'name': entry.key,
          'images': entry.value,
          'checked': true,
        };
      }).toList();

      // Sort songs alphabetically
      songs.sort((a, b) => a['name'].compareTo(b['name']));

      // Load saved order if exists
      File orderFile = File('${thisWeekDir.path}/order.json');
      if (await orderFile.exists()) {
        String orderContent = await orderFile.readAsString();
        List<dynamic> savedOrder = jsonDecode(orderContent);

        songs.sort((a, b) {
          int indexA = savedOrder.indexWhere((song) => song['name'] == a['name']);
          int indexB = savedOrder.indexWhere((song) => song['name'] == b['name']);
          return indexA.compareTo(indexB);
        });
      }

      // Assign numbers to songs
      for (int i = 0; i < songs.length; i++) {
        songs[i]['number'] = i + 1;
      }
       return songs;

    } catch (e) {
      print("Error loading songs: $e");
      rethrow;
    }
   
  }

  int _extractNumberFromFilename(String filename) {
    RegExp regExp = RegExp(r'(\d*)\.jpg$');
    Match? match = regExp.firstMatch(filename.split('/').last);
    if (match != null && match.group(1) != '') {
      return int.parse(match.group(1)!);
    } else {
      return 0;
    }
  }