import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'view_song_page.dart';

class ThisWeekPage extends StatefulWidget {
  final String appDataPath;

  const ThisWeekPage({Key? key, required this.appDataPath}) : super(key: key);

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
      if (!await thisWeekDir.exists()) {
        print("This week directory does not exist");
        return;
      }

      Map<String, List<String>> songImages = {};

      // First pass: Identify valid songs and their initial images
      List<FileSystemEntity> files = await thisWeekDir.list().toList();
      for (FileSystemEntity entity in files) {
        if (entity is File && entity.path.endsWith('.jpg')) {
          String fileName = entity.path.split('/').last;
          String songName = fileName.split('.').first;
          File validFile = File('${widget.appDataPath}/library/${songName}.txt');
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

      // Update state
      setState(() {
        songsList = songs;
      });

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

  void _handleCheckboxChange(String songName, bool isChecked) async {
    try {
      Directory thisWeekDir = Directory('${widget.appDataPath}/this_week');
      List<FileSystemEntity> thisWeekFiles = thisWeekDir.listSync();
      List<String> deletedFiles = [];

      if (!isChecked) {
        for (var file in thisWeekFiles) {
          if (file is File && file.path.endsWith('.jpg') && file.path.contains(songName)) {
            await file.delete();
            deletedFiles.add(file.path);
          }
        }

        String message = deletedFiles.isNotEmpty
            ? '$songName images are deleted from this week folder'
            : 'No images found for $songName in this week folder';
        _showFlashMessage(message);

        await _loadThisWeekSongs();
      }
    } catch (e) {
      print("Error handling checkbox change: $e");
      _showFlashMessage('Error occurred while processing');
    }
  }
  
  void _showFlashMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.deepPurpleAccent,
    ));
  }

  void _toggleReorderMode() {
    setState(() {
      isReorderMode = !isReorderMode;
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = songsList.removeAt(oldIndex);
      songsList.insert(newIndex, item);

      for (int i = 0; i < songsList.length; i++) {
        songsList[i]['number'] = i + 1;
      }
    });
    _saveOrder();
  }

  Future<void> _saveOrder() async {
    try {
      Directory thisWeekDir = Directory('${widget.appDataPath}/this_week');
      File orderFile = File('${thisWeekDir.path}/order.json');

      List<Map<String, dynamic>> orderList = songsList.map((song) => {'name': song['name']}).toList();
      String orderContent = jsonEncode(orderList);

      await orderFile.writeAsString(orderContent);
    } catch (e) {
      print("Error saving order: $e");
      _showFlashMessage('Error occurred while saving order');
    }
  }

  Future<void> _confirmDeleteAllSongs() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(184, 10, 10, 10),
        title: const Text('Confirm Delete',
        style: TextStyle(color: Color.fromARGB(248, 244, 98, 98))),
        content: const Text('Are you sure you want to delete all songs from this week?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteAllSongs();
    }
  }

  Future<void> _deleteAllSongs() async {
    try {
      Directory thisWeekDir = Directory('${widget.appDataPath}/this_week');
      await for (FileSystemEntity file in thisWeekDir.list()) {
        if (file is File && file.path.endsWith('.jpg')) {
          await file.delete();
        }
      }

      File orderFile = File('${thisWeekDir.path}/order.json');
      if (await orderFile.exists()) {
        await orderFile.delete();
      }

      _showFlashMessage('All songs deleted from this week folder');
      await _loadThisWeekSongs();
    } catch (e) {
      print("Error deleting songs: $e");
      _showFlashMessage('Error occurred while deleting songs');
    }
  }

  void _viewSongImages(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewSongPage(
          songs: songsList,
          initialSongIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('This Week Songs', style: TextStyle(color: Color.fromARGB(247, 243, 243, 243))),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(isReorderMode ? Icons.check : Icons.edit, color: const Color.fromARGB(247, 199, 157, 157)),
            onPressed: _toggleReorderMode,
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _songsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            if (songsList.isEmpty) {
              return Center(
                child: Text(
                  'No songs found in this week folder',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              );
            } else {
              return isReorderMode
                  ? ReorderableListView.builder(
                      itemCount: songsList.length,
                      itemBuilder: (context, index) => _buildSongTile(songsList[index], true),
                      onReorder: _onReorder,
                    )
                  : ListView.builder(
                      itemCount: songsList.length,
                      itemBuilder: (context, index) => _buildSongTile(songsList[index], false),
                    );
            }
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _confirmDeleteAllSongs,
        child: const Icon(Icons.delete),
        backgroundColor: const Color.fromARGB(255, 223, 94, 85),
      ),
    );
  }

  Widget _buildSongTile(Map<String, dynamic> song, bool isReorderMode) {
    return Container(
      key: ValueKey(song['name']),
      constraints: BoxConstraints(minHeight: 80),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Color.fromARGB(72, 166, 127, 232).withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Color.fromARGB(40, 218, 207, 237).withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple,
          child: Text('${song['number']}', style: const TextStyle(color: Colors.white)),
        ),
        title: Text(
          song['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${song['images'].length} pages'),
        trailing: isReorderMode
            ? const Icon(Icons.drag_handle)
            : Checkbox(
                value: song['checked'],
                onChanged: (bool? value) {
                  setState(() {
                    song['checked'] = value ?? false;
                    _handleCheckboxChange(song['name'], value ?? false);
                  });
                },
              ),
        onTap: isReorderMode ? null : () => _viewSongImages(songsList.indexOf(song)),
      ),
    );
  }
}