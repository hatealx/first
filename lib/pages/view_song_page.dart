import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';

class ViewSongPage extends StatefulWidget {
  final List<Map<String, dynamic>> songs;
  final int initialSongIndex;

  const ViewSongPage({Key? key, required this.songs, required this.initialSongIndex}) : super(key: key);

  @override
  _ViewSongPageState createState() => _ViewSongPageState();
}

class _ViewSongPageState extends State<ViewSongPage> {
  late int _currentSongIndex;
  late int _currentImageIndex;
  late PageController _pageController;
  bool _showIndex = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentSongIndex = widget.initialSongIndex;
    _currentImageIndex = 0;
    _pageController = PageController(initialPage: _currentImageIndex);
    _pageController.addListener(() {
      setState(() {
        _currentImageIndex = _pageController.page?.round() ?? _currentImageIndex;
      });
    });
    _startHideIndexTimer();
    _printDebugInfo();
  }

  void _printDebugInfo() {
    print('Current song: ${widget.songs[_currentSongIndex]['name']}');
    print('Number of images: ${widget.songs[_currentSongIndex]['images'].length}');
    print('Image paths: ${widget.songs[_currentSongIndex]['images']}');
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (details.primaryVelocity == null) return;
    if (details.primaryVelocity! < 0) {
      _goToNextSong();
    } else if (details.primaryVelocity! > 0) {
      _goToPreviousSong();
    }
  }

  void _goToNextSong() {
    if (_currentSongIndex < widget.songs.length - 1) {
      setState(() {
        _currentSongIndex++;
        _pageController.jumpToPage(0);
        _showIndex = true;
      });
      _startHideIndexTimer();
      _printDebugInfo();
    }
  }

  void _goToPreviousSong() {
    if (_currentSongIndex > 0) {
      setState(() {
        _currentSongIndex--;
        _pageController.jumpToPage(0);
        _showIndex = true;
      });
      _startHideIndexTimer();
      _printDebugInfo();
    }
  }

  void _startHideIndexTimer() {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: 1500), () {
      setState(() {
        _showIndex = false;
      });
    });
  }

  void _handleTap() {
    setState(() {
      _showIndex = !_showIndex;
    });
    if (_showIndex) {
      _startHideIndexTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<String> images = widget.songs[_currentSongIndex]['images'];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.songs[_currentSongIndex]['name'], style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple, // Deep color for the app bar
      ),
      body: GestureDetector(
        onTap: _handleTap,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: images.length,
              itemBuilder: (context, index) {
                return AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Image.file(
                    File(images[index]),
                    key: ValueKey<String>(images[index]),
                    fit: BoxFit.cover, // Cover to fill the screen nicely
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading image: $error');
                      return Center(child: Text('Error loading image', style: TextStyle(color: Colors.red, fontSize: 16.0)));
                    },
                  ),
                );
              },
            ),
            if (_showIndex)
              Positioned(
                bottom: 16.0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8.0), // Rounded corners
                    ),
                    child: Text(
                      'Song ${_currentSongIndex + 1} / ${widget.songs.length} - Image ${_currentImageIndex + 1} / ${images.length}',
                      style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
