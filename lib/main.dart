import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'pages/home_page.dart';
import 'pages/this_week_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String appDataPath = "";
  List<Directory>? externalDirs = await getExternalStorageDirectories();

  if (externalDirs != null && externalDirs.isNotEmpty) {
    Directory externalDir = externalDirs.first;
    appDataPath = '${externalDir.parent.parent.parent.parent.path}/appdata';

    try {
      Directory appDataDir = Directory(appDataPath);
      if (!await appDataDir.exists()) {
        await appDataDir.create(recursive: true);
        print("AppData directory created at: $appDataPath");
      }
      Directory libraryDir = Directory('$appDataPath/library');
      if (!await libraryDir.exists()) {
        await libraryDir.create(recursive: true);
        print("Library directory created at: ${libraryDir.path}");
      }
      Directory thisWeekDir = Directory('$appDataPath/this_week');
      if (!await thisWeekDir.exists()) {
        await thisWeekDir.create(recursive: true);
        print("ThisWeek directory created at: ${thisWeekDir.path}");
      }
    } catch (e) {
      debugPrint("Error creating folders: $e");
    }
  }

  print(appDataPath);

  runApp(MyApp(appDataPath: appDataPath));
}

class MyApp extends StatelessWidget {
  final String appDataPath;

  const MyApp({super.key, required this.appDataPath});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Music App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: MainScreen(appDataPath: appDataPath),
    );
  }
}

class MainScreen extends StatefulWidget {
  final String appDataPath;

  const MainScreen({super.key, required this.appDataPath});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic> library = {};
  bool isLoading = true;
  Map<String, dynamic> newLibrary = {};

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
      await _checkAndUpdateDictionary(libraryDir.path);

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _checkAndUpdateDictionary(String libraryPath) async {
    File jsonFile = File('${widget.appDataPath}/fileDict.json');

    if (!await jsonFile.exists()) {
      Map<String, dynamic> newLibrary = await _createDictionaryMap(libraryPath);
      await _saveDictToJson(newLibrary);
      setState(() {
        library = newLibrary;
      });
      _showFlashMessage("File json dictionary created");
    } else {
      String jsonString = await jsonFile.readAsString();
      Map<String, dynamic> existingLibrary = json.decode(jsonString);

      Map<String, dynamic> newLibrary = await _createDictionaryMap(libraryPath);
      List<dynamic> existingValidSongs = existingLibrary['**'] ?? [];
      List<dynamic> newValidSongs = newLibrary['**'] ?? [];

      if (!listEquals(existingValidSongs, newValidSongs)) {
        await _saveDictToJson(newLibrary);
        setState(() {
          library = newLibrary;
        });

        // Find the songs that have been added or removed
        List<dynamic> addedSongs = newValidSongs
            .toSet()
            .difference(existingValidSongs.toSet())
            .toList();
        List<dynamic> removedSongs = existingValidSongs
            .toSet()
            .difference(newValidSongs.toSet())
            .toList();

        // Show a flash message with the songs that have been added or removed
        if (addedSongs.isNotEmpty) {
          _showFlashMessage("Added songs: ${addedSongs.join(', ')}");
        }
        if (removedSongs.isNotEmpty) {
          _showFlashMessage("Removed songs: ${removedSongs.join(', ')}");
        }
      }
    }
  }

  Future<Map<String, dynamic>> _createDictionaryMap(String libraryPath) async {
    Map<String, dynamic> library = {};
    library['**'] = []; // List to store all valid text files
    Directory libraryDir = Directory(libraryPath);

    if (await libraryDir.exists()) {
      List<FileSystemEntity> files = await libraryDir.list().toList();

      for (FileSystemEntity file in files) {
        if (file is File && file.path.endsWith('.txt')) {
          String fileName = file.path.split('/').last.split('.').first;
          String imagePath = '${libraryDir.path}/$fileName.jpg';

          if (await File(imagePath).exists()) {
            library['**'].add(fileName); // Add the valid text file to the list

            // Add words from the filename to the library
            for (String word in _getWords(fileName)) {
              _addWordToLibrary(word, fileName, library);
            }

            // Add words from the file content to the library
            String fileContent = await File(file.path).readAsString();
            for (String word in _getWords(fileContent)) {
              _addWordToLibrary(word, fileName, library);
            }
          }
        }
      }
    }

    // Sort the library keys for better readability
    Map<String, dynamic> sortedLibrary = Map.fromEntries(
        library.entries.toList()..sort((e1, e2) => e1.key.compareTo(e2.key)));

    return sortedLibrary;
  }

  List<String> _getWords(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]+'), '') // Remove special characters
        .replaceAll(
            RegExp(r'\s+'), ' ') // Replace multiple spaces with a single space
        .replaceAll(RegExp(r'\r\n|\r|\n'),
            ' ') // Replace newline characters with a space
        .split(' ') // Split into words
        .where((word) => word.isNotEmpty) // Remove empty words
        .toSet() // Remove duplicates
        .toList();
  }

  void _addWordToLibrary(
      String word, String fileName, Map<String, dynamic> library) {
    if (!library.containsKey(word)) {
      library[word] = [];
    }
    if (!library[word].contains(fileName)) {
      library[word].add(fileName);
    }
  }

  Future<void> _saveDictToJson(Map<String, dynamic> library) async {
    File jsonFile = File('${widget.appDataPath}/fileDict.json');
    String jsonString = const JsonEncoder.withIndent('  ')
        .convert(library); // Use indented JSON for better readability
    await jsonFile.writeAsString(jsonString);
  }

  void _showFlashMessage(String message) {
    final snackBar = SnackBar(
      content: Text(message),
      duration: const Duration(milliseconds: 6000),
      backgroundColor: Colors.deepPurpleAccent,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    List<Widget> pages = [
      HomePage(appDataPath: widget.appDataPath, library: library),
      ThisWeekPage(appDataPath: widget.appDataPath),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'This Week',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color.fromARGB(255, 247, 142, 5),
        onTap: _onItemTapped,
        backgroundColor: const Color.fromARGB(255, 22, 27, 155),
        unselectedItemColor: Colors.white,
      ),
      backgroundColor: Color.fromARGB(255, 227, 223, 228),
    );
  }

  
}
