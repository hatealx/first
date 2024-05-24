import 'package:flutter/material.dart';
import 'dart:io'; // Add this import to use the File class

class ViewSongPage extends StatelessWidget {
  final String imagePath;

  ViewSongPage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Song Image'),
      ),
      body: Center(
        child: Image.file(
          File(imagePath), // Use the File class to display the image
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
