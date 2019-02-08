import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_converter/video_converter.dart';
import 'package:file_sharing/file_sharing.dart';

// Работу с камерой взял из примера от плагина camera.
List<CameraDescription> cameras;

Future<void> main() async {
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    logError(e.code, e.description);
  }
  runApp(MyApp());
}

void logError(String code, String message) =>
    print('Error: $code\nError Message: $message');

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Video Catalog'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}


// Экран отвечает за:
// - отображение снятого списка видео
// - отображение элементов управления для снятия видео
// - конвертацию (вырезает кусок после первой секунды длительностью 5сек) и шаринг видео в другие приложения

// Перед шарингом видео каждый раз происходит его конвертация в отдельную папку. 
// Асинхронно от плагина [VideoConverter] получаем уведомление о завершении конвертации и отправляем другому  
// плагину [FileSharing].

class _MyHomePageState extends State<MyHomePage> {
  StreamSubscription<dynamic> _converterEventSubscription;
  ConvertStatus _convertStatus;
  List<VideoFile> _videosList = [];
  CameraController _controller;
  String _currentRecordingPath;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _controller = CameraController(cameras[0], ResolutionPreset.medium);
    _controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _controller.addListener(_cameraStateChanged);
      setState(() {});
    });
    // Подписываемся на статусы конвертера, ведь видео обрабатывается асинхронно.
    _converterEventSubscription = VideoConverter.onConvertStatusChanged.listen(_onConvertStatusChanged);
    _updateVideoCatalogInfo();
  }

  // Incoming updates from VideoConverter plugin
  // Когда приходит 'success', то шарим видео
  void _onConvertStatusChanged(ConvertStatus convertStatus) {
    _convertStatus = convertStatus;
    print(_convertStatus);
    if (mounted) {
      if (_convertStatus.status == ConvertStatusType.success) {
        FileSharing.share(_convertStatus.outputFilePath);
      }
      setState(() {});
    }
  }

  // Возвращает виджет, отображающий статус состояния конвертера.
  Widget getConverterStatusWidget() {
    if (_convertStatus == null) {
      return null;
    }
    switch (_convertStatus.status) {
      case ConvertStatusType.failed:
        return Text('=(');
      case ConvertStatusType.inProcess:
        return Center(
          child: CupertinoActivityIndicator(animating: true,),
        );
      case ConvertStatusType.success:
        return Text('');
    }
    return null;
  }

  // Создаем FileStat для всех файлов в каталоге. По массиву из них составляется
  // список видео файлов
  void _updateVideoCatalogInfo() async {
    _videosList.clear();
    final Directory extDir = await getApplicationDocumentsDirectory();
    Directory('${extDir.path}/records')
      .list(recursive: false, followLinks: false)
      .listen((FileSystemEntity entity) {
        FileStat stat = FileStat.statSync(entity.path);
        if (stat.type == FileSystemEntityType.file) {
          _videosList.add(VideoFile(
            name: '${stat.size.toString()} bytes',
            path: entity.path,
            created: stat.changed.toString()
          ));
        }
        setState(() {});
      });
  }

  void _cameraStateChanged() {
    setState(() {});
  }

  // В зависимости от того снимается ли видео или нет - возвращает 'запуск' или 'стоп'
  Widget _controlButtons() {
    return !_controller.value.isRecordingVideo ?
    CupertinoButton(
      child: Text('◉', style: TextStyle(fontSize: 80, color: Colors.red),),
      onPressed: () {
        // TODO После нажатия на 'Старт', визуально кажется, что ничего не просходит, хотя идет инициализация записи. 
        // Нужно сделать дополнительный статус на уровне этого виджета и отображать loading activity допустим.
        onVideoRecordButtonPressed();
      },
    ) :
    CupertinoButton(
      child: Text('✋🏻', style: TextStyle(fontSize: 80)),
      onPressed: () {
        onStopButtonPressed();
      },
    );
  }
   
  // Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    if (_controller == null || !_controller.value.isInitialized) {
      return const Text(
        'Tap a camera',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: CameraPreview(_controller),
      );
    }
  }

  String _timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void _showInSnackBar(String message) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(message)));
  }

  void onVideoRecordButtonPressed() {
    startVideoRecording().then((String filePath) {
      if (mounted) setState(() {});
      if (filePath != null) _showInSnackBar('Saving video to $filePath');
      _updateVideoCatalogInfo();
    });
  }

  Future<void> onStopButtonPressed() async {
    stopVideoRecording().then((_) {
      if (mounted) setState(() {});
      _showInSnackBar('Video recorded to: $_currentRecordingPath');
      _updateVideoCatalogInfo();
    });
  }

  Future<String> startVideoRecording() async {
    if (!_controller.value.isInitialized) {
      _showInSnackBar('Error: select a camera first.');
      return null;
    }

    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/records';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${_timestamp()}.mp4';

    if (_controller.value.isRecordingVideo) {
      // A recording is already started, do nothing.
      return null;
    }

    try {
      _currentRecordingPath = filePath;
      await _controller.startVideoRecording(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
    return filePath;
  }

  Future<void> stopVideoRecording() async {
    if (!_controller.value.isRecordingVideo) {
      return null;
    }

    try {
      await _controller.stopVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
  }

  void _showCameraException(CameraException e) {
    logError(e.code, e.description);
    _showInSnackBar('Error: ${e.code}\n${e.description}');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.title),
        leading: getConverterStatusWidget(),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Container(
                child: ListView(
                  children: _videosList.map((videoFile) => VideoListItem(
                    nameTitle: videoFile.name,
                    createdTitle: videoFile.created,
                    onShareTap: () {
                      // По завершению конвертации вызовется FileSharing.share
                      VideoConverter.convert(videoFile.path);
                    },
                  )).toList(),
                ),
              ),
            ),
            Container(
              height: 250,
              color: Colors.black12,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  mainAxisSize: MainAxisSize.max,
                  children: <Widget>[
                    _cameraPreviewWidget(),
                    _controlButtons()
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() async {
    _controller.removeListener(_cameraStateChanged);
    await _converterEventSubscription?.cancel();
    super.dispose();
  }
}

// Используем для хранения данных об отснятом видео файле.
class VideoFile {
  final String name;
  final String created;
  final String path;

  VideoFile({this.created, this.name, this.path});
}

// Элемент, который используем в основном списке, где отображаются все виде в папке.
// Отображает видео запись, с кнопной 'share'
class VideoListItem extends StatelessWidget {
  final String nameTitle;
  final String createdTitle;
  final VoidCallback onShareTap;

  VideoListItem({this.nameTitle = 'noname', this.createdTitle = '', this.onShareTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: Colors.white,
      child: Column(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        Text('Video file  $nameTitle'),
                        Text(createdTitle)
                      ],
                    ),
                  ),
                  CupertinoButton(
                    child: Text(
                      'Cut & Share',
                      style: TextStyle(
                        fontSize: 18,
                      ),
                    ),
                    onPressed: onShareTap,
                  )
                ],
              ),
            ),
          ),
          Container(
            height: 0.5,
            color: Colors.black,
          )
        ],
      ),
    );
  }
}