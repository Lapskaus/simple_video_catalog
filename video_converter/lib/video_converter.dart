import 'dart:async';

import 'package:flutter/services.dart';

enum ConvertStatusType {
  failed,
  inProcess,
  success,
}

class ConvertStatus {
  final String filePath;
  final String outputFilePath;
  final String errorDescription;
  final ConvertStatusType status;

  ConvertStatus({
    this.filePath,
    this.outputFilePath,
    this.errorDescription,
    this.status
  });

  factory ConvertStatus.fromEvent(dynamic event) {
    final Map<dynamic, dynamic> map = event;
    ConvertStatusType status;
    switch (map['status']) {
      case 'failed':
        status = ConvertStatusType.failed;
        break;
      case 'inProcess':
        status = ConvertStatusType.inProcess;
        break;
      case 'success':
      default:
        status = ConvertStatusType.success;
        break;
    }
    ConvertStatus element = new ConvertStatus(
      filePath: map['filePath'],
      outputFilePath: map['outputFilePath'],
      errorDescription: map['errorDescription'],
      status: status
    );
    return element;
  }

  @override
  String toString() {
    return '$runtimeType('
        'filePath: $filePath, '
        'outputFilePath: $outputFilePath, '
        'errorDescription: $errorDescription, '
        'status: $status, ';
  }
}

class VideoConverter {
  static const MethodChannel _methodsChannel = const MethodChannel('com.lych/video_converter_methods');
  static const EventChannel _eventChannel = EventChannel('com.lych/video_converter_events');


  // Конвертация заключается в вырезании 5ти секундного отрезока видео, после 1сек от его начала
  static Future<void> convert(String filePath) async {
    try {
      return _methodsChannel.invokeMethod('convert', <String, dynamic>{
        'filePath': filePath,
      });
    } on PlatformException catch (e) {
      print(e);
    }
  }

  static Stream<ConvertStatus> _onConvertStatusChanged;

  static Stream<ConvertStatus> get onConvertStatusChanged {
    if (_onConvertStatusChanged == null) {
      _onConvertStatusChanged = _eventChannel
          .receiveBroadcastStream()
          .map((dynamic event) => ConvertStatus.fromEvent(event));
    }
    return _onConvertStatusChanged;
  }
}
