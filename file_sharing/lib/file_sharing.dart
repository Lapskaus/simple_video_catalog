import 'dart:async';

import 'package:flutter/services.dart';

class FileSharing {
  static const MethodChannel _methodsChannel = const MethodChannel('com.lych/file_sharing_methods');

  static Future<void> share(String filePath) async {
    return _methodsChannel.invokeMethod('share', <String, dynamic>{
      'filePath': filePath,
    });
  }
}
