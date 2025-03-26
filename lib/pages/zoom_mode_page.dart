import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'image_editor_page.dart';

class FullScreenImageView extends StatefulWidget {
  final List<Map<String, dynamic>> songs;
  final int initialSongIndex;

  const FullScreenImageView({
    Key? key,
    required this.songs,
    required this.initialSongIndex,
  }) : super(key: key);

  @override
  _FullScreenImageViewState createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<FullScreenImageView>
    with SingleTickerProviderStateMixin {
  late int _currentSongIndex;
  late int _currentImageIndex;
  late PageController _pageController;
  bool _showIndex = true;
  Timer? _timer;
  bool _showBars = true;
  bool _isVerticalDragging = false;
  double _verticalDragStart = 0;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentSongIndex = widget.initialSongIndex;
    _currentImageIndex = 0;
    _pageController = PageController(initialPage: 0);

    // Start the timer to hide UI elements.
    _startHideIndexTimer();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
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
        // Clear the image cache to reload edited images.
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

  // Updated to loop back to first song when at the end.
  void _goToNextSong() {
    setState(() {
      _currentSongIndex = (_currentSongIndex + 1) % widget.songs.length;
      _currentImageIndex = 0; // Reset image index for the new song.
      _pageController.jumpToPage(_currentImageIndex);
      _showIndex = true;
      _showBars = true;
    });
    _startHideIndexTimer();
  }

  // Updated to loop back to last song when at the beginning.
  void _goToPreviousSong() {
    setState(() {
      _currentSongIndex =
          (_currentSongIndex - 1 + widget.songs.length) % widget.songs.length;
      _currentImageIndex = 0; // Reset image index for the new song.
      _pageController.jumpToPage(_currentImageIndex);
      _showIndex = true;
      _showBars = true;
    });
    _startHideIndexTimer();
  }

  void _handleVerticalDragStart(DragStartDetails details) {
    _isVerticalDragging = true;
    _verticalDragStart = details.globalPosition.dy;
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (!_isVerticalDragging) return;

    double velocity = details.primaryVelocity ?? 0;

    if (velocity.abs() > 300) {
      _slideAnimation = Tween<Offset>(
        begin: const Offset(0.0, 0.0),
        end: Offset(0.0, velocity > 0 ? 1.0 : -1.0),
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ));

      _animationController.forward().then((_) {
        if (velocity > 0) {
          _goToPreviousSong();
        } else {
          _goToNextSong();
        }
        _animationController.reset();
      });
    }

    _isVerticalDragging = false;
  }

  void _handlePageChange(int index) {
    if (!mounted) return;
    // For pages within bounds, simply update the current image index.
    setState(() {
      _currentImageIndex = index;
    });

    _showIndex = true;
    _showBars = true;
    _startHideIndexTimer();
  }

  // NotificationListener to detect horizontal overscroll for multi-image songs.
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is OverscrollNotification) {
      final currentImages = widget.songs[_currentSongIndex]['images'];
      // If swiping left on the last image.
      if (notification.overscroll > 0 &&
          _currentImageIndex == currentImages.length - 1) {
        _goToNextSong();
      }
      // If swiping right on the first image.
      else if (notification.overscroll < 0 && _currentImageIndex == 0) {
        _goToPreviousSong();
      }
    }
    return false;
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
                color: Colors.white,
              ),
            )
          : null,
      // Added onHorizontalDragEnd to capture horizontal swipes when there's only one image.
      body: GestureDetector(
        onTap: _toggleBars,
        onVerticalDragStart: _handleVerticalDragStart,
        onVerticalDragEnd: _handleVerticalDragEnd,
        onHorizontalDragEnd: (details) {
          // If there is only one image, overscroll may not be triggered,
          // so we handle horizontal swipes here.
          if (widget.songs[_currentSongIndex]['images'].length == 1) {
            const threshold = 300;
            if (details.velocity.pixelsPerSecond.dx > threshold) {
              // Right swipe: go to previous song.
              _goToPreviousSong();
            } else if (details.velocity.pixelsPerSecond.dx < -threshold) {
              // Left swipe: go to next song.
              _goToNextSong();
            }
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScrollNotification,
                  child: PhotoViewGallery.builder(
                    itemCount: images.length,
                    builder: (context, index) {
                      return PhotoViewGalleryPageOptions(
                        imageProvider: FileImage(File(images[index])),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 4,
                      );
                    },
                    scrollPhysics: const ClampingScrollPhysics(),
                    pageController: _pageController,
                    onPageChanged: _handlePageChange,
                  ),
                ),
              ),
            ),
            if (_showIndex)
              Positioned(
                bottom: 16.0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 20.0),
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple[400]?.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(15.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.songs[_currentSongIndex]['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo,
                                color: Colors.deepPurple[100], size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Image ${_currentImageIndex + 1} of ${images.length}',
                              style: TextStyle(
                                color: Colors.deepPurple[100],
                                fontSize: 16.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.library_music,
                                color: Colors.deepPurple[100], size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Song ${_currentSongIndex + 1} of ${widget.songs.length}',
                              style: TextStyle(
                                color: Colors.deepPurple[100],
                                fontSize: 14.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
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
    _animationController.dispose();
    _timer?.cancel();
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual);
    super.dispose();
  }
}
