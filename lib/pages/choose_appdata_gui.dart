import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:first/main.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class AppDataSelectionScreen extends StatelessWidget {
  final String baseDataPath;

  const AppDataSelectionScreen({Key? key, required this.baseDataPath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Light grey background
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            //expandedHeight: 60.0,
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
                title: Text('Select Music Library', 
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
                  _buildLibraryCard(context, 'SBC Library', 'appdata_sbc', 'assets/sbc_library.jpg', Colors.blue),
                  _buildLibraryCard(context, 'Ukulele Library', 'appdata_uke', 'assets/ukulele_library.jpg', Colors.green),
                  _buildLibraryCard(context, 'Christmas Library', 'appdata_xmas', 'assets/christmas_library.jpg', Colors.red),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryCard(BuildContext context, String title, String appDataFolder, String imagePath, Color accentColor) {
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