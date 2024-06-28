// ignore_for_file: unnecessary_brace_in_string_interps

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'view_song_page.dart'; // Import the new page

class ThisWeekPage extends StatefulWidget {
  final String appDataPath;

  const ThisWeekPage({super.key, required this.appDataPath});

  @override
  _ThisWeekPageState createState() => _ThisWeekPageState();
}

class _ThisWeekPageState extends State<ThisWeekPage> {
  List<Map<String, dynamic>> songsList = [];
  bool isReorderMode = false;
  late Future<void> _songsFuture;

  @override
  void initState() {
    super.initState();
    _songsFuture = _loadThisWeekSongs();
  }

  Future<void> _loadThisWeekSongs() async {
    try {
      Directory thisWeekDir = Directory('${widget.appDataPath}/this_week');
      File orderFile = File('${thisWeekDir.path}/order.json');

      if (await thisWeekDir.exists()) {
        List<FileSystemEntity> files = await thisWeekDir.list().toList();
        List<Map<String, dynamic>> songs = [];
        int songNumber = 1;

        for (FileSystemEntity file in files) {
          if (file is File && file.path.endsWith('.jpg')) {
            String songName = file.path.split('/').last.split('.').first;
            Directory library= Directory('${widget.appDataPath}/library');
            File validFile = File('${library.path}/${songName}.txt');
            if (await validFile.exists())
            {
               songs.add({'name': songName, 'number': songNumber, 'checked': true, 'path': file.path});
               songNumber++;
            }



           
          }
        }

        if (await orderFile.exists()) {
          String orderContent = await orderFile.readAsString();
          List<dynamic> savedOrder = jsonDecode(orderContent);

          songs.sort((a, b) {
            int indexA = savedOrder.indexWhere((song) => song['name'] == a['name']);
            int indexB = savedOrder.indexWhere((song) => song['name'] == b['name']);
            return indexA.compareTo(indexB);
          });

          // Update song numbers based on saved order
          for (int i = 0; i < songs.length; i++) {
            songs[i]['number'] = i + 1;
          }
        }

        setState(() {
          songsList = songs;
        });
      }
    } catch (e) {
      // Handle errors here
      print("Error loading songs: $e");
      rethrow; // Re-throw to notify FutureBuilder of the error
    }
  }

 void _handleCheckboxChange(String songName, bool isChecked) async {
  Directory thisWeekDir = Directory('${widget.appDataPath}/this_week');

  // Get all files in the this week folder
  List<FileSystemEntity> thisWeekFiles = thisWeekDir.listSync();
  List<String> deletedFiles = [];

  if (!isChecked) {
    for (var file in thisWeekFiles) {
      if (file is File && file.path.endsWith('.jpg') && file.path.contains(RegExp('^${thisWeekDir.path}/$songName.*\.jpg\$'))) {
        await file.delete();
        deletedFiles.add(file.path);
      }
    }
    
    if (deletedFiles.isNotEmpty) {
      _showFlashMessage('$songName images are deleted from this week folder');
    } else {
      _showFlashMessage('No images found for $songName in this week folder');
    }
    
    await _loadThisWeekSongs();  // Reload the list after deleting
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

  void _toggleReorderMode() {
    setState(() {
      isReorderMode = !isReorderMode;
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final Map<String, dynamic> item = songsList.removeAt(oldIndex);
    songsList.insert(newIndex, item);

    // Update song numbers after reordering
    for (int i = 0; i < songsList.length; i++) {
      songsList[i]['number'] = i + 1;
    }

    _saveOrder();
    setState(() {});
  }

  Future<void> _saveOrder() async {
    Directory thisWeekDir = Directory('${widget.appDataPath}/this_week');
    File orderFile = File('${thisWeekDir.path}/order.json');

    List<Map<String, dynamic>> orderList = songsList.map((song) => {'name': song['name']}).toList();
    String orderContent = jsonEncode(orderList);

    await orderFile.writeAsString(orderContent);
  }

  

  Future<void> _confirmDeleteAllSongs() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(10, 10, 10, 0.795),
          title: const Text('Confirm Delete', style: TextStyle(color: Color.fromRGBO(186, 77, 77, 0.792)),),
          content: const Text('Are you sure you want to delete all songs from this week?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete',style: TextStyle(color: Color.fromARGB(200, 205, 23, 23))),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _deleteAllSongs();
    }
  }

  Future<void> _deleteAllSongs() async {
    try {
      Directory thisWeekDir = Directory('${widget.appDataPath}/this_week');
      List<FileSystemEntity> files = await thisWeekDir.list().toList();

      for (FileSystemEntity file in files) {
        if (file is File && file.path.endsWith('.jpg')) {
          await file.delete();
        }
      }

      File orderFile = File('${thisWeekDir.path}/order.json');
      if (await orderFile.exists()) {
        await orderFile.delete();
      }

      _showFlashMessage('All songs deleted from this week folder');
      await _loadThisWeekSongs();  // Reload the list after deleting
    } catch (e) {
      print("Error deleting songs: $e");
      // Optionally, show a flash message or a dialog to notify the user
    }
  }


  void _viewSongImage(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewSongPage(
          songs: songsList, // Pass the entire songsList
          initialIndex: index,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('This Week Songs',
         style: TextStyle(color: Color.fromARGB(250, 243, 242, 242)),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(isReorderMode ? Icons.check : Icons.edit, 
            color: const Color.fromARGB(250, 239, 109, 109),
            size: 25.0,
            ),
            onPressed: _toggleReorderMode,
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _songsFuture,
        builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          } else {
            return isReorderMode
                ? ReorderableListView(
                    onReorder: _onReorder,
                    children: [
                      for (int index = 0; index < songsList.length; index++)
                        Card(
                          key: ValueKey(songsList[index]['name']),
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple,
                              child: Text(
                                '${songsList[index]['number']}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(songsList[index]['name']),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility),
                                  onPressed: () => _viewSongImage(songsList[index]['path']),
                                ),
                                Checkbox(
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
                              ],
                            ),
                          ),
                        ),
                    ],
                  )
                : songsList.isNotEmpty
                    ? ListView.builder(
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
                              title: Text(songsList[index]['name']),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.visibility),
                                    onPressed: () => _viewSongImage(index),
                                  ),
                                  Checkbox(
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
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Text('No songs found in this week folder.',
                        style: TextStyle(color: Color.fromARGB(249, 0, 0, 0)),
                        ),
                      );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _confirmDeleteAllSongs,
        backgroundColor: Colors.red,
        tooltip: 'Delete All Songs',
        child: const Icon(Icons.delete, color: Colors.white),
      ),
    );
  }
}
