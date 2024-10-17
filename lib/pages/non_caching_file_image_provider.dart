import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NonCachingFileImageProvider extends ImageProvider<NonCachingFileImageProvider> {
  final String filePath;
  const NonCachingFileImageProvider(this.filePath);

  @override
  Future<NonCachingFileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<NonCachingFileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadBuffer(NonCachingFileImageProvider key, DecoderBufferCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: filePath,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>('Image provider', this);
        yield DiagnosticsProperty<String>('File path', filePath);
      },
    );
  }

  Future<ui.Codec> _loadAsync(NonCachingFileImageProvider key, DecoderBufferCallback decode) async {
    final file = File(key.filePath);
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('File is empty: $filePath');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return await decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is NonCachingFileImageProvider && other.filePath == filePath;
  }

  @override
  int get hashCode => filePath.hashCode;
}
