import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';

class ViewSongPage extends StatefulWidget {
  final List<Map<String, dynamic>> songs;
  final int initialSongIndex;

  ViewSongPage({required this.songs, required this.initialSongIndex});

  @override
  _ViewSongPageState createState() => _ViewSongPageState();
}

class _ViewSongPageState extends State<ViewSongPage> {
  late int _currentSongIndex;
  late int _currentImageIndex;
  bool _showIndex = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentSongIndex = widget.initialSongIndex;
    _currentImageIndex = 0;
    _startHideIndexTimer();
    _printDebugInfo();
  }

  void _printDebugInfo() {
    print('Current song: ${widget.songs[_currentSongIndex]['name']}');
    print('Number of images: ${widget.songs[_currentSongIndex]['images'].length}');
    print('Image paths: ${widget.songs[_currentSongIndex]['images']}');
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (details.primaryVelocity != null) {
      if (details.primaryVelocity! < 0) {
        // Swiped left
        _goToNextSong();
      } else if (details.primaryVelocity! > 0) {
        // Swiped right
        _goToPreviousSong();
      }
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    print('Vertical drag detected: ${details.delta.dy}');
    if (details.delta.dy < -10) {
      // Swiped up
      _goToNextImage();
    } else if (details.delta.dy > 10) {
      // Swiped down
      _goToPreviousImage();
    }
  }

  void _goToNextSong() {
    if (_currentSongIndex < widget.songs.length - 1) {
      setState(() {
        _currentSongIndex++;
        _currentImageIndex = 0;
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
        _currentImageIndex = 0;
        _showIndex = true;
      });
      _startHideIndexTimer();
      _printDebugInfo();
    }
  }

  void _goToNextImage() {
    List<String> images = widget.songs[_currentSongIndex]['images'];
    print('Attempting to go to next image. Current index: $_currentImageIndex, Total images: ${images.length}');
    if (_currentImageIndex < images.length - 1) {
      setState(() {
        _currentImageIndex++;
        _showIndex = true;
      });
      _startHideIndexTimer();
      print('Moved to next image. New index: $_currentImageIndex');
    } else {
      print('Already at the last image');
    }
  }

  void _goToPreviousImage() {
    print('Attempting to go to previous image. Current index: $_currentImageIndex');
    if (_currentImageIndex > 0) {
      setState(() {
        _currentImageIndex--;
        _showIndex = true;
      });
      _startHideIndexTimer();
      print('Moved to previous image. New index: $_currentImageIndex');
    } else {
      print('Already at the first image');
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<String> images = widget.songs[_currentSongIndex]['images'];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.songs[_currentSongIndex]['name']),
      ),
      body: GestureDetector(
        onTap: _handleTap,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        child: Stack(
          children: [
            Center(
              child: Image.file(
                File(images[_currentImageIndex]),
                fit: BoxFit.cover,
              ),
            ),
            if (_showIndex)
              Positioned(
                bottom: 16.0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    color: Colors.black54,
                    child: Text(
                      'Song ${_currentSongIndex + 1} / ${widget.songs.length} - Image ${_currentImageIndex + 1} / ${images.length}',
                      style: TextStyle(color: Colors.white, fontSize: 16.0),
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