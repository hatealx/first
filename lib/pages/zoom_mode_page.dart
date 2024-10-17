import 'dart:io';

import 'package:first/pages/image_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';

class FullScreenImageView extends StatefulWidget {
  final String imagePath;
  final String songName;

  const FullScreenImageView({super.key, required this.imagePath, required this.songName});

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
              title: Text(widget.songName,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.deepPurple.withOpacity(0.7),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ImageEditorPage(imagePath: widget.imagePath),
                      ),
                    );
                  },
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: _toggleBars,
        onDoubleTap: _handleDoubleTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PhotoView(
              imageProvider: FileImage(File(widget.imagePath)),
              controller: _controller,
              scaleStateController: PhotoViewScaleStateController(),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    super.dispose();
  }
}
