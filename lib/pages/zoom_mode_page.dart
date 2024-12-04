import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart'; // Import PhotoViewGallery for improved gallery view
import 'image_editor_page.dart';

class FullScreenImageView extends StatefulWidget {
  final List<Map<String, dynamic>> songs;
  final int initialSongIndex;

  const FullScreenImageView({
    super.key,
    required this.songs,
    required this.initialSongIndex,
  });

  @override
  _FullScreenImageViewState createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<FullScreenImageView> {
  late int _currentSongIndex;
  late int _currentImageIndex;
  late PageController _pageController;
  bool _showIndex = true;
  Timer? _timer;
  bool _showBars = true;

  @override
  void initState() {
    super.initState();
    _currentSongIndex = widget.initialSongIndex;
    _currentImageIndex = 0;
    _pageController = PageController(initialPage: _currentImageIndex);

    // Start the timer to hide UI elements
    _startHideIndexTimer();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  void _startHideIndexTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 6000), () {
      if (mounted) {
        setState(() {
          _showIndex = false;
          _showBars = false;
        });
      }
    });
  }

  Future<void> _editImage() async {
    String currentImagePath =
        widget.songs[_currentSongIndex]['images'][_currentImageIndex];

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageEditorPage(imagePath: currentImagePath),
      ),
    );

    if (result == true) {
      setState(() {
        // Clear the image cache to reload edited images
        imageCache.clear();
        imageCache.clearLiveImages();
      });
    }
  }

  void _toggleBars() {
    setState(() {
      _showBars = !_showBars;
      _showIndex = _showBars;
    });

    if (_showBars) {
      _startHideIndexTimer();
    }

    try {
      SystemChrome.setEnabledSystemUIMode(
        _showBars ? SystemUiMode.manual : SystemUiMode.immersive,
        overlays: _showBars ? SystemUiOverlay.values : [],
      );
    } catch (e) {
      print('Error setting System UI Mode: $e');
    }
  }

  void _goToNextSong() {
    if (_currentSongIndex < widget.songs.length - 1) {
      setState(() {
        _currentSongIndex++;
        _currentImageIndex = 0; // Reset image index to 0 for the new song
        _pageController.jumpToPage(_currentImageIndex);
        _showIndex = true;
        _showBars = true;
      });
      _startHideIndexTimer();
    }
  }

  void _goToPreviousSong() {
    if (_currentSongIndex > 0) {
      setState(() {
        _currentSongIndex--;
        _currentImageIndex = 0; // Reset image index to 0 for the new song
        _pageController.jumpToPage(_currentImageIndex);
        _showIndex = true;
        _showBars = true;
      });
      _startHideIndexTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> images = widget.songs[_currentSongIndex]['images'];

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: _showBars
          ? AppBar(
              title: Text(
                widget.songs[_currentSongIndex]['name'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.deepPurple.withOpacity(0.7),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: _editImage,
                ),
              ],
              iconTheme: const IconThemeData(
                color: Colors.white, // Set the color of the back arrow
              ),
            )
          : null,
      body: GestureDetector(
        onTap: _toggleBars,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PhotoViewGallery.builder(
              itemCount: images.length,
              builder: (context, index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: FileImage(File(images[index])),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 4,
                );
              },
              scrollPhysics: const BouncingScrollPhysics(),
              pageController: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentImageIndex = index;
                });
              },
            ),
            if (_showIndex)
              Positioned(
                bottom: 16.0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Text(
                      'Image ${_currentImageIndex + 1} / ${images.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual);
    super.dispose();
  }
}
