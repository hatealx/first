import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'image_editor_page.dart';
import 'zoom_mode_page.dart';

class NonCachingNetworkImageProvider extends ImageProvider<NonCachingNetworkImageProvider> {
  final String url;
  const NonCachingNetworkImageProvider(this.url);

  @override
  Future<NonCachingNetworkImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<NonCachingNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadBuffer(NonCachingNetworkImageProvider key, DecoderBufferCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: url,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>('Image provider', this);
        yield DiagnosticsProperty<String>('Image URL', url);
      },
    );
  }

  Future<ui.Codec> _loadAsync(NonCachingNetworkImageProvider key, DecoderBufferCallback decode) async {
    final bytes = await File(key.url.split('?')[0]).readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return await decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is NonCachingNetworkImageProvider && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;
}

class ViewSongPage extends StatefulWidget {
  final List<Map<String, dynamic>> songs;
  final int initialSongIndex;

  const ViewSongPage({
    super.key,
    required this.songs,
    required this.initialSongIndex,
  });

  @override
  _ViewSongPageState createState() => _ViewSongPageState();
}

class _ViewSongPageState extends State<ViewSongPage> {
  late int _currentSongIndex;
  late int _currentImageIndex;
  late PageController _pageController;
  bool _showIndex = true;
  Timer? _timer;
  double _horizontalDragStartX = 0.0;

  @override
  void initState() {
    super.initState();
    _currentSongIndex = widget.initialSongIndex;
    _currentImageIndex = 0;
    _pageController = PageController(initialPage: _currentImageIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pageController.jumpToPage(_currentImageIndex);
    });
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
    
    print('Image paths: ${widget.songs[_currentSongIndex]['images']}');
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _horizontalDragStartX = details.globalPosition.dx;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final dragDistance = details.globalPosition.dx - _horizontalDragStartX;
    final screenWidth = MediaQuery.of(context).size.width;
    if (dragDistance.abs() > screenWidth / 3) {
      if (dragDistance < 0) {
        _goToNextSong();
      } else {
        _goToPreviousSong();
      }
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
    _timer = Timer(const Duration(milliseconds: 1500), () {
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

  void _handleDoubleTap() {
    String currentImagePath = widget.songs[_currentSongIndex]['images'][_currentImageIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageView(
          imagePath: currentImagePath,
          songName: widget.songs[_currentSongIndex]['name'],
        ),
      ),
    );
  }

  Future<void> _editImage() async {
    String currentImagePath = widget.songs[_currentSongIndex]['images'][_currentImageIndex];
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageEditorPage(imagePath: currentImagePath),
      ),
    );
    if (result == true) {
      setState(() {
        // Force rebuild of the image
        widget.songs[_currentSongIndex]['images'][_currentImageIndex] ;
      });
      
      // Clear the image cache
      imageCache.clear();
      imageCache.clearLiveImages();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> images = widget.songs[_currentSongIndex]['images'];
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.songs[_currentSongIndex]['name'],
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple.withOpacity(0.7),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: _editImage,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: _handleTap,
              onDoubleTap: _handleDoubleTap,
              onHorizontalDragStart: _onHorizontalDragStart,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Image(
                    image: NonCachingNetworkImageProvider(images[index]),
                    fit: BoxFit.contain,
                    key: UniqueKey(), // Add a UniqueKey to force rebuild
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading image: $error');
                      return const Center(
                        child: Text(
                          'Error loading image',
                          style: TextStyle(color: Colors.red, fontSize: 18.0),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_showIndex)
              Positioned(
                bottom: 16.0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Text(
                      'Song ${_currentSongIndex + 1} / ${widget.songs.length} - Image ${_currentImageIndex + 1} / ${images.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
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
    super.dispose();
  }
}