import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'view_song_page.dart'; // Import the new page

class ThisWeekPage extends StatefulWidget {
  final String appDataPath;

  ThisWeekPage({required this.appDataPath});

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
            songs.add({'name': songName, 'number': songNumber, 'checked': true, 'path': file.path});
            songNumber++;
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
      throw e; // Re-throw to notify FutureBuilder of the error
    }
  }

  void _handleCheckboxChange(String songName, bool isChecked) async {
    Directory thisWeekDir = Directory('${widget.appDataPath}/this_week');

    String filePath = '${thisWeekDir.path}/$songName.jpg';

    if (!isChecked) {
      if (await File(filePath).exists()) {
        await File(filePath).delete();
        _showFlashMessage('$songName is deleted from this week folder');
        await _loadThisWeekSongs();  // Reload the list after deleting
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

  void _viewSongImage(String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewSongPage(imagePath: imagePath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('This Week Songs',
         style: TextStyle(color: Color.fromARGB(250, 243, 242, 242)
        ),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(isReorderMode ? Icons.check : Icons.edit, 
            color: Color.fromARGB(250, 239, 109, 109),
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
            return Center(
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
                          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple,
                              child: Text(
                                '${songsList[index]['number']}',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(songsList[index]['name']),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.visibility),
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
                            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.deepPurple,
                                child: Text(
                                  '${songsList[index]['number']}',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(songsList[index]['name']),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.visibility),
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
                          );
                        },
                      )
                    : const Center(
                        child: Text('No songs found in this week folder.',
                        style: TextStyle(color: Color.fromARGB(249, 0, 0, 0)
        ),
                        ),
                      );
          }
        },
      ),
    );
  }
}
