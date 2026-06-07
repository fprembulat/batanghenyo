import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

class SheetPerspectiveWarper {
  static Future<File> warpCapturedSheet({
    required File capturedFile,
    required List<Offset> cornerPoints,
    required Size frameSize,
    int targetWidth = 1000,
    int targetHeight = 1400,
  }) async {
    if (cornerPoints.length != 4) {
      return capturedFile;
    }

    if (frameSize.width <= 0 || frameSize.height <= 0) {
      return capturedFile;
    }

    final List<int> bytes = await capturedFile.readAsBytes();
    final img.Image? sourceImage = img.decodeImage(Uint8List.fromList(bytes));
    if (sourceImage == null) {
      return capturedFile;
    }

    final double scaleX = sourceImage.width / frameSize.width;
    final double scaleY = sourceImage.height / frameSize.height;

    final List<_Point> sourcePoints = <_Point>[
      _Point(cornerPoints[0].dx * scaleX, cornerPoints[0].dy * scaleY),
      _Point(cornerPoints[1].dx * scaleX, cornerPoints[1].dy * scaleY),
      _Point(cornerPoints[2].dx * scaleX, cornerPoints[2].dy * scaleY),
      _Point(cornerPoints[3].dx * scaleX, cornerPoints[3].dy * scaleY),
    ];

    final List<_Point> destinationPoints = <_Point>[
      _Point(0.0, 0.0),
      _Point((targetWidth - 1).toDouble(), 0.0),
      _Point((targetWidth - 1).toDouble(), (targetHeight - 1).toDouble()),
      _Point(0.0, (targetHeight - 1).toDouble()),
    ];

    final _Homography homography = _Homography.fromQuadToQuad(
      destinationPoints,
      sourcePoints,
    );

    final img.Image warped = img.Image(width: targetWidth, height: targetHeight);

    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        final _Point mapped = homography.mapPoint(x.toDouble(), y.toDouble());

        if (mapped.x.isNaN || mapped.y.isNaN) {
          warped.setPixel(x, y, img.ColorRgb8(255, 255, 255));
          continue;
        }

        final img.ColorRgb8? sampled = _sampleBilinear(
          sourceImage,
          mapped.x,
          mapped.y,
        );

        if (sampled == null) {
          warped.setPixel(x, y, img.ColorRgb8(255, 255, 255));
        } else {
          warped.setPixel(x, y, sampled);
        }
      }
    }

    final String fileName = capturedFile.path.split(Platform.pathSeparator).last;
    final int dotIndex = fileName.lastIndexOf('.');
    final String stem = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    final File outputFile = File(
      '${Directory.systemTemp.path}/${stem}_warped.png',
    );

    await outputFile.writeAsBytes(img.encodePng(warped));
    return outputFile;
  }

  static img.ColorRgb8? _sampleBilinear(
    img.Image sourceImage,
    double x,
    double y,
  ) {
    if (x < 0 || y < 0) {
      return null;
    }

    if (x >= sourceImage.width - 1 || y >= sourceImage.height - 1) {
      return null;
    }

    final int x0 = x.floor();
    final int y0 = y.floor();
    final int x1 = x0 + 1;
    final int y1 = y0 + 1;

    final double tx = x - x0;
    final double ty = y - y0;

    final img.Pixel p00 = sourceImage.getPixel(x0, y0);
    final img.Pixel p10 = sourceImage.getPixel(x1, y0);
    final img.Pixel p01 = sourceImage.getPixel(x0, y1);
    final img.Pixel p11 = sourceImage.getPixel(x1, y1);

    final double r0 = _lerp(p00.r.toDouble(), p10.r.toDouble(), tx);
    final double g0 = _lerp(p00.g.toDouble(), p10.g.toDouble(), tx);
    final double b0 = _lerp(p00.b.toDouble(), p10.b.toDouble(), tx);

    final double r1 = _lerp(p01.r.toDouble(), p11.r.toDouble(), tx);
    final double g1 = _lerp(p01.g.toDouble(), p11.g.toDouble(), tx);
    final double b1 = _lerp(p01.b.toDouble(), p11.b.toDouble(), tx);

    final int red = _clampByte(_lerp(r0, r1, ty));
    final int green = _clampByte(_lerp(g0, g1, ty));
    final int blue = _clampByte(_lerp(b0, b1, ty));

    return img.ColorRgb8(red, green, blue);
  }

  static double _lerp(double a, double b, double t) {
    return a + ((b - a) * t);
  }

  static int _clampByte(double value) {
    return value.round().clamp(0, 255);
  }
}

class _Point {
  final double x;
  final double y;

  const _Point(this.x, this.y);
}

class _Homography {
  final List<double> values;

  const _Homography(this.values);

  factory _Homography.fromQuadToQuad(
    List<_Point> source,
    List<_Point> destination,
  ) {
    final List<List<double>> matrix = <List<double>>[];
    final List<double> vector = <double>[];

    for (int i = 0; i < 4; i++) {
      final double x = source[i].x;
      final double y = source[i].y;
      final double xTarget = destination[i].x;
      final double yTarget = destination[i].y;

      matrix.add(<double>[x, y, 1.0, 0.0, 0.0, 0.0, -x * xTarget, -y * xTarget]);
      vector.add(xTarget);

      matrix.add(<double>[0.0, 0.0, 0.0, x, y, 1.0, -x * yTarget, -y * yTarget]);
      vector.add(yTarget);
    }

    final List<double> solution = _solveLinearSystem(matrix, vector);

    return _Homography(<double>[
      solution[0],
      solution[1],
      solution[2],
      solution[3],
      solution[4],
      solution[5],
      solution[6],
      solution[7],
      1.0,
    ]);
  }

  _Point mapPoint(double x, double y) {
    final double denominator = (values[6] * x) + (values[7] * y) + values[8];
    if (denominator.abs() < 1e-10) {
      return const _Point(double.nan, double.nan);
    }

    final double mappedX =
        ((values[0] * x) + (values[1] * y) + values[2]) / denominator;
    final double mappedY =
        ((values[3] * x) + (values[4] * y) + values[5]) / denominator;

    return _Point(mappedX, mappedY);
  }
}

List<double> _solveLinearSystem(List<List<double>> a, List<double> b) {
  final int size = b.length;
  final List<List<double>> augmented = List<List<double>>.generate(
    size,
    (int rowIndex) => <double>[...a[rowIndex], b[rowIndex]],
  );

  for (int pivotIndex = 0; pivotIndex < size; pivotIndex++) {
    int bestRow = pivotIndex;
    double bestValue = augmented[pivotIndex][pivotIndex].abs();

    for (int rowIndex = pivotIndex + 1; rowIndex < size; rowIndex++) {
      final double candidateValue = augmented[rowIndex][pivotIndex].abs();
      if (candidateValue > bestValue) {
        bestValue = candidateValue;
        bestRow = rowIndex;
      }
    }

    if (bestRow != pivotIndex) {
      final List<double> temp = augmented[pivotIndex];
      augmented[pivotIndex] = augmented[bestRow];
      augmented[bestRow] = temp;
    }

    final double pivot = augmented[pivotIndex][pivotIndex];
    if (pivot.abs() < 1e-12) {
      throw StateError('unable to solve perspective transform');
    }

    for (int colIndex = pivotIndex; colIndex <= size; colIndex++) {
      augmented[pivotIndex][colIndex] =
          augmented[pivotIndex][colIndex] / pivot;
    }

    for (int rowIndex = 0; rowIndex < size; rowIndex++) {
      if (rowIndex == pivotIndex) {
        continue;
      }

      final double factor = augmented[rowIndex][pivotIndex];
      for (int colIndex = pivotIndex; colIndex <= size; colIndex++) {
        augmented[rowIndex][colIndex] =
            augmented[rowIndex][colIndex] -
            (factor * augmented[pivotIndex][colIndex]);
      }
    }
  }

  final List<double> solution = <double>[];
  for (int rowIndex = 0; rowIndex < size; rowIndex++) {
    solution.add(augmented[rowIndex][size]);
  }
  return solution;
}