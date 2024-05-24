import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
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
      }
      Directory libraryDir = Directory('$appDataPath/library');
      if (!await libraryDir.exists()) {
        await libraryDir.create(recursive: true);
      }
      Directory thisWeekDir = Directory('$appDataPath/this_week');
      if (!await thisWeekDir.exists()) {
        await thisWeekDir.create(recursive: true);
      }
    } catch (e) {
      print("Error creating folders: $e");
    }
  }

  print(appDataPath);
  runApp(MyApp(appDataPath: appDataPath));
}

class MyApp extends StatelessWidget {
  final String appDataPath;

  MyApp({required this.appDataPath});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: TextTheme(
          bodyText2: TextStyle(color: Colors.white),
        ),
      ),
      home: MainScreen(appDataPath: appDataPath),
    );
  }
}

class MainScreen extends StatefulWidget {
  final String appDataPath;

  MainScreen({required this.appDataPath});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic> library = {};

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: Color.fromARGB(255, 22, 27, 155),
        unselectedItemColor: Colors.white,
      ),
      backgroundColor: Color.fromARGB(255, 210, 41, 223),
    );
  }
}