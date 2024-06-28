import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';

class ViewSongPage extends StatefulWidget {
  final List<Map<String, dynamic>> songs;
  final int initialIndex;

  ViewSongPage({required this.songs, required this.initialIndex});

  @override
  _ViewSongPageState createState() => _ViewSongPageState();
}

class _ViewSongPageState extends State<ViewSongPage> {
  late int _currentIndex;
  bool _showIndex = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _startHideIndexTimer();
  }

  void _onHorizontalDrag(DragEndDetails details) {
    if (details.primaryVelocity != null) {
      if (details.primaryVelocity! < 0) {
        // Swiped left
        _goToNextImage();
      } else if (details.primaryVelocity! > 0) {
        // Swiped right
        _goToPreviousImage();
      }
    }
  }

  void _goToNextImage() {
    if (_currentIndex < widget.songs.length - 1) {
      setState(() {
        _currentIndex++;
        _showIndex = true;
      });
      _startHideIndexTimer();
    }
  }

  void _goToPreviousImage() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _showIndex = true;
      });
      _startHideIndexTimer();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.songs[_currentIndex]['name']),
      ),
      body: GestureDetector(
        onTap: _handleTap,
        onHorizontalDragEnd: _onHorizontalDrag,
        child: Stack(
          children: [
            Center(
              child: Image.file(
                File(widget.songs[_currentIndex]['path']),
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
                      'Song ${_currentIndex + 1} / ${widget.songs.length}',
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
