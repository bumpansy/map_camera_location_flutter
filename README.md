# map_camera_flutter

A Flutter package that provides a widget for capturing high-quality images with the device camera and overlaying location information as readable text.
<br>

<img src="https://raw.githubusercontent.com/Always-Bijoy/map_camera_location_flutter/main/assets/Screenshot_2.png" alt="Interface preview" width="400">

## Features

- **High-quality image capture** using the device camera (no screenshots)
- **Real-time location tracking** with GPS coordinates and address information
- **Text overlay** with location data, coordinates, and timestamp
- **Fast processing** - captures and processes images in under 1 second
- **Clean UI** with minimal overlay elements for better image quality
- **Automatic location updates** every second

## Getting Started

To use this package, add `map_camera_flutter` as a dependency in your `pubspec.yaml` file.

```yaml
dependencies:
  map_camera_flutter: ^1.0.0
```

### Usage

Import the package in your Dart file:

```dart
import 'package:map_camera_flutter/map_camera_flutter.dart';
```

## Permissions

Before using the package, make sure to add the necessary location permission to your AndroidManifest.xml file.

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

## Usage

The `MapCameraLocation` widget is used to capture high-quality images with location data overlay. It requires a `CameraDescription` object and an optional callback function for receiving the captured image and location data.

```dart
MapCameraLocation(
  camera: yourCameraDescription,
  onImageCaptured: yourCallbackFunction,
)
```

The `camera` parameter is required and represents the camera to be used for capturing images. You can obtain a `CameraDescription` object using the `camera` package or any other camera plugin.

The `onImageCaptured` parameter is an optional callback function that will be triggered when an image and location data are captured. The function should have the following signature:

```dart
void yourCallbackFunction(ImageAndLocationData data) {
  // Handle the captured image and location data
}
```

The `ImageAndLocationData` object contains the captured image file path and the location information (latitude, longitude, location name, and sublocation).

## How It Works

1. **Camera Preview**: Displays a live camera feed with minimal UI overlays
2. **Location Tracking**: Continuously updates GPS coordinates and address information
3. **Image Capture**: Takes a high-quality photo using the camera's native resolution
4. **Text Overlay**: Adds location data, coordinates, and timestamp as readable text
5. **Fast Processing**: Optimized image processing for quick results

## Example

Here's an example of how to use the `MapCameraLocation` widget:

```dart
import 'package:flutter/material.dart';
import 'package:map_camera_flutter/map_camera_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;
  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;
  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('High-Quality Camera with Location'),
        ),
        body: Center(
          child: MapCameraLocation(
            camera: camera,
            onImageCaptured: (ImageAndLocationData data) {
              // Handle the captured image and location data
              print('Image Path: ${data.imagePath}');
              print('Latitude: ${data.latitude}');
              print('Longitude: ${data.longitude}');
              print('Location Name: ${data.locationName}');
              print('SubLocation: ${data.subLocation}');
            },
          ),
        ),
      ),
    );
  }
}
```

## Image Quality

This package is specifically designed for applications that require high-quality images with readable text, such as:
- Document scanning and OCR applications
- Field inspection and survey tools
- Real estate and property documentation
- Travel and tourism photo apps
- Any application where text readability is crucial

## Performance

- **Capture Speed**: Images are captured and processed in under 1 second
- **Memory Efficient**: Optimized image processing with minimal memory usage
- **Battery Friendly**: Efficient location updates and camera management

## Issues and Contributions

If you encounter any issues or have suggestions for improvements, please file an issue on the GitHub repository.

Pull requests are also welcome! If you would like to contribute to this package, feel free to open a pull request with your proposed changes.

## License

This package is released under the MIT License. See the LICENSE file for more details.
