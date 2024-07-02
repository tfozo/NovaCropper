import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:image/image.dart' as img;

class ImageCropper extends StatefulWidget {
  final String imagePath;
  final double aspectRatio;

  const ImageCropper(
      {super.key, required this.imagePath, this.aspectRatio = 1.0});

  @override
  _ImageCropperState createState() => _ImageCropperState();
}

class _ImageCropperState extends State<ImageCropper> {
  ui.Image? image;
  Rect? cropRect;
  Offset? _startingFocalPoint;
  Size? _imageSize;
  Rect? _imageRect;
  bool isDragging = false;
  bool isResizing = false;
  String? resizeHandle;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final File file = File(widget.imagePath);
    final Uint8List bytes = await file.readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo fi = await codec.getNextFrame();
    setState(() {
      image = fi.image;
      _imageSize = Size(image!.width.toDouble(), image!.height.toDouble());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom Image Cropper')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: image == null
                  ? const CircularProgressIndicator()
                  : GestureDetector(
                      onPanStart: _handlePanStart,
                      onPanUpdate: _handlePanUpdate,
                      onPanEnd: _handlePanEnd,
                      child: CustomPaint(
                        painter: _CropPainter(
                          image: image!,
                          cropRect: cropRect,
                          updateImageRect: (Rect rect) {
                            _imageRect = rect;
                          },
                          aspectRatio: widget.aspectRatio,
                        ),
                        size: Size.infinite,
                      ),
                    ),
            ),
          ),
          ElevatedButton(
            onPressed: () => _cropImage(context),
            child: const Text('Crop Image'),
          ),
        ],
      ),
    );
  }

  void _handlePanStart(DragStartDetails details) {
    _startingFocalPoint = details.localPosition;

    if (cropRect == null) {
      setState(() {
        cropRect = Rect.fromPoints(_startingFocalPoint!, _startingFocalPoint!);
      });
    } else {
      resizeHandle = _detectResizeHandle(details.localPosition);
      if (resizeHandle != null) {
        isResizing = true;
      } else if (_isInsideCropRect(details.localPosition)) {
        isDragging = true;
      }
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      if (isDragging) {
        final Offset delta = details.delta;
        cropRect = cropRect!.shift(delta);
      } else if (isResizing) {
        _resizeCropRect(details.localPosition);
      } else {
        cropRect = Rect.fromPoints(_startingFocalPoint!, details.localPosition);
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    isDragging = false;
    isResizing = false;
    resizeHandle = null;

    if (_imageRect == null || cropRect == null) return;

    setState(() {
      Rect normalizedRect = Rect.fromPoints(
        Offset(
            cropRect!.left < cropRect!.right ? cropRect!.left : cropRect!.right,
            cropRect!.top < cropRect!.bottom
                ? cropRect!.top
                : cropRect!.bottom),
        Offset(
            cropRect!.left > cropRect!.right ? cropRect!.left : cropRect!.right,
            cropRect!.top > cropRect!.bottom
                ? cropRect!.top
                : cropRect!.bottom),
      );

      cropRect = Rect.fromLTRB(
        normalizedRect.left.clamp(_imageRect!.left, _imageRect!.right),
        normalizedRect.top.clamp(_imageRect!.top, _imageRect!.bottom),
        normalizedRect.right.clamp(_imageRect!.left, _imageRect!.right),
        normalizedRect.bottom.clamp(_imageRect!.top, _imageRect!.bottom),
      );
    });
  }

  bool _isInsideCropRect(Offset point) {
    return cropRect != null && cropRect!.contains(point);
  }

  String? _detectResizeHandle(Offset point) {
    const double handleSize = 20.0;
    final handles = {
      'topLeft': cropRect!.topLeft,
      'topRight': cropRect!.topRight,
      'bottomLeft': cropRect!.bottomLeft,
      'bottomRight': cropRect!.bottomRight,
      'centerLeft': cropRect!.centerLeft,
      'centerRight': cropRect!.centerRight,
      'topCenter': cropRect!.topCenter,
      'bottomCenter': cropRect!.bottomCenter,
    };

    for (var handle in handles.entries) {
      if ((handle.value - point).distance <= handleSize) {
        return handle.key;
      }
    }
    return null;
  }

  void _resizeCropRect(Offset point) {
    setState(() {
      switch (resizeHandle) {
        case 'topLeft':
          cropRect = Rect.fromLTRB(
              point.dx, point.dy, cropRect!.right, cropRect!.bottom);
          break;
        case 'topRight':
          cropRect = Rect.fromLTRB(
              cropRect!.left, point.dy, point.dx, cropRect!.bottom);
          break;
        case 'bottomLeft':
          cropRect =
              Rect.fromLTRB(point.dx, cropRect!.top, cropRect!.right, point.dy);
          break;
        case 'bottomRight':
          cropRect =
              Rect.fromLTRB(cropRect!.left, cropRect!.top, point.dx, point.dy);
          break;
        case 'centerLeft':
          cropRect = Rect.fromLTRB(
              point.dx, cropRect!.top, cropRect!.right, cropRect!.bottom);
          break;
        case 'centerRight':
          cropRect = Rect.fromLTRB(
              cropRect!.left, cropRect!.top, point.dx, cropRect!.bottom);
          break;
        case 'topCenter':
          cropRect = Rect.fromLTRB(
              cropRect!.left, point.dy, cropRect!.right, cropRect!.bottom);
          break;
        case 'bottomCenter':
          cropRect = Rect.fromLTRB(
              cropRect!.left, cropRect!.top, cropRect!.right, point.dy);
          break;
      }
    });
  }

  void _cropImage(BuildContext context) async {
    if (cropRect != null && _imageRect != null) {
      final double scaleX = _imageSize!.width / _imageRect!.width;
      final double scaleY = _imageSize!.height / _imageRect!.height;

      final Rect scaledCropRect = Rect.fromLTRB(
        (cropRect!.left - _imageRect!.left) * scaleX,
        (cropRect!.top - _imageRect!.top) * scaleY,
        (cropRect!.right - _imageRect!.left) * scaleX,
        (cropRect!.bottom - _imageRect!.top) * scaleY,
      );

      final File file = File(widget.imagePath);
      final Uint8List bytes = await file.readAsBytes();
      final img.Image? originalImage = img.decodeImage(bytes);

      if (originalImage != null) {
        final img.Image croppedImage = img.copyCrop(
          originalImage,
          x: scaledCropRect.left.round(),
          y: scaledCropRect.top.round(),
          width: scaledCropRect.width.round(),
          height: scaledCropRect.height.round(),
        );

        final Uint8List croppedBytes =
            Uint8List.fromList(img.encodePng(croppedImage));

        Navigator.pop(context, croppedBytes);
      }
    }
  }
}

class _CropPainter extends CustomPainter {
  final ui.Image image;
  final Rect? cropRect;
  final Function(Rect) updateImageRect;
  final double aspectRatio;

  _CropPainter({
    required this.image,
    this.cropRect,
    required this.updateImageRect,
    required this.aspectRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final fittedSize = applyBoxFit(BoxFit.contain, imageSize, size);
    final src = Alignment.center.inscribe(imageSize, Offset.zero & imageSize);
    final dst =
        Alignment.center.inscribe(fittedSize.destination, Offset.zero & size);

    canvas.drawImageRect(image, src, dst, paint);

    updateImageRect(dst);

    Rect cropRect = this.cropRect ?? _getInitialCropRect(dst);

    _drawOverlay(canvas, size, cropRect);

    _drawGrid(canvas, cropRect);

    final cropPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 2.0;
    canvas.drawRect(cropRect, cropPaint);

    // Draw drag handles
    _drawHandles(canvas, cropRect);
  }

  void _drawOverlay(Canvas canvas, Size size, Rect cropRect) {
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.5);

    canvas.drawRect(
        Rect.fromLTRB(0, 0, size.width, cropRect.top), overlayPaint);
    canvas.drawRect(Rect.fromLTRB(0, cropRect.bottom, size.width, size.height),
        overlayPaint);
    canvas.drawRect(
        Rect.fromLTRB(0, cropRect.top, cropRect.left, cropRect.bottom),
        overlayPaint);
    canvas.drawRect(
        Rect.fromLTRB(
            cropRect.right, cropRect.top, size.width, cropRect.bottom),
        overlayPaint);
  }

  void _drawGrid(Canvas canvas, Rect rect) {
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.0;

    const int gridSize = 3; // 3x3 grid

    for (int i = 1; i < gridSize; i++) {
      final dx = rect.left + (rect.width / gridSize) * i;
      final dy = rect.top + (rect.height / gridSize) * i;
      canvas.drawLine(Offset(dx, rect.top), Offset(dx, rect.bottom), gridPaint);
      canvas.drawLine(Offset(rect.left, dy), Offset(rect.right, dy), gridPaint);
    }
  }

  void _drawHandles(Canvas canvas, Rect rect) {
    const handleSize = 10.0;
    final handlePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    final handles = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
      rect.centerLeft,
      rect.centerRight,
      rect.topCenter,
      rect.bottomCenter,
    ];

    for (var handle in handles) {
      canvas.drawRect(
        Rect.fromCenter(center: handle, width: handleSize, height: handleSize),
        handlePaint,
      );
    }
  }

  Rect _getInitialCropRect(Rect imageRect) {
    final double imageAspectRatio = imageRect.width / imageRect.height;
    double rectWidth, rectHeight;
    if (imageAspectRatio > aspectRatio) {
      rectHeight = imageRect.height * 0.8;
      rectWidth = rectHeight * aspectRatio;
    } else {
      rectWidth = imageRect.width * 0.8;
      rectHeight = rectWidth / aspectRatio;
    }
    final rectLeft = imageRect.left + (imageRect.width - rectWidth) / 2;
    final rectTop = imageRect.top + (imageRect.height - rectHeight) / 2;
    return Rect.fromLTWH(rectLeft, rectTop, rectWidth, rectHeight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
