import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/home_page.dart';
import 'pages/this_week_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? baseDataPath;
  bool isLoading = true;
  String? errorMessage;
  String? selectedLibrary;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      var status = await Permission.storage.request();
      if (status.isGranted) {
        await _setupFolders();
        await _loadSelectedLibrary();
      } else {
        throw Exception("Storage permission is required.");
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _setupFolders() async {
    List<Directory>? externalDirs = await getExternalStorageDirectories();
    if (externalDirs != null && externalDirs.isNotEmpty) {
      baseDataPath = externalDirs.first.parent.parent.parent.parent.path;
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

  Future<void> _loadSelectedLibrary() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedLibrary = prefs.getString('selectedLibrary');
    });
  }

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
      home: isLoading
          ? const LoadingScreen()
          : errorMessage != null
              ? ErrorScreen(message: errorMessage!, onRetry: _initializeApp)
              : selectedLibrary != null
                  ? MainScreen(
                      appDataPath: '$baseDataPath/$selectedLibrary',
                      appDataName: selectedLibrary!,
                    )
                  : AppDataSelectionScreen(baseDataPath: baseDataPath!),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorScreen({Key? key, required this.message, required this.onRetry})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(message, textAlign: TextAlign.center),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class AppDataSelectionScreen extends StatelessWidget {
  final String baseDataPath;

  const AppDataSelectionScreen({Key? key, required this.baseDataPath})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 142, 109, 232),
        title: Center(
            child: Text(
          'Select Music Library',
          style: TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
        )),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _selectAppData(context, 'appdata_sbc'),
              child: SizedBox(
                width: 130.0,
                child: Center(
                  child: Text('SBC Library'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _selectAppData(context, 'appdata_uke'),
              child: SizedBox(
                width: 130.0,
                child: Center(
                  child: Text('Ukelele Library'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _selectAppData(context, 'appdata_xmas'),
              child: SizedBox(
                width: 130.0,
                child: Center(
                  child: Text('Chrismast Library'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectAppData(BuildContext context, String appDataFolder) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedLibrary', appDataFolder);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainScreen(
          appDataPath: '$baseDataPath/$appDataFolder',
          appDataName: appDataFolder,
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final String appDataPath;
  final String appDataName;

  const MainScreen(
      {Key? key, required this.appDataPath, required this.appDataName})
      : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic> library = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    //loadLibrary();

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

  // Future<void> _loadLibrary() async {
  //   try {
  //     File jsonFile = File('${widget.appDataPath}/fileDict.json');
  //     if (await jsonFile.exists()) {
  //       String jsonString = await jsonFile.readAsString();

  //       Directory libraryDir = Directory('${widget.appDataPath}/library');
  //       Map<String, dynamic> newLibrary = await _createDictionaryMap(libraryDir.path);

  //       setState(() {
  //         library = json.decode(jsonString);
  //         isLoading = false;
  //       });

  //     } else {
  //       await _createAndSaveLibrary();
  //       _showFlashMessage("File json dictionary created");
  //     }
  //   } catch (e) {
  //     print("Error loading library: $e");
  //     setState(() {
  //       isLoading = false;
  //     });
  //   }
  // }

  // Future<void> _createAndSaveLibrary() async {
  //   try {
  //     Directory libraryDir = Directory('${widget.appDataPath}/library');
  //     Map<String, dynamic> newLibrary = await _createDictionaryMap(libraryDir.path);
  //     await _saveDictToJson(newLibrary);
  //     setState(() {
  //       library = newLibrary;
  //       isLoading = false;
  //     });

  //   } catch (e) {
  //     print("Error creating library: $e");
  //     setState(() {
  //       isLoading = false;
  //     });
  //   }
  // }

  Future<Map<String, dynamic>> _createDictionaryMap(String libraryPath) async {
    Map<String, dynamic> library = {};
    library['**'] = [];
    Directory libraryDir = Directory(libraryPath);

    if (await libraryDir.exists()) {
      List<FileSystemEntity> files = await libraryDir.list().toList();

      for (FileSystemEntity file in files) {
        if (file is File && file.path.endsWith('.txt')) {
          String fileName = file.path.split('/').last.split('.').first;
          String imagePath = '${libraryDir.path}/$fileName.jpg';

          if (await File(imagePath).exists()) {
            library['**'].add(fileName);

            for (String word in _getWords(fileName)) {
              _addWordToLibrary(word, fileName, library);
            }

            String fileContent = await File(file.path).readAsString();
            for (String word in _getWords(fileContent)) {
              _addWordToLibrary(word, fileName, library);
            }
          }
        }
      }
    }

    Map<String, dynamic> sortedLibrary = Map.fromEntries(
        library.entries.toList()..sort((e1, e2) => e1.key.compareTo(e2.key)));

    return sortedLibrary;
  }

  List<String> _getWords(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\r\n|\r|\n'), ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toSet()
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
    String jsonString = const JsonEncoder.withIndent('  ').convert(library);
    await jsonFile.writeAsString(jsonString);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showFlashMessage(String message) {
    final snackBar = SnackBar(
      content: Text(message),
      duration: const Duration(milliseconds: 6000),
      backgroundColor: Colors.deepPurpleAccent,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
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
      appBar: AppBar(
        backgroundColor: Colors.black12,
        title: Center(
          child:
              Text(widget.appDataName.replaceAll('appdata_', '').toUpperCase()),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.remove('selectedLibrary');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => AppDataSelectionScreen(
                      baseDataPath: widget.appDataPath
                          .replaceAll(RegExp(r'/appdata_[^/]+$'), '')),
                ),
              );
            },
          ),
        ],
      ),
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
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }
}
