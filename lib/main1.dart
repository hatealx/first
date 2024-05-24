import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

void main() {
  runApp(
    const MaterialApp(
      home: Home(),
    ),
  );
}

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Map<String, dynamic>> songsList = [];
  String appDataPath = '';
  Map<String, dynamic> library = {};

  @override
  void initState() {
    super.initState();
    _requestPermissionAndSetup();
  }

  /// Loads songs from a JSON file located in appdata folder
  Future<void> _loadSongsFromJson() async {
    try {
      String jsonFilePath = '$appDataPath/fileDict.json';
      File jsonFile = File(jsonFilePath);
      if (await jsonFile.exists()) {
        String jsonString = await jsonFile.readAsString();
        setState(() {
          library = json.decode(jsonString);
        });
      } else {
        _showNoDictionaryPopup();
      }
    } catch (e) {
      print("Error loading JSON file: $e");
    }
  }

  /// Requests storage permission and sets up directories if permission is granted
  Future<void> _requestPermissionAndSetup() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    if (status.isGranted) {
      List<Directory>? externalDirs = await getExternalStorageDirectories();
      if (externalDirs != null && externalDirs.isNotEmpty) {
        // Use the first directory in the list, which is the root of the external storage
        Directory externalDir = externalDirs.first;
        appDataPath = '${externalDir.parent?.parent?.parent?.parent?.path}/appdata';

        try {
          Directory appDataDir = Directory(appDataPath);
          if (!await appDataDir.exists()) {
            await appDataDir.create(recursive: true);
          }

          Directory libraryDir = Directory('${appDataDir.path}/library');
          Directory thisWeekDir = Directory('${appDataDir.path}/this_week');

          if (!await libraryDir.exists()) {
            await libraryDir.create();
          }

          if (!await thisWeekDir.exists()) {
            await thisWeekDir.create();
          }

          songsList = await _getSongsList(libraryDir.path, thisWeekDir.path);
          setState(() {});
        } catch (e) {
          print("Error creating folders: $e");
        }
      } else {
        print("No external storage directories found.");
      }
    } else {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Storage Permission Needed'),
            content: const Text('This app needs storage permission to function properly.'),
            actions: <Widget>[
              TextButton(
                child: const Text('Ask Again'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _requestPermissionAndSetup();
                },
              ),
            ],
          );
        },
      );
    }
  }

  /// Gets a list of songs from the library and this_week directories
  Future<List<Map<String, dynamic>>> _getSongsList(String libraryPath, String thisWeekPath) async {
    List<Map<String, dynamic>> songs = [];
    int songNumber = 1;

    Directory libraryDir = Directory(libraryPath);
    Directory thisWeekDir = Directory(thisWeekPath);

    if (await libraryDir.exists() && (await libraryDir.list().length > 0)) {
      List<FileSystemEntity> files = await libraryDir.list().toList();

      for (FileSystemEntity file in files) {
        if (file is File && file.path.endsWith('.txt')) {
          String songName = file.path.split('/').last.split('.').first;
          bool isChecked = await File('${thisWeekDir.path}/$songName.jpg').exists();
          songs.add({'name': songName, 'number': songNumber, 'checked': isChecked});
          songNumber++;
        }
      }
    }

    return songs;
  }

  /// Handles the state change of checkboxes and performs file operations accordingly
  void _handleCheckboxChange(String songName, bool isChecked) async {
    Directory libraryDir = Directory('${appDataPath}/library');
    Directory thisWeekDir = Directory('${appDataPath}/this_week');

    String imageFilePath = '${libraryDir.path}/$songName.jpg';
    String destinationPath = '${thisWeekDir.path}/$songName.jpg';

    if (isChecked) {
      if (await File(imageFilePath).exists()) {
        await File(imageFilePath).copy(destinationPath);
        _showFlashMessage('$songName is copied to this week folder');
      }
    } else {
      if (await File(destinationPath).exists()) {
        await File(destinationPath).delete();
        _showFlashMessage('$songName is deleted from this week folder');
      }
    }
  }

  /// Filters the list of songs based on the search query
  void _filterSongs(String query) async {
    List<Map<String, dynamic>> filteredSongs = [];
    Set<String> songNamesSet = {};
    List<String> queryWords = query.toLowerCase().split(' ').where((word) => word.isNotEmpty).toList();

    if (queryWords.isEmpty) {
      // Show all songs if the search query is empty
      for (var song in library.entries) {
        songNamesSet.addAll(List<String>.from(song.value));
      }
    } else {
      // Filter songs based on the search query
      Set<String>? commonSongs;
      for (var word in queryWords) {
        if (library.containsKey(word)) {
          Set<String> wordSongs = Set.from(List<String>.from(library[word]!));
          if (commonSongs == null) {
            commonSongs = wordSongs;
          } else {
            commonSongs = commonSongs.intersection(wordSongs);
          }
        }
      }

      if (commonSongs != null) {
        songNamesSet = commonSongs;
      }
    }

    Directory thisWeekDir = Directory('${appDataPath}/this_week');
    int songNumber = 1;
    for (var songName in songNamesSet) {
      bool isChecked = await File('${thisWeekDir.path}/$songName.jpg').exists();
      filteredSongs.add({'name': songName, 'number': songNumber, 'checked': isChecked});
      songNumber++;
    }

    setState(() {
      songsList = filteredSongs;
    });
  }

  /// Displays a flash message using Snackbar
  void _showFlashMessage(String message) {
    final snackBar = SnackBar(
      content: Text(message),
      duration: const Duration(milliseconds: 1500), // Flash message duration
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Shows a popup indicating that the dictionary JSON file is missing
  void _showNoDictionaryPopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Dictionary Not Found'),
          content: const Text('No dictionary for search found. Please add the fileDict.json file to the appdata folder.'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Song Library'),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 230, 205, 232),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: "Search for a song",
                suffixIcon: Icon(Icons.search),
              ),
              onTap: () {
                _loadSongsFromJson();
              },
              onChanged: (text) {
                _filterSongs(text);
              },
            ),
          ),
          Expanded(
            child: songsList.isNotEmpty
                ? ListView.builder(
                    itemCount: songsList.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: Text('${songsList[index]['number']}'),
                        title: Text(songsList[index]['name']),
                        trailing: Checkbox(
                          value: songsList[index]['checked'],
                          onChanged: (bool? value) {
                            if (value != null) {
                              setState(() {
                                songsList[index]['checked'] = value;
                                _handleCheckboxChange(songsList[index]['name'], value);
                              });
                            }
                          },
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Text('No songs found in the library folder.'),
                  ),
          ),
        ],
      ),
    );
  }
}
