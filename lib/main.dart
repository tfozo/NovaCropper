import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:typed_data';
import 'imagecrp.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.photos.request();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Cropper Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  Uint8List? profileImage;
  Uint8List? coverImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Cropper Demo')),
      body: Column(
        children: [
          if (coverImage != null)
            Container(
              height: 500,
              width: 500,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: MemoryImage(coverImage!),
                  fit: BoxFit.fill,
                ),
              ),
            ),
          if (profileImage != null)
            Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: MemoryImage(profileImage!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ElevatedButton(
            onPressed: () => pickAndCropImage(true),
            child: const Text('Pick and Crop Cover Image'),
          ),
          ElevatedButton(
            onPressed: () => pickAndCropImage(false),
            child: const Text('Pick and Crop Profile Image'),
          ),
        ],
      ),
    );
  }

  Future<void> pickAndCropImage(bool isCover) async {
    final status = await Permission.photos.status;
    if (status.isGranted) {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile =
          await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final Uint8List? croppedImage = await Navigator.push<Uint8List>(
          context,
          MaterialPageRoute(
            builder: (context) => ImageCropper(
              imagePath: pickedFile.path,
              aspectRatio: isCover ? 16 / 9 : 1,
            ),
          ),
        );

        if (croppedImage != null) {
          setState(() {
            if (isCover) {
              coverImage = croppedImage;
            } else {
              profileImage = croppedImage;
            }
          });
        }
      }
    } else if (status.isDenied) {
      await Permission.photos.request();
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }
}
