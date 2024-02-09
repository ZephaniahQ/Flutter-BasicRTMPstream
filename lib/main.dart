import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rtmp_broadcaster/camera.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RTMP Streamer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const StreamingPage(),
    );
  }
}

class StreamingPage extends StatefulWidget {
  const StreamingPage({Key? key}) : super(key: key);

  @override
  StreamingPageState createState() => StreamingPageState();
}

class StreamingPageState extends State<StreamingPage> {
  CameraController? _controller;
  bool _isStreaming = false;
  String? _streamUrl;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<bool> requestPermissions() async {
    // Request camera permission
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }

    if (status.isDenied) {
      print(
          'Camera permission was denied. Please enable it in the app settings.');
      // Optionally, you can open the app settings page to allow the user to manually grant the permission.
      // openAppSettings();
      return false;
    }

    // Request microphone permission
    status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }

    if (status.isDenied) {
      print(
          'Microphone permission was denied. Please enable it in the app settings.');
      // Optionally, you can open the app settings page to allow the user to manually grant the permission.
      // openAppSettings();
      return false;
    }

    // Both permissions are granted
    return true;
  }

  Future<void> _initCamera() async {
    /* Wait for permissions to be granted
    bool permissionsGranted = await requestPermissions();
    if (!permissionsGranted) {
      print('Permissions not granted. Cannot initialize camera.');
      return;
    }*/

    // Proceed with camera initialization only if permissions are granted
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.high,
      enableAudio: true, // Set to true if you want to enable audio streaming
    );

    _controller!.addListener(() {
      if (!mounted) {
        return;
      }
      setState(() {});
      if (_controller!.value.hasError) {
        print('Camera error ${_controller!.value.errorDescription}');
      }
    });

    await _controller!.initialize();
  }

  void _startStream() async {
    if (_debounceTimer?.isActive ?? false)
      return; // Prevent rapid start actions

    if (_controller == null) {
      print('Error: select a camera first.');
      return;
    }
    if (_isStreaming) {
      print('Streaming is already started.');
      return;
    }

    _streamUrl = 'rtmp://192.168.10.8:1935/live'; // Update with your RTMP URL
    if (_streamUrl == null || _streamUrl!.isEmpty) {
      print('Please enter a valid RTMP URL.');
      return;
    }

    try {
      await _controller!.startVideoStreaming(_streamUrl!);
      setState(() {
        _isStreaming = true;
      });
    } on CameraException catch (e) {
      print('Error: ${e.code}\n${e.description}');
    } finally {
      _debounceTimer = Timer(const Duration(seconds: 2), () {
        _debounceTimer = null;
      });
    }
  }

  void _stopStream() async {
    if (_debounceTimer?.isActive ?? false) return; // Prevent rapid stop actions

    if (_controller == null || !_isStreaming) {
      return;
    }

    try {
      await _controller!.stopVideoStreaming();
      setState(() {
        _isStreaming = false;
      });
    } on CameraException catch (e) {
      print('Error: ${e.code}\n${e.description}');
    } finally {
      _debounceTimer = Timer(const Duration(seconds: 2), () {
        _debounceTimer = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RTMP Streamer'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              child: _controller != null
                  ? AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: CameraPreview(_controller!),
                    )
                  : Container(),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              FloatingActionButton(
                onPressed: _startStream,
                child: const Icon(Icons.cast),
              ),
              const SizedBox(width: 10),
              FloatingActionButton(
                onPressed: _stopStream,
                child: const Icon(Icons.stop),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
