import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:dartcv4/dartcv.dart' as cv;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/student_result.dart';
import '../services/firebase_service.dart';
import '../services/omr_processor.dart';

class MarkerDetectionException implements Exception {
  final String message;

  const MarkerDetectionException(this.message);

  @override
  String toString() {
    return message;
  }
}

class ScannerScreen extends StatefulWidget {
  final String examTitle;

  const ScannerScreen({super.key, required this.examTitle});

  @override
  State<ScannerScreen> createState() {
    return _ScannerScreenState();
  }
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  static const Duration _frameThrottle = Duration(milliseconds: 180);
  static const int _requiredStableFrames = 4;

  final TextEditingController _studentNameController = TextEditingController();

  CameraController? _cameraController;
  Size? _latestFrameSize;
  List<Offset>? _detectedCorners;
  DateTime _lastFrameStartedAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _stableFrameCount = 0;
  bool _isInitializingCamera = true;
  bool _isAnalyzingFrame = false;
  bool _isProcessing = false;
  String? _cameraError;

  bool get _hasReliableCorners {
    return _detectedCorners != null &&
        _stableFrameCount >= _requiredStableFrames;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? controller = _cameraController;

    if (controller == null || controller.value.isInitialized == false) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _disposeCameraController();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _studentNameController.dispose();
    _disposeCameraController();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializingCamera = true;
      _cameraError = null;
    });

    try {
      final List<CameraDescription> cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw const MarkerDetectionException('no Android camera was found');
      }

      final CameraDescription selectedCamera = cameras.firstWhere(
        (CameraDescription camera) {
          return camera.lensDirection == CameraLensDirection.back;
        },
        orElse: () {
          return cameras.first;
        },
      );

      final CameraController controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();

      if (mounted == false) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      await controller.startImageStream(_handleCameraFrame);

      if (mounted == true) {
        setState(() {
          _isInitializingCamera = false;
        });
      }
    } on CameraException catch (error) {
      if (mounted == true) {
        setState(() {
          _isInitializingCamera = false;
          _cameraError = 'camera failed: ${error.description ?? error.code}';
        });
      }
    } catch (error) {
      if (mounted == true) {
        setState(() {
          _isInitializingCamera = false;
          _cameraError = error.toString();
        });
      }
    }
  }

  Future<void> _disposeCameraController() async {
    final CameraController? controller = _cameraController;
    _cameraController = null;

    if (controller == null) {
      return;
    }

    try {
      if (controller.value.isStreamingImages == true) {
        await controller.stopImageStream();
      }
    } catch (_) {
      // The camera may already be closing during Android lifecycle changes.
    }

    await controller.dispose();
  }

  void _handleCameraFrame(CameraImage image) {
    final DateTime now = DateTime.now();

    if (_isAnalyzingFrame == true ||
        now.difference(_lastFrameStartedAt) < _frameThrottle) {
      return;
    }

    _isAnalyzingFrame = true;
    _lastFrameStartedAt = now;

    Future<void>(() async {
      try {
        final _MarkerDetection detection = _MarkerDetector.detect(image);

        if (mounted == true) {
          setState(() {
            _latestFrameSize = Size(
              image.width.toDouble(),
              image.height.toDouble(),
            );
            _detectedCorners = detection.corners;
            _stableFrameCount = math.min(
              _stableFrameCount + 1,
              _requiredStableFrames,
            );
            _cameraError = null;
          });
        }
      } on MarkerDetectionException catch (error) {
        if (mounted == true) {
          setState(() {
            _latestFrameSize = Size(
              image.width.toDouble(),
              image.height.toDouble(),
            );
            _detectedCorners = null;
            _stableFrameCount = 0;
            _cameraError = error.message;
          });
        }
      } catch (error) {
        if (mounted == true) {
          setState(() {
            _detectedCorners = null;
            _stableFrameCount = 0;
            _cameraError = 'marker detection failed: $error';
          });
        }
      } finally {
        _isAnalyzingFrame = false;
      }
    });
  }

  Future<void> _captureAndGrade() async {
    final String studentName = _studentNameController.text.trim();

    if (studentName.isEmpty == true) {
      _showSnackBar('please enter the student name first');
      return;
    }

    final CameraController? controller = _cameraController;

    if (controller == null || controller.value.isInitialized == false) {
      _showSnackBar('camera is not ready yet');
      return;
    }

    if (_hasReliableCorners == false) {
      throw const MarkerDetectionException(
        'cannot capture: four corner markers are not aligned yet',
      );
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      if (controller.value.isStreamingImages == true) {
        await controller.stopImageStream();
      }

      final XFile capturedPhoto = await controller.takePicture();
      final File imageToProcess = File(capturedPhoto.path);
      await _processAndSave(studentName, imageToProcess);

      if (mounted == true) {
        await controller.startImageStream(_handleCameraFrame);
      }
    } on MarkerDetectionException catch (error) {
      _showSnackBar(error.message);
      if (controller.value.isInitialized == true &&
          controller.value.isStreamingImages == false &&
          mounted == true) {
        await controller.startImageStream(_handleCameraFrame);
      }
    } catch (error) {
      _showSnackBar('scan failed: $error');
      if (controller.value.isInitialized == true &&
          controller.value.isStreamingImages == false &&
          mounted == true) {
        await controller.startImageStream(_handleCameraFrame);
      }
    } finally {
      if (mounted == true) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processAndSave(String studentName, File imageToProcess) async {
    final FirebaseService firebaseService = Provider.of<FirebaseService>(
      context,
      listen: false,
    );
    final List<int>? masterKey = await firebaseService.getMasterKey(
      widget.examTitle,
    );

    if (masterKey == null) {
      _showSnackBar('master key not found for this exam');
      return;
    }

    final int totalQuestions = masterKey.length;
    final List<int> studentAnswers = OMRProcessor.processAnswerSheet(
      imageToProcess,
      totalQuestions,
    );
    int score = 0;
    final List<bool> analysis = <bool>[];

    for (
      int questionIndex = 0;
      questionIndex < totalQuestions;
      questionIndex++
    ) {
      if (questionIndex < studentAnswers.length &&
          studentAnswers[questionIndex] == masterKey[questionIndex]) {
        score = score + 1;
        analysis.add(true);
      } else {
        analysis.add(false);
      }
    }

    final StudentResult finalResult = StudentResult(
      id: '',
      studentName: studentName,
      subject: widget.examTitle,
      score: score,
      totalQuestions: totalQuestions,
      studentAnswers: studentAnswers,
      analysis: analysis,
      timestamp: DateTime.now(),
    );

    await firebaseService.saveStudentResult(finalResult);

    if (mounted == true) {
      _showSuccessModal(finalResult);
      _studentNameController.clear();
    }
  }

  void _showSnackBar(String message) {
    if (mounted == false) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccessModal(StudentResult result) {
    final AlertDialog dialog = AlertDialog(
      title: const Text('scan successful'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 64.0),
          const SizedBox(height: 16.0),
          Text(
            result.studentName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
          ),
          const SizedBox(height: 8.0),
          Text(
            'score: ${result.score} / ${result.totalQuestions}',
            style: const TextStyle(fontSize: 24.0, color: Colors.teal),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('scan next'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
          child: const Text('review details'),
        ),
      ],
    );

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return dialog;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? controller = _cameraController;
    final bool cameraReady =
        controller != null &&
        controller.value.isInitialized == true &&
        _isInitializingCamera == false;

    Widget cameraContent;

    if (_cameraError != null && cameraReady == false) {
      cameraContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _cameraError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    } else if (cameraReady == false) {
      cameraContent = const Center(child: CircularProgressIndicator());
    } else {
      cameraContent = Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(controller),
          CustomPaint(
            painter: _MarkerOverlayPainter(
              corners: _detectedCorners,
              frameSize: _latestFrameSize,
              sensorOrientation: controller.description.sensorOrientation,
              isReady: _hasReliableCorners,
            ),
          ),
          Positioned(
            left: 16.0,
            right: 16.0,
            bottom: 16.0,
            child: _ScannerStatusBar(
              message: _hasReliableCorners
                  ? 'markers locked'
                  : (_cameraError ?? 'align the four black corner squares'),
              isReady: _hasReliableCorners,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('scan answer sheet'), centerTitle: true),
      body: Column(
        children: [
          Expanded(child: cameraContent),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _studentNameController,
                  decoration: const InputDecoration(
                    labelText: 'student full name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12.0),
                ElevatedButton.icon(
                  onPressed: _isProcessing == true
                      ? null
                      : () => _captureAndGrade(),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56.0),
                    backgroundColor: _hasReliableCorners
                        ? Colors.teal
                        : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18.0,
                          height: 18.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.document_scanner),
                  label: Text(
                    _isProcessing ? 'processing scan' : 'capture and grade',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkerDetector {
  static const int _analysisWidth = 420;

  static _MarkerDetection detect(CameraImage image) {
    if (image.planes.isEmpty) {
      throw const MarkerDetectionException('camera frame has no image planes');
    }

    final Uint8List luminance = _copyYPlane(image);
    final cv.Mat frame = cv.Mat.fromList(
      image.height,
      image.width,
      cv.MatType.CV_8UC1,
      luminance,
    );
    cv.Mat? resized;
    cv.Mat? binary;
    cv.Contours? contours;
    cv.VecVec4i? hierarchy;

    try {
      final int analysisHeight = (image.height * (_analysisWidth / image.width))
          .round();
      resized = cv.resize(frame, (
        _analysisWidth,
        analysisHeight,
      ), interpolation: cv.INTER_AREA);
      final (double _, cv.Mat thresholded) = cv.threshold(
        resized,
        0,
        255,
        cv.THRESH_BINARY_INV | cv.THRESH_OTSU,
      );
      binary = thresholded;
      final (cv.Contours foundContours, cv.VecVec4i foundHierarchy) = cv
          .findContours(binary, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);
      contours = foundContours;
      hierarchy = foundHierarchy;

      final List<_SquareCandidate> squares = <_SquareCandidate>[];
      final double scaleX = image.width / resized.cols;
      final double scaleY = image.height / resized.rows;
      final double frameArea = resized.cols * resized.rows.toDouble();

      for (final cv.VecPoint contour in contours) {
        final double area = cv.contourArea(contour).abs();

        if (area < frameArea * 0.00045 || area > frameArea * 0.05) {
          continue;
        }

        final double perimeter = cv.arcLength(contour, true);

        if (perimeter <= 0) {
          continue;
        }

        final cv.VecPoint polygon = cv.approxPolyDP(
          contour,
          perimeter * 0.035,
          true,
        );

        try {
          if (polygon.length != 4) {
            continue;
          }

          final cv.Rect bounds = cv.boundingRect(polygon);
          final double aspectRatio = bounds.width / bounds.height;
          final double rectArea = bounds.width * bounds.height.toDouble();
          final double extent = area / rectArea;

          if (aspectRatio < 0.72 ||
              aspectRatio > 1.28 ||
              extent < 0.58 ||
              extent > 1.08) {
            continue;
          }

          final Offset center = Offset(
            (bounds.x + (bounds.width / 2.0)) * scaleX,
            (bounds.y + (bounds.height / 2.0)) * scaleY,
          );

          squares.add(
            _SquareCandidate(center: center, area: area * scaleX * scaleY),
          );
        } finally {
          polygon.dispose();
        }
      }

      if (squares.length < 4) {
        throw MarkerDetectionException(
          'found ${squares.length}/4 corner markers',
        );
      }

      final List<Offset> corners = _selectCornerSquares(
        squares,
        Size(image.width.toDouble(), image.height.toDouble()),
      );

      return _MarkerDetection(corners: corners);
    } finally {
      hierarchy?.dispose();
      contours?.dispose();
      binary?.dispose();
      resized?.dispose();
      frame.dispose();
    }
  }

  static Uint8List _copyYPlane(CameraImage image) {
    final Plane yPlane = image.planes.first;
    final Uint8List source = yPlane.bytes;
    final int bytesPerRow = yPlane.bytesPerRow;
    final Uint8List luminance = Uint8List(image.width * image.height);

    for (int rowIndex = 0; rowIndex < image.height; rowIndex++) {
      final int sourceOffset = rowIndex * bytesPerRow;
      final int targetOffset = rowIndex * image.width;
      luminance.setRange(
        targetOffset,
        targetOffset + image.width,
        source,
        sourceOffset,
      );
    }

    return luminance;
  }

  static List<Offset> _selectCornerSquares(
    List<_SquareCandidate> squares,
    Size frameSize,
  ) {
    final List<_SquareCandidate> candidates =
        List<_SquareCandidate>.from(squares)
          ..sort((_SquareCandidate left, _SquareCandidate right) {
            return right.area.compareTo(left.area);
          });
    final int searchCount = math.min(16, candidates.length);
    final List<_SquareCandidate> largestSquares = candidates
        .take(searchCount)
        .toList();
    final Map<_MarkerCorner, _SquareCandidate> selected =
        <_MarkerCorner, _SquareCandidate>{};

    for (final _MarkerCorner corner in _MarkerCorner.values) {
      _SquareCandidate? bestCandidate;
      double bestDistance = double.infinity;

      for (final _SquareCandidate candidate in largestSquares) {
        final Offset target = switch (corner) {
          _MarkerCorner.topLeft => Offset.zero,
          _MarkerCorner.topRight => Offset(frameSize.width, 0),
          _MarkerCorner.bottomRight => Offset(
            frameSize.width,
            frameSize.height,
          ),
          _MarkerCorner.bottomLeft => Offset(0, frameSize.height),
        };
        final double distance = (candidate.center - target).distance;

        if (distance < bestDistance &&
            selected.values.contains(candidate) == false) {
          bestDistance = distance;
          bestCandidate = candidate;
        }
      }

      if (bestCandidate == null) {
        throw const MarkerDetectionException(
          'could not assign all four corner markers',
        );
      }

      selected[corner] = bestCandidate;
    }

    return <Offset>[
      selected[_MarkerCorner.topLeft]!.center,
      selected[_MarkerCorner.topRight]!.center,
      selected[_MarkerCorner.bottomRight]!.center,
      selected[_MarkerCorner.bottomLeft]!.center,
    ];
  }
}

class _MarkerOverlayPainter extends CustomPainter {
  final List<Offset>? corners;
  final Size? frameSize;
  final int sensorOrientation;
  final bool isReady;

  const _MarkerOverlayPainter({
    required this.corners,
    required this.frameSize,
    required this.sensorOrientation,
    required this.isReady,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final List<Offset>? sourceCorners = corners;
    final Size? sourceFrameSize = frameSize;

    if (sourceCorners == null || sourceFrameSize == null) {
      return;
    }

    final List<Offset> displayCorners = sourceCorners.map((Offset point) {
      return _mapFramePointToCanvas(point, sourceFrameSize, size);
    }).toList();
    final Path path = Path()
      ..moveTo(displayCorners[0].dx, displayCorners[0].dy)
      ..lineTo(displayCorners[1].dx, displayCorners[1].dy)
      ..lineTo(displayCorners[2].dx, displayCorners[2].dy)
      ..lineTo(displayCorners[3].dx, displayCorners[3].dy)
      ..close();
    final Paint fillPaint = Paint()
      ..color = (isReady ? Colors.greenAccent : Colors.orangeAccent).withValues(
        alpha: 0.12,
      )
      ..style = PaintingStyle.fill;
    final Paint strokePaint = Paint()
      ..color = isReady ? Colors.greenAccent : Colors.orangeAccent
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    final Paint markerPaint = Paint()
      ..color = strokePaint.color
      ..style = PaintingStyle.fill;

    for (final Offset corner in displayCorners) {
      canvas.drawCircle(corner, 7.0, markerPaint);
    }
  }

  Offset _mapFramePointToCanvas(
    Offset point,
    Size sourceSize,
    Size canvasSize,
  ) {
    final _RotatedPoint rotatedPoint = _rotateSensorPoint(point, sourceSize);
    final double scale = math.max(
      canvasSize.width / rotatedPoint.size.width,
      canvasSize.height / rotatedPoint.size.height,
    );
    final double displayedWidth = rotatedPoint.size.width * scale;
    final double displayedHeight = rotatedPoint.size.height * scale;
    final double offsetX = (canvasSize.width - displayedWidth) / 2.0;
    final double offsetY = (canvasSize.height - displayedHeight) / 2.0;

    return Offset(
      offsetX + (rotatedPoint.point.dx * scale),
      offsetY + (rotatedPoint.point.dy * scale),
    );
  }

  _RotatedPoint _rotateSensorPoint(Offset point, Size sourceSize) {
    if (sensorOrientation == 90) {
      return _RotatedPoint(
        point: Offset(sourceSize.height - point.dy, point.dx),
        size: Size(sourceSize.height, sourceSize.width),
      );
    }

    if (sensorOrientation == 270) {
      return _RotatedPoint(
        point: Offset(point.dy, sourceSize.width - point.dx),
        size: Size(sourceSize.height, sourceSize.width),
      );
    }

    if (sensorOrientation == 180) {
      return _RotatedPoint(
        point: Offset(
          sourceSize.width - point.dx,
          sourceSize.height - point.dy,
        ),
        size: sourceSize,
      );
    }

    return _RotatedPoint(point: point, size: sourceSize);
  }

  @override
  bool shouldRepaint(covariant _MarkerOverlayPainter oldDelegate) {
    return oldDelegate.corners != corners ||
        oldDelegate.frameSize != frameSize ||
        oldDelegate.sensorOrientation != sensorOrientation ||
        oldDelegate.isReady != isReady;
  }
}

class _ScannerStatusBar extends StatelessWidget {
  final String message;
  final bool isReady;

  const _ScannerStatusBar({required this.message, required this.isReady});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        child: Row(
          children: [
            Icon(
              isReady ? Icons.check_circle : Icons.crop_free,
              color: isReady ? Colors.greenAccent : Colors.white,
              size: 20.0,
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerDetection {
  final List<Offset> corners;

  const _MarkerDetection({required this.corners});
}

class _SquareCandidate {
  final Offset center;
  final double area;

  const _SquareCandidate({required this.center, required this.area});
}

class _RotatedPoint {
  final Offset point;
  final Size size;

  const _RotatedPoint({required this.point, required this.size});
}

enum _MarkerCorner { topLeft, topRight, bottomRight, bottomLeft }
