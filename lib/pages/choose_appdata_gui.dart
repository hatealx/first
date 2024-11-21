import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:first/main.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:io';

class AppDataSelectionScreen extends StatefulWidget {
  final String baseDataPath;
  final List<String> customLibraries;

  const AppDataSelectionScreen({
    Key? key,
    required this.baseDataPath,
    required this.customLibraries,
  }) : super(key: key);

  @override
  _AppDataSelectionScreenState createState() => _AppDataSelectionScreenState();
}

class _AppDataSelectionScreenState extends State<AppDataSelectionScreen> {
  late List<String> customLibraries;

  @override
  void initState() {
    super.initState();
    customLibraries = List.from(widget.customLibraries);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: false,
            pinned: true,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF8E6DE8), Color(0xFF6A5ACD)],
                ),
              ),
              child: const FlexibleSpaceBar(
                title: Text(
                  'Select Music Library',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: true,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: AnimationLimiter(
              child: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildListDelegate([
                  _buildLibraryCard(context, 'SBC Library', 'appdata_sbc',
                      'assets/sbc_library.jpg', Colors.blue),
                  _buildLibraryCard(context, 'Ukulele Library', 'appdata_uke',
                      'assets/ukulele_library.jpg', Colors.green),
                  _buildLibraryCard(context, 'Christmas Library', 'appdata_xmas',
                      'assets/christmas_library.jpg', Colors.red),
                  ...customLibraries.map((library) => _buildLibraryCard(
                      context,
                      library,
                      library,
                      'assets/custom.jpeg',
                      Colors.orange)),
                  _buildCreateNewLibraryCard(context),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryCard(BuildContext context, String title,
      String appDataFolder, String imagePath, Color accentColor) {
    return AnimationConfiguration.staggeredGrid(
      position: 0,
      duration: const Duration(milliseconds: 500),
      columnCount: 2,
      child: ScaleAnimation(
        child: FadeInAnimation(
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              onTap: () => _selectAppData(context, appDataFolder),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Hero(
                        tag: appDataFolder,
                        child: Image.asset(
                          imagePath,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                      ),
                      child: Center(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateNewLibraryCard(BuildContext context) {
    return AnimationConfiguration.staggeredGrid(
      position: 0,
      duration: const Duration(milliseconds: 500),
      columnCount: 2,
      child: ScaleAnimation(
        child: FadeInAnimation(
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              onTap: () => _createNewLibrary(context),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, size: 64, color: Colors.purple),
                  SizedBox(height: 16),
                  Text(
                    'Create New Library',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
          appDataPath: '${widget.baseDataPath}/$appDataFolder',
          appDataName: appDataFolder,
        ),
      ),
    );
  }

  void _createNewLibrary(BuildContext context) async {
    String? newLibraryName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        String libraryName = '';
        return AlertDialog(
          title: Text('Create New Library'),
          content: TextField(
            onChanged: (value) {
              libraryName = value;
            },
            decoration: InputDecoration(hintText: "Enter library name"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Create'),
              onPressed: () {
                Navigator.of(context).pop(libraryName);
              },
            ),
          ],
        );
      },
    );

    if (newLibraryName != null && newLibraryName.isNotEmpty) {
      String appDataFolder = 'appdata_${newLibraryName.toLowerCase().replaceAll(' ', '_')}';
      Directory newLibraryDir = Directory('${widget.baseDataPath}/$appDataFolder');
      await newLibraryDir.create(recursive: true);
      await Directory('${newLibraryDir.path}/library').create(recursive: true);
      await Directory('${newLibraryDir.path}/this_week').create(recursive: true);

      setState(() {
        customLibraries.add(appDataFolder);
      });

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('customLibraries', customLibraries);

      // Optionally, you can automatically select the newly created library
      _selectAppData(context, appDataFolder);
    }
  }
}