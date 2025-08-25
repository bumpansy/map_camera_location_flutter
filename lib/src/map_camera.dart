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

// Callback function type for capturing image and location data
typedef ImageAndLocationCallback = void Function(ImageAndLocationData data);

class MapCameraLocation extends StatefulWidget {
  final CameraDescription camera;
  final ImageAndLocationCallback? onImageCaptured;

  /// Constructs a MapCameraLocation widget.
  ///
  /// The [camera] parameter is required and represents the camera to be used for capturing images.
  /// The [onImageCaptured] parameter is an optional callback function that will be triggered when an image and location data are captured.
  const MapCameraLocation({
    super.key, 
    required this.camera, 
    this.onImageCaptured
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
  bool _isCapturing = false;

  Timer? _positionTimer;

  @override
  void initState() {
    super.initState();
    
    // Initialize location updates
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (mounted) {
        await updatePosition(context);
      }
    });

    // Initialize the camera controller with high quality
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high, // Use high resolution for better quality
      enableAudio: false, // Disable audio for faster processing
    );
    _initializeControllerFuture = _controller.initialize();

    // Get the current date and time in a formatted string
    dateTime = DateFormat.yMd().add_jm().format(DateTime.now());
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
            return Center(
              child: Stack(
                children: [
                  // Camera preview
                  CameraPreview(_controller),
                  
                  // Location info overlay (top right)
                  Positioned(
                    top: 40,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locationData?.locationName ?? "Loading...",
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 14, 
                              fontWeight: FontWeight.bold
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Lat: ${locationData?.latitude ?? "..."}",
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 12
                            ),
                          ),
                          Text(
                            "Long: ${locationData?.longitude ?? "..."}",
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 12
                            ),
                          ),
                          Text(
                            dateTime ?? "",
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 12
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Capture button overlay
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
                            border: Border.all(color: Colors.black, width: 3),
                          ),
                          child: _isCapturing
                              ? const Center(
                                  child: SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  size: 40,
                                  color: Colors.black,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  /// Captures a high-quality image and overlays location data
  Future<void> _captureImage() async {
    if (_isCapturing) return;
    
    setState(() {
      _isCapturing = true;
    });

    try {
      // Capture the image
      final XFile image = await _controller.takePicture();
      
      if (image.path.isNotEmpty) {
        // Process the image with location overlay
        final String processedImagePath = await _addLocationOverlay(image.path);
        
        // Update state
        setState(() {
          cameraImagePath = File(processedImagePath);
        });

        // Trigger callback
        if (widget.onImageCaptured != null) {
          final ImageAndLocationData data = ImageAndLocationData(
            imagePath: processedImagePath,
            locationData: locationData,
          );
          widget.onImageCaptured!(data);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error capturing image: $e');
      }
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  /// Adds location data overlay to the captured image
  Future<String> _addLocationOverlay(String imagePath) async {
    try {
      // Read the original image
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      // Decode the image
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image originalImage = frameInfo.image;
      
      // Create a canvas to draw the overlay
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      
      // Draw the original image
      canvas.drawImage(originalImage, Offset.zero, Paint());
      
      // Prepare location text
      final String locationText = locationData?.locationName ?? "Location unavailable";
      final String coordinatesText = "Lat: ${locationData?.latitude ?? "N/A"}, Long: ${locationData?.longitude ?? "N/A"}";
      final String timeText = dateTime ?? DateFormat.yMd().add_jm().format(DateTime.now());
      
      // Create text painter for location
      final TextPainter locationPainter = TextPainter(
        text: TextSpan(
          text: locationText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: Offset(2, 2),
                blurRadius: 4,
                color: Colors.black,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      );
      locationPainter.layout();
      
      // Create text painter for coordinates
      final TextPainter coordinatesPainter = TextPainter(
        text: TextSpan(
          text: coordinatesText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            shadows: [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 2,
                color: Colors.black,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      coordinatesPainter.layout();
      
      // Create text painter for time
      final TextPainter timePainter = TextPainter(
        text: TextSpan(
          text: timeText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            shadows: [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 2,
                color: Colors.black,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      timePainter.layout();
      
      // Calculate positions (bottom left with padding)
      final double padding = 20;
      final double imageHeight = originalImage.height.toDouble();
      final double imageWidth = originalImage.width.toDouble();
      
      // Draw semi-transparent background for text
      final Rect backgroundRect = Rect.fromLTWH(
        padding,
        imageHeight - padding - locationPainter.height - coordinatesPainter.height - timePainter.height - 20,
        imageWidth - (padding * 2),
        locationPainter.height + coordinatesPainter.height + timePainter.height + 20,
      );
      
      canvas.drawRect(
        backgroundRect,
        Paint()..color = Colors.black.withValues(alpha: 0.6),
      );
      
      // Draw location text
      locationPainter.paint(
        canvas,
        Offset(padding + 10, imageHeight - padding - locationPainter.height - coordinatesPainter.height - timePainter.height - 15),
      );
      
      // Draw coordinates text
      coordinatesPainter.paint(
        canvas,
        Offset(padding + 10, imageHeight - padding - coordinatesPainter.height - timePainter.height - 10),
      );
      
      // Draw time text
      timePainter.paint(
        canvas,
        Offset(padding + 10, imageHeight - padding - timePainter.height - 5),
      );
      
      // Convert to image
      final ui.Picture picture = recorder.endRecording();
      final ui.Image finalImage = await picture.toImage(
        originalImage.width,
        originalImage.height,
      );
      
      // Convert to bytes
      final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();
      
      // Save to new file
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = 'captured_${DateTime.now().millisecondsSinceEpoch}.png';
      final String newPath = '${appDir.path}/$fileName';
      
      final File newFile = File(newPath);
      await newFile.writeAsBytes(pngBytes);
      
      // Clean up original file
      await imageFile.delete();
      
      return newPath;
    } catch (e) {
      if (kDebugMode) {
        print('Error adding overlay: $e');
      }
      // Return original path if overlay fails
      return imagePath;
    }
  }

  /// Updates the current position by retrieving location information
  Future<void> updatePosition(BuildContext context) async {
    try {
      final position = await _determinePosition();
      final placeMarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      LocationData newLocationData;
      if (placeMarks.isNotEmpty) {
        final placeMark = placeMarks.first;
        newLocationData = LocationData(
          latitude: position.latitude.toString(),
          longitude: position.longitude.toString(),
          locationName: "${placeMark.locality ?? ""}, ${placeMark.administrativeArea ?? ""}, ${placeMark.country ?? ""}",
          subLocation: "${placeMark.street ?? ""}, ${placeMark.thoroughfare ?? ""} ${placeMark.administrativeArea ?? ""}",
        );
      } else {
        newLocationData = LocationData(
          longitude: null,
          latitude: null,
          locationName: 'No Location Data',
          subLocation: "",
        );
      }

      if (newLocationData != locationData) {
        setState(() {
          locationData = newLocationData;
        });
      }

      if (kDebugMode) {
        print("Latitude: ${locationData?.latitude}, Longitude: ${locationData?.longitude}, Location: ${locationData?.locationName}");
      }
    } catch (e) {
      setState(() {
        locationData = LocationData(
          longitude: null,
          latitude: null,
          locationName: 'Error Retrieving Location',
          subLocation: "",
        );
      });
    }
  }

  /// Determines the current position using the GeoLocator package
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }
}
