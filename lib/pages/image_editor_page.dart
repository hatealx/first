import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_painter/image_painter.dart';

class ImageEditorPage extends StatefulWidget {
  final String imagePath;

  const ImageEditorPage({super.key, required this.imagePath});

  @override
  State<ImageEditorPage> createState() => _ImageEditorPageState();
}

class _ImageEditorPageState extends State<ImageEditorPage> {
  final ImagePainterController _controller = ImagePainterController(
    color: Colors.green,
    strokeWidth: 4,
    mode: PaintMode.line,
  );
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 157, 124, 210),
        title: const Text("Edit Image"),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.save_alt,
             color: Color.fromARGB(255, 244, 239, 238),
            ),
            onPressed: saveImage,
          )
        ],
      ),
      body: ImagePainter.file(
        File(widget.imagePath),
        controller: _controller,
        scalable: true,
        textDelegate: TextDelegate(),
      ),
    );
  }

  void saveImage() async {
    final image = await _controller.exportImage();

    List<String> pathParts = widget.imagePath.split('/');
    String filename = pathParts.last;
    List<String> nameParts = filename.split('.');

    String songname = nameParts.first;

    print(songname);

    if (image != null) {
      final newImage = File(widget.imagePath);

      try {
        await newImage.writeAsBytes(image);

        if (!mounted) return; // Check if the widget is still mounted

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: const Color.fromARGB(255, 131, 64, 238),
              padding: const EdgeInsets.all(10),
              content:  Center(
                child: Text("$songname  editing saved successfully.",
                    style: const TextStyle(color: Colors.white)),
              )),
        );
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return; // Check if the widget is still mounted

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving image: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
