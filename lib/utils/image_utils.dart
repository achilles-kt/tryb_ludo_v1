import 'package:flutter/material.dart';

class ImageUtils {
  static ImageProvider getAvatarProvider(String path) {
    if (path.isEmpty)
      return const AssetImage('assets/avatars/a1.png'); // Fallback

    if (path.startsWith('http') || path.startsWith('https')) {
      return NetworkImage(path);
    } else {
      return AssetImage(path);
    }
  }
}
