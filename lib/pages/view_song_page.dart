import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'package:photo_view/photo_view.dart';

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
  List<DraggableText> _draggableTexts = [];
  TextEditingController _textController = TextEditingController();
  bool _isAddingText = false;
  bool _isDraggingText = false;
  double _horizontalDragStartX = 0.0;

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

  void _onHorizontalDragStart(DragStartDetails details) {
    _horizontalDragStartX = details.globalPosition.dx;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_isDraggingText) return;
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
        _draggableTexts.clear();
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
        _draggableTexts.clear();
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

  void _addTextToImage() {
    setState(() {
      _isAddingText = true;
    });
  }

  void _submitText() {
    if (_textController.text.isNotEmpty) {
      setState(() {
        _draggableTexts.add(DraggableText(
          text: _textController.text,
          position: Offset(100, 100),
        ));
        _textController.clear();
        _isAddingText = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<String> images = widget.songs[_currentSongIndex]['images'];
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.songs[_currentSongIndex]['name'],
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple.withOpacity(0.7),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.white),
            onPressed: _addTextToImage,
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
              onVerticalDragEnd: _isDraggingText ? null : (_) {},
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(images[index]),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading image: $error');
                          return Center(child: Text('Error loading image', style: TextStyle(color: Colors.red, fontSize: 18.0)));
                        },
                      ),
                      ..._draggableTexts.map((draggableText) => Positioned(
                        left: draggableText.position.dx,
                        top: draggableText.position.dy,
                        child: Draggable(
                          feedback: Material(
                            color: Colors.transparent,
                            child: Text(draggableText.text, style: TextStyle(color: Colors.deepPurple, fontSize: 22)),
                          ),
                          childWhenDragging: Container(),
                          onDragStarted: () {
                            setState(() {
                              _isDraggingText = true;
                            });
                          },
                          onDragEnd: (details) {
                            setState(() {
                              draggableText.position = details.offset;
                              _isDraggingText = false;
                            });
                          },
                          child: Text(draggableText.text, style: TextStyle(color: Colors.deepPurple, fontSize: 22)),
                        ),
                      )).toList(),
                    ],
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
                    padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Text(
                      'Song ${_currentSongIndex + 1} / ${widget.songs.length} - Image ${_currentImageIndex + 1} / ${images.length}',
                      style: TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            if (_isAddingText)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: 'Enter text',
                            hintStyle: TextStyle(color: Colors.deepPurple.withOpacity(0.6)),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.deepPurple),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                          ),
                          style: TextStyle(color: Colors.deepPurple, fontSize: 18),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.send, color: Colors.deepPurple),
                        onPressed: _submitText,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FullScreenImageView extends StatefulWidget {
  final String imagePath;
  final String songName;

  const FullScreenImageView({Key? key, required this.imagePath, required this.songName}) : super(key: key);

  @override
  _FullScreenImageViewState createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<FullScreenImageView> {
  bool _showBars = false;
  late PhotoViewController _controller;
  late PhotoViewScaleState _scaleState;

  @override
  void initState() {
    super.initState();
    _controller = PhotoViewController();
    _scaleState = PhotoViewScaleState.initial;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  void _toggleBars() {
    setState(() {
      _showBars = !_showBars;
    });
    SystemChrome.setEnabledSystemUIMode(
      _showBars ? SystemUiMode.manual : SystemUiMode.immersive,
      overlays: _showBars ? SystemUiOverlay.values : [],
    );
  }

  void _handleDoubleTap() {
    if (_scaleState == PhotoViewScaleState.initial) {
      _controller.scale = (_controller.initial.scale! * 2);
      _scaleState = PhotoViewScaleState.zoomedIn;
    } else {
      _controller.scale = _controller.initial.scale;
      _scaleState = PhotoViewScaleState.initial;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: _showBars
          ? AppBar(
              title: Text(
                widget.songName,
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.deepPurple.withOpacity(0.7),
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: GestureDetector(
        onTap: _toggleBars,
        onDoubleTap: _handleDoubleTap,
        child: PhotoView(
          imageProvider: FileImage(File(widget.imagePath)),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
          initialScale: PhotoViewComputedScale.contained,
          controller: _controller,
          backgroundDecoration: BoxDecoration(color: Colors.black),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }
}

class DraggableText {
  String text;
  Offset position;

  DraggableText({required this.text, required this.position});
}