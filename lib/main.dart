import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:double_back_to_close_app/double_back_to_close_app.dart';
import 'package:first/pages/choose_appdata_gui.dart';
import 'package:first/permissions.dart';
import 'package:first/utils/errorScreen.dart';
import 'package:first/utils/loadingScreen.dart';
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
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? baseDataPath;
  bool isLoading = true;
  String? errorMessage;
  String? selectedLibrary;
  List<String> customLibraries = [];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      var status = await storagePermission();
      if (status) {
        await _setupFolders();
        await _loadSelectedLibrary();
        await _loadCustomLibraries();
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
        print("successfully created ${appDataDir.path}");
        await Directory('${appDataDir.path}/library').create(recursive: true);
        await Directory('${appDataDir.path}/this_week').create(recursive: true);
      }
    } else {
      print("No external storage directories found.");
      ErrorScreen(
          message: "Storage permission is required.", onRetry: _initializeApp);
    }
  }

  Future<void> _loadSelectedLibrary() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedLibrary = prefs.getString('selectedLibrary');
    });
  }

  Future<void> _loadCustomLibraries() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      customLibraries = prefs.getStringList('customLibraries') ?? [];
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
                  ?  Scaffold(
                    body: DoubleBackToCloseApp(
                      snackBar: const SnackBar(
                        content: Text('Tap back again to exit the app'),
                      ),
                      child: MainScreen(
                        appDataPath: '$baseDataPath/$selectedLibrary',
                        appDataName: selectedLibrary!,
                      ),
                    ),
                  )
                  : AppDataSelectionScreen(
                      baseDataPath: baseDataPath!,
                      customLibraries: customLibraries,
                    ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final String appDataPath;
  final String appDataName;

  const MainScreen(
      {super.key, required this.appDataPath, required this.appDataName});

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
    _requestPermissionAndSetup();
  }

  Future<void> _requestPermissionAndSetup() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;

    if (deviceInfo.version.sdkInt > 32) {
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }

      if (status.isGranted) {
        Directory libraryDir = Directory('${widget.appDataPath}/library');
        await _checkAndUpdateDictionary(libraryDir.path);

        setState(() {
          isLoading = false;
        });
      }

    } else {

      print('Requesting storage permission FOR ANDROID SDK <= 32');
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

        List<dynamic> addedSongs = newValidSongs
            .toSet()
            .difference(existingValidSongs.toSet())
            .toList();
        List<dynamic> removedSongs = existingValidSongs
            .toSet()
            .difference(newValidSongs.toSet())
            .toList();

        if (addedSongs.isNotEmpty) {
          _showFlashMessage("Added songs: ${addedSongs.join(', ')}");
        }
        if (removedSongs.isNotEmpty) {
          _showFlashMessage("Removed songs: ${removedSongs.join(', ')}");
        }
      }
      else{
         _showFlashMessage("there is no  update to do on the json dictionary");
      }
    }
  }

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
        backgroundColor: Colors.white,
        title: Center(
          child: Text(
            widget.appDataName.replaceAll('appdata_', '').toUpperCase(),
            style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
          ),
        ),
        actions: [
          IconButton(
          onPressed: () async {
             Directory libraryDir = Directory('${widget.appDataPath}/library');
             await _checkAndUpdateDictionary(libraryDir.path);
              // Trigger a rebuild of the selected page
                setState(() {
                  // You can reassign library or any other state variables if needed
                  library = Map<String, dynamic>.from(library);
                });
          },
          icon:  const Icon(
             Icons.download_for_offline,
              color: Color.fromARGB(255, 7, 43, 222),
          ),),
          IconButton(
            icon: const Icon(
              Icons.swap_horiz,
              color: Color.fromARGB(255, 7, 43, 222),
            ),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.remove('selectedLibrary');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => AppDataSelectionScreen(
                    baseDataPath: widget.appDataPath
                        .replaceAll(RegExp(r'/appdata_[^/]+$'), ''),
                    customLibraries:
                        prefs.getStringList('customLibraries') ?? [],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: CurvedNavigationBar(
        color: Theme.of(context).scaffoldBackgroundColor,
        backgroundColor: Colors.deepPurple,
        items: const <Widget>[
          Icon(Icons.library_music),
          Icon(Icons.list, size: 30),
        ],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}
