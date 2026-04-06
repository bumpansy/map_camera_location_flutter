import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'image_and_location_data.dart';

typedef ImageAndLocationCallback = void Function(ImageAndLocationData data);

class MapCameraLocation extends StatefulWidget {
  final CameraDescription camera;
  final ImageAndLocationCallback? onImageCaptured;

  const MapCameraLocation({
    super.key,
    required this.camera,
    this.onImageCaptured,
  });

  @override
  State<MapCameraLocation> createState() => _MapCameraLocationState();
}

class _MapCameraLocationState extends State<MapCameraLocation> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  File? cameraImagePath;
  String? dateTime;
  LocationData? locationData;

  String? _capturedImageResolution;
  String? _capturedImageSize;

  bool _isCapturing = false;
  Timer? _positionTimer;

  FlashMode _flashMode = FlashMode.off;
  final List<FlashMode> _flashModesCycle = [
    FlashMode.off,
    FlashMode.auto,
    FlashMode.always,
    FlashMode.torch,
  ];

  @override
  void initState() {
    super.initState();

    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (mounted) {
        await updatePosition(context);
      }
    });

    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _initializeControllerFuture = _controller.initialize().then((_) {
      if (mounted) {
        final previewSize = _controller.value.previewSize;

        setState(() {
          _flashMode = _controller.value.flashMode;
          _capturedImageResolution =
              "${previewSize?.width.toInt()}x${previewSize?.height.toInt()}";
        });
      }
    });

    dateTime = DateFormat.yMd().add_jm().format(DateTime.now());
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return "$bytes B";

    final double kb = bytes / 1024;
    if (kb < 1024) return "${kb.toStringAsFixed(1)} KB";

    final double mb = kb / 1024;
    return "${mb.toStringAsFixed(2)} MB";
  }

  @override
  void dispose() {
    _controller.dispose();
    _positionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                CameraPreview(_controller),

                /// Flash toggle
                Positioned(
                  top: 40,
                  left: 20,
                  child: IconButton(
                    onPressed: _cycleFlashMode,
                    icon: Icon(_iconForFlashMode(_flashMode),
                        color: Colors.white),
                  ),
                ),

                /// Info overlay
                Positioned(
                  top: 40,
                  right: 20,
                  child: Container(
                    key: ValueKey("${_capturedImageResolution}_${_capturedImageSize}"),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "DEBUG TEXT",
                          style: TextStyle(color: Colors.red),
                        ),

                        Text(
                          locationData?.locationName ?? "Loading...",
                          style: const TextStyle(color: Colors.white),
                        ),

                        Text(
                          "Lat: ${locationData?.latitude ?? "..."}",
                          style: const TextStyle(color: Colors.white),
                        ),

                        Text(
                          "Lng: ${locationData?.longitude ?? "..."}",
                          style: const TextStyle(color: Colors.white),
                        ),

                        Text(
                          dateTime ?? "",
                          style: const TextStyle(color: Colors.white),
                        ),

                        Text(
                          "Res: ${_capturedImageResolution ?? '---'}",
                          style: const TextStyle(color: Colors.white),
                        ),

                        Text(
                          "Size: ${_capturedImageSize ?? '---'}",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

                /// Capture button
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _isCapturing ? null : _captureImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _isCapturing ? Colors.grey : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: _isCapturing
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.camera_alt),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  IconData _iconForFlashMode(FlashMode mode) {
    switch (mode) {
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.torch:
        return Icons.highlight;
      case FlashMode.off:
        return Icons.flash_off;
    }
  }

  void _cycleFlashMode() {
    final current = _flashModesCycle.indexOf(_flashMode);
    final next = _flashModesCycle[(current + 1) % _flashModesCycle.length];
    _setFlashMode(next);
  }

  Future<void> _setFlashMode(FlashMode mode) async {
    try {
      await _controller.setFlashMode(mode);
      setState(() => _flashMode = mode);
    } catch (_) {}
  }

  /// 🔥 FIXED CAPTURE FLOW
  Future<void> _captureImage() async {
    if (_isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final XFile image = await _controller.takePicture();

      /// ===== STEP 1: RAW IMAGE METADATA =====
      final rawFile = File(image.path);
      final rawBytes = await rawFile.readAsBytes();

      final codec = await ui.instantiateImageCodec(rawBytes);
      final frame = await codec.getNextFrame();

      final rawResolution =
          "${frame.image.width}x${frame.image.height}";
      final rawSize = _formatFileSize(rawBytes.length);

      /// UPDATE IMMEDIATELY (IMPORTANT)
      setState(() {
        _capturedImageResolution = rawResolution;
        _capturedImageSize = rawSize;
      });

      /// ===== STEP 2: PROCESS IMAGE =====
      final processedPath = await _addLocationOverlay(image.path);

      final processedFile = File(processedPath);
      final processedBytes = await processedFile.readAsBytes();

      final processedCodec =
          await ui.instantiateImageCodec(processedBytes);
      final processedFrame = await processedCodec.getNextFrame();

      final finalResolution =
          "${processedFrame.image.width}x${processedFrame.image.height}";
      final finalSize = _formatFileSize(processedBytes.length);

      /// FINAL UPDATE
      setState(() {
        cameraImagePath = processedFile;
        _capturedImageResolution = finalResolution;
        _capturedImageSize = finalSize;
      });

      if (widget.onImageCaptured != null) {
        widget.onImageCaptured!(
          ImageAndLocationData(
            imagePath: processedPath,
            locationData: locationData,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print("Capture error: $e");
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  /// 🔥 FIXED OVERLAY (correct size)
  Future<String> _addLocationOverlay(String imagePath) async {
    final imageFile = File(imagePath);
    final imageBytes = await imageFile.readAsBytes();

    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final originalImage = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw original image
    canvas.drawImage(originalImage, Offset.zero, Paint());

    final double padding = 20;
    final double imageHeight = originalImage.height.toDouble();
    final double imageWidth = originalImage.width.toDouble();

    // ===== TEXT CONTENT =====
    final locationText = locationData?.locationName ?? "Unknown Location";
    final coordText =
        "Lat: ${locationData?.latitude ?? "N/A"}, Lng: ${locationData?.longitude ?? "N/A"}";
    final timeText = dateTime ?? DateFormat.yMd().add_jm().format(DateTime.now());

    // TEMP values (we will update size later)
    final resolutionText =
        "Resolution: ${originalImage.width}x${originalImage.height}";
    final sizeTextPlaceholder = "Size: Calculating...";

    // ===== TEXT STYLE =====
    TextStyle style(double size) => TextStyle(
          color: Colors.white,
          fontSize: size,
          fontWeight: FontWeight.w500,
          shadows: const [
            Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black),
          ],
        );

    // ===== CREATE TEXT PAINTERS =====
    TextPainter buildPainter(String text, double size) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style(size)),
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: imageWidth - 40);
      return tp;
    }

    final tpLocation = buildPainter(locationText, 22);
    final tpCoords = buildPainter(coordText, 18);
    final tpTime = buildPainter(timeText, 16);
    final tpRes = buildPainter(resolutionText, 16);
    final tpSize = buildPainter(sizeTextPlaceholder, 16);

    final totalHeight = tpLocation.height +
        tpCoords.height +
        tpTime.height +
        tpRes.height +
        tpSize.height +
        40;

    final backgroundRect = Rect.fromLTWH(
      padding,
      imageHeight - totalHeight - padding,
      imageWidth - (padding * 2),
      totalHeight,
    );

    // Background box
    canvas.drawRect(
      backgroundRect,
      Paint()..color = Colors.black.withOpacity(0.6),
    );

    double yOffset = backgroundRect.top + 10;

    tpLocation.paint(canvas, Offset(padding + 10, yOffset));
    yOffset += tpLocation.height;

    tpCoords.paint(canvas, Offset(padding + 10, yOffset));
    yOffset += tpCoords.height;

    tpTime.paint(canvas, Offset(padding + 10, yOffset));
    yOffset += tpTime.height;

    tpRes.paint(canvas, Offset(padding + 10, yOffset));
    yOffset += tpRes.height;

    tpSize.paint(canvas, Offset(padding + 10, yOffset));

    // ===== FINAL IMAGE =====
    final picture = recorder.endRecording();
    final finalImage =
        await picture.toImage(originalImage.width, originalImage.height);

    final byteData =
        await finalImage.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    // ✅ NOW compute ACTUAL SIZE
    final finalSizeText =
        "Size: ${_formatFileSize(pngBytes.length)}";

    // ===== REDRAW WITH CORRECT SIZE =====
    final recorder2 = ui.PictureRecorder();
    final canvas2 = Canvas(recorder2);

    canvas2.drawImage(finalImage, Offset.zero, Paint());

    final tpFinalSize = buildPainter(finalSizeText, 16);

    tpFinalSize.paint(
      canvas2,
      Offset(
        padding + 10,
        backgroundRect.bottom - tpFinalSize.height - 10,
      ),
    );

    final picture2 = recorder2.endRecording();
    final finalImage2 =
        await picture2.toImage(originalImage.width, originalImage.height);

    final byteData2 =
        await finalImage2.toByteData(format: ui.ImageByteFormat.png);
    final finalBytes = byteData2!.buffer.asUint8List();

    final dir = await getApplicationDocumentsDirectory();
    final path =
        "${dir.path}/captured_${DateTime.now().millisecondsSinceEpoch}.png";

    final file = File(path);
    await file.writeAsBytes(finalBytes);

    await imageFile.delete();

    return path;
  }
}