import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  final String appDataPath;
  Map<String, dynamic> library;

  HomePage({super.key, required this.appDataPath, required this.library});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> songsList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndSetup();
  }

  Future<void> _requestPermissionAndSetup() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    if (status.isGranted) {
      Directory libraryDir = Directory('${widget.appDataPath}/library');
      Directory thisWeekDir = Directory('${widget.appDataPath}/this_week');

      if (!await libraryDir.exists()) {
        await libraryDir.create();
      }

      if (!await thisWeekDir.exists()) {
        await thisWeekDir.create();
      }

      if (await libraryDir.exists()) {
        songsList = await _getSongsList(libraryDir.path, thisWeekDir.path);
      }

      setState(() {
        isLoading = false; // Set loading to false once songs are loaded
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getSongsList(
      String libraryPath, String thisWeekPath) async {
    List<Map<String, dynamic>> songs = [];
    Directory libraryDir = Directory(libraryPath);
    Directory thisWeekDir = Directory(thisWeekPath);

    if (await libraryDir.exists()) {
      List<FileSystemEntity> files = await libraryDir.list().toList();

      for (FileSystemEntity file in files) {
        if (file is File && file.path.endsWith('.txt')) {
          String songName = file.path.split('/').last.split('.').first;
          bool isChecked = await File('${thisWeekDir.path}/$songName.jpg').exists();
          bool hasImage = await File('${libraryDir.path}/$songName.jpg').exists();
          songs.add({'name': songName, 'checked': isChecked, 'hasImage': hasImage});
        }
      }

      // Sort songs alphabetically by name
      songs.sort((a, b) => a['name'].compareTo(b['name']));

      // Update the songNumber after sorting
      for (int i = 0; i < songs.length; i++) {
        songs[i]['number'] = i + 1;
      }
    }

    return songs;
  }

  void _filterSongs(String query) async {
    List<Map<String, dynamic>> filteredSongs = [];
    Set<String> songNamesSet = {};
    List<String> queryWords = query
        .toLowerCase()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();

    if (queryWords.isEmpty) {
      for (var song in widget.library.entries) {
        songNamesSet.addAll(List<String>.from(song.value));
      }
    } else {
      Set<String>? commonSongs;
      for (var word in queryWords) {
        if (widget.library.containsKey(word)) {
          Set<String> wordSongs = Set.from(List<String>.from(widget.library[word]!));
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

    Directory thisWeekDir = Directory('${widget.appDataPath}/this_week');
    int songNumber = 1;
    for (var songName in songNamesSet) {
      bool isChecked = await File('${thisWeekDir.path}/$songName.jpg').exists();
      bool hasImage = await File('${widget.appDataPath}/library/$songName.jpg').exists();
      filteredSongs.add({'name': songName, 'number': songNumber, 'checked': isChecked, 'hasImage': hasImage});
      songNumber++;
    }

    // Sort filtered songs alphabetically by name
    filteredSongs.sort((a, b) => a['name'].compareTo(b['name']));

    for (int i = 0; i < filteredSongs.length; i++) {
        filteredSongs[i]['number'] = i + 1;
      }

    setState(() {
      songsList = filteredSongs;
    });
  }

 void _handleCheckboxChange(String songName, bool isChecked) async {
  Directory libraryDir = Directory('${widget.appDataPath}/library');
  Directory thisWeekDir = Directory('${widget.appDataPath}/this_week');

  // Get all files in the library folder
  List<FileSystemEntity> libraryFiles = libraryDir.listSync();
  List<String> matchingFiles = [];

  // Find all JPG files that start with the song name
  for (var file in libraryFiles) {
    if (file is File && file.path.endsWith('.jpg') && file.path.contains(RegExp('^${libraryDir.path}/$songName.*\.jpg\$'))) {
      matchingFiles.add(file.path);
    }
  }

  if (isChecked) {
    for (String filePath in matchingFiles) {
      String fileName = filePath.split('/').last;
      String destinationPath = '${thisWeekDir.path}/$fileName';

      if (await File(filePath).exists()) {
        await File(filePath).copy(destinationPath);
      }
    }
     _showFlashMessage('$songName is copied to this week folder');
  } else {
    for (String filePath in matchingFiles) {
      String fileName = filePath.split('/').last;
      String destinationPath = '${thisWeekDir.path}/$fileName';

      if (await File(destinationPath).exists()) {
        await File(destinationPath).delete();
        _showFlashMessage('$fileName is deleted from this week folder');
      }
    }
  }
}


  void _showFlashMessage(String message) {
    final snackBar = SnackBar(
      content: Text(message),
      duration: const Duration(milliseconds: 1500),
      backgroundColor: Colors.deepPurpleAccent,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

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

  Future<void> _loadSongsFromJson() async {
    try {
      File jsonFile = File('${widget.appDataPath}/fileDict.json');
      if (await jsonFile.exists()) {
        String jsonString = await jsonFile.readAsString();
        setState(() {
          widget.library = json.decode(jsonString);
        });
      } else {
        widget.library.clear();
        _showNoDictionaryPopup();
      }
    } catch (e) {
      print("Error loading JSON file: $e");
      widget.library.clear();
      _showNoDictionaryPopup();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text('Song Library'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: "Search for a song",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _filterSongs('');
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                    onTap: () async {
                      await _loadSongsFromJson();
                    },
                    onChanged: (text) {
                      _filterSongs(text);
                    },
                  ),
                ),
                Expanded(
                  child: songsList.isEmpty
                      ? const Center(
                          child: Text(
                            'No songs found in the library folder.',
                            style: TextStyle(color: Color.fromARGB(249, 0, 0, 0)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: songsList.length,
                          itemBuilder: (context, index) {
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.deepPurple,
                                  child: Text(
                                    '${songsList[index]['number']}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  songsList[index]['name'],
                                  style: TextStyle(
                                    color: songsList[index]['hasImage']
                                        ? Colors.black
                                        : Colors.red,
                                        fontWeight: FontWeight.bold
                                  ),
                                ),
                                trailing: Checkbox(
                                  value: songsList[index]['checked'],
                                  onChanged: songsList[index]['hasImage']
                                      ? (bool? value) {
                                          if (value != null) {
                                            setState(() {
                                              songsList[index]['checked'] = value;
                                              _handleCheckboxChange(songsList[index]['name'], value);
                                            });
                                          }
                                        }
                                      : null, // Disable checkbox if no image file
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
