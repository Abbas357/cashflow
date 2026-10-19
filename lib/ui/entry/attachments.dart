import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Receipt photos. Copied into the app's own folder so they survive the
/// original being deleted from the gallery.
class Attachments {
  Attachments._();

  static bool get supported => !kIsWeb;

  static bool get hasCamera =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<String?> pick(ImageSource source) async {
    if (!supported) return null;
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1800,
    );
    if (file == null) return null;
    final dir = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'cash_flow_attachments'),
    );
    await dir.create(recursive: true);
    final ext = p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
    final dest = p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}$ext');
    await File(file.path).copy(dest);
    return dest;
  }

  static Widget image(String path, {BoxFit fit = BoxFit.cover}) {
    if (!supported) return const SizedBox.shrink();
    return Image.file(
      File(path),
      fit: fit,
      errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}
