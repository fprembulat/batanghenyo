import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class OMRProcessor {
  static const int _targetWidth = 1000;
  static const int _itemsPerColumn = 20;
  static const int _choicesPerQuestion = 5;
  static const int _columns = 3;

  static List<int> processAnswerSheet(File imageFile, int totalQuestions) {
    final List<int> bytes = imageFile.readAsBytesSync();
    final img.Image? originalImage = img.decodeImage(Uint8List.fromList(bytes));

    if (originalImage == null) {
      return <int>[];
    }

    return processImage(originalImage, totalQuestions);
  }

  static List<int> processImage(img.Image originalImage, int totalQuestions) {
    if (totalQuestions <= 0) {
      return <int>[];
    }

    final img.Image grayscale = img.grayscale(originalImage);
    final img.Image scaledImage = img.copyResize(
      grayscale,
      width: _targetWidth,
    );
    final int width = scaledImage.width;
    final int height = scaledImage.height;
    final List<int> luminance = _readLuminance(scaledImage);
    final int otsuThreshold = _calculateOtsuThreshold(luminance);
    final int componentThreshold = otsuThreshold.clamp(90, 185).toInt();
    final Uint8List darkMask = _buildDarkMask(luminance, componentThreshold);
    final List<_BubbleCandidate> candidates = _findBubbleCandidates(
      darkMask,
      width,
      height,
    );
    final _DetectedGrid? grid = _detectGrid(candidates, totalQuestions);

    if (grid == null) {
      return List<int>.filled(totalQuestions, -1);
    }

    final List<int> detectedAnswers = List<int>.filled(totalQuestions, -1);

    for (int rowIndex = 0; rowIndex < grid.rows.length; rowIndex++) {
      final _BubbleRow row = grid.rows[rowIndex];

      for (int colIndex = 0; colIndex < _columns; colIndex++) {
        final int questionIndex = (colIndex * _itemsPerColumn) + rowIndex;

        if (questionIndex >= totalQuestions || colIndex >= row.groups.length) {
          continue;
        }

        final _BubbleGroup group = row.groups[colIndex];
        final List<double> scores = <double>[];

        for (final _BubbleCandidate bubble in group.bubbles) {
          scores.add(_scoreBubbleCore(luminance, width, height, bubble));
        }

        detectedAnswers[questionIndex] = _selectMarkedChoice(scores);
      }
    }

    return detectedAnswers;
  }

  static List<int> _readLuminance(img.Image image) {
    final List<int> luminance = List<int>.filled(
      image.width * image.height,
      255,
    );

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final img.Pixel pixel = image.getPixel(x, y);
        luminance[(y * image.width) + x] = pixel.r.toInt();
      }
    }

    return luminance;
  }

  static int _calculateOtsuThreshold(List<int> luminance) {
    final List<int> histogram = List<int>.filled(256, 0);

    for (final int value in luminance) {
      histogram[value] = histogram[value] + 1;
    }

    final int totalPixels = luminance.length;
    int totalSum = 0;

    for (int i = 0; i < histogram.length; i++) {
      totalSum = totalSum + (i * histogram[i]);
    }

    int backgroundWeight = 0;
    int backgroundSum = 0;
    double bestVariance = -1.0;
    int bestThreshold = 150;

    for (int threshold = 0; threshold < histogram.length; threshold++) {
      backgroundWeight = backgroundWeight + histogram[threshold];

      if (backgroundWeight == 0) {
        continue;
      }

      final int foregroundWeight = totalPixels - backgroundWeight;

      if (foregroundWeight == 0) {
        break;
      }

      backgroundSum = backgroundSum + (threshold * histogram[threshold]);

      final double backgroundMean = backgroundSum / backgroundWeight;
      final double foregroundMean =
          (totalSum - backgroundSum) / foregroundWeight;
      final double meanDifference = backgroundMean - foregroundMean;
      final double betweenClassVariance =
          backgroundWeight * foregroundWeight * meanDifference * meanDifference;

      if (betweenClassVariance > bestVariance) {
        bestVariance = betweenClassVariance;
        bestThreshold = threshold;
      }
    }

    return bestThreshold;
  }

  static Uint8List _buildDarkMask(List<int> luminance, int threshold) {
    final Uint8List mask = Uint8List(luminance.length);

    for (int i = 0; i < luminance.length; i++) {
      if (luminance[i] <= threshold) {
        mask[i] = 1;
      }
    }

    return mask;
  }

  static List<_BubbleCandidate> _findBubbleCandidates(
    Uint8List darkMask,
    int width,
    int height,
  ) {
    final Uint8List visited = Uint8List(darkMask.length);
    final List<_BubbleCandidate> candidates = <_BubbleCandidate>[];
    final Queue<int> queue = Queue<int>();
    final int minSize = max(6, (width * 0.006).round());
    final int maxSize = max(32, (width * 0.05).round());
    final int minArea = max(14, (width * 0.00002).round());
    final int maxArea = max(600, (width * 0.0025).round());

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int startIndex = (y * width) + x;

        if (darkMask[startIndex] == 0 || visited[startIndex] == 1) {
          continue;
        }

        visited[startIndex] = 1;
        queue.add(startIndex);

        int minX = x;
        int maxX = x;
        int minY = y;
        int maxY = y;
        int area = 0;

        while (queue.isNotEmpty) {
          final int currentIndex = queue.removeFirst();
          final int currentX = currentIndex % width;
          final int currentY = currentIndex ~/ width;
          area = area + 1;

          if (currentX < minX) {
            minX = currentX;
          }
          if (currentX > maxX) {
            maxX = currentX;
          }
          if (currentY < minY) {
            minY = currentY;
          }
          if (currentY > maxY) {
            maxY = currentY;
          }

          _enqueueDarkNeighbor(
            currentX - 1,
            currentY,
            width,
            height,
            darkMask,
            visited,
            queue,
          );
          _enqueueDarkNeighbor(
            currentX + 1,
            currentY,
            width,
            height,
            darkMask,
            visited,
            queue,
          );
          _enqueueDarkNeighbor(
            currentX,
            currentY - 1,
            width,
            height,
            darkMask,
            visited,
            queue,
          );
          _enqueueDarkNeighbor(
            currentX,
            currentY + 1,
            width,
            height,
            darkMask,
            visited,
            queue,
          );
        }

        final int componentWidth = maxX - minX + 1;
        final int componentHeight = maxY - minY + 1;
        final double aspectRatio = componentWidth / componentHeight;
        final double fillRatio = area / (componentWidth * componentHeight);
        final bool hasBubbleSize =
            componentWidth >= minSize &&
            componentHeight >= minSize &&
            componentWidth <= maxSize &&
            componentHeight <= maxSize;
        final bool hasBubbleShape = aspectRatio >= 0.6 && aspectRatio <= 1.6;
        final bool hasBubbleArea =
            area >= minArea && area <= maxArea && fillRatio >= 0.08;

        if (hasBubbleSize && hasBubbleShape && hasBubbleArea) {
          candidates.add(
            _BubbleCandidate(
              centerX: (minX + maxX) / 2.0,
              centerY: (minY + maxY) / 2.0,
              diameter: (componentWidth + componentHeight) / 2.0,
            ),
          );
        }
      }
    }

    return candidates;
  }

  static void _enqueueDarkNeighbor(
    int x,
    int y,
    int width,
    int height,
    Uint8List darkMask,
    Uint8List visited,
    Queue<int> queue,
  ) {
    if (x < 0 || y < 0 || x >= width || y >= height) {
      return;
    }

    final int index = (y * width) + x;

    if (darkMask[index] == 0 || visited[index] == 1) {
      return;
    }

    visited[index] = 1;
    queue.add(index);
  }

  static _DetectedGrid? _detectGrid(
    List<_BubbleCandidate> candidates,
    int totalQuestions,
  ) {
    if (candidates.length < _choicesPerQuestion) {
      return null;
    }

    final List<double> diameters = candidates.map((_BubbleCandidate candidate) {
      return candidate.diameter;
    }).toList()..sort();
    final double medianDiameter = diameters[diameters.length ~/ 2];
    final double yTolerance = max(7.0, medianDiameter * 0.75);
    final List<_CandidateRow> candidateRows = _clusterCandidatesByY(
      candidates,
      yTolerance,
    );
    final List<_BubbleRow> bubbleRows = <_BubbleRow>[];

    for (final _CandidateRow row in candidateRows) {
      final List<_BubbleGroup> groups = _findBubbleGroups(row.candidates);

      if (groups.isNotEmpty) {
        bubbleRows.add(_BubbleRow(centerY: row.centerY, groups: groups));
      }
    }

    if (bubbleRows.isEmpty) {
      return null;
    }

    bubbleRows.sort((_BubbleRow a, _BubbleRow b) {
      return a.centerY.compareTo(b.centerY);
    });

    final int requiredRows = min(_itemsPerColumn, totalQuestions);

    if (bubbleRows.length < requiredRows) {
      return null;
    }

    _GridWindow? bestWindow;

    for (int start = 0; start <= bubbleRows.length - requiredRows; start++) {
      final List<_BubbleRow> window = bubbleRows.sublist(
        start,
        start + requiredRows,
      );
      final double score = _scoreGridWindow(window, totalQuestions);
      final _GridWindow candidateWindow = _GridWindow(
        rows: window,
        score: score,
      );

      if (bestWindow == null || candidateWindow.score > bestWindow.score) {
        bestWindow = candidateWindow;
      }
    }

    if (bestWindow == null || bestWindow.score <= 0.0) {
      return null;
    }

    return _DetectedGrid(rows: bestWindow.rows);
  }

  static List<_CandidateRow> _clusterCandidatesByY(
    List<_BubbleCandidate> candidates,
    double yTolerance,
  ) {
    final List<_BubbleCandidate> sortedCandidates =
        List<_BubbleCandidate>.from(candidates)
          ..sort((_BubbleCandidate a, _BubbleCandidate b) {
            return a.centerY.compareTo(b.centerY);
          });
    final List<_CandidateRow> rows = <_CandidateRow>[];

    for (final _BubbleCandidate candidate in sortedCandidates) {
      if (rows.isEmpty ||
          (candidate.centerY - rows.last.centerY).abs() > yTolerance) {
        rows.add(
          _CandidateRow(
            centerY: candidate.centerY,
            candidates: <_BubbleCandidate>[candidate],
          ),
        );
      } else {
        rows.last.add(candidate);
      }
    }

    return rows;
  }

  static List<_BubbleGroup> _findBubbleGroups(
    List<_BubbleCandidate> rowCandidates,
  ) {
    final List<_BubbleCandidate> sortedCandidates =
        List<_BubbleCandidate>.from(rowCandidates)
          ..sort((_BubbleCandidate a, _BubbleCandidate b) {
            return a.centerX.compareTo(b.centerX);
          });
    final List<_BubbleGroup> groups = <_BubbleGroup>[];
    int index = 0;

    while (index <= sortedCandidates.length - _choicesPerQuestion) {
      final List<_BubbleCandidate> window = sortedCandidates.sublist(
        index,
        index + _choicesPerQuestion,
      );

      if (_isRegularBubbleGroup(window)) {
        groups.add(_BubbleGroup(bubbles: window));
        index = index + _choicesPerQuestion;
      } else {
        index = index + 1;
      }
    }

    return groups;
  }

  static bool _isRegularBubbleGroup(List<_BubbleCandidate> bubbles) {
    if (bubbles.length != _choicesPerQuestion) {
      return false;
    }

    final List<double> gaps = <double>[];

    for (int i = 1; i < bubbles.length; i++) {
      gaps.add(bubbles[i].centerX - bubbles[i - 1].centerX);
    }

    final double meanGap =
        gaps.reduce((double a, double b) => a + b) / gaps.length;
    final double minGap = gaps.reduce(min);
    final double maxGap = gaps.reduce(max);
    final double meanDiameter =
        bubbles
            .map((_BubbleCandidate bubble) => bubble.diameter)
            .reduce((double a, double b) => a + b) /
        bubbles.length;

    return meanGap >= meanDiameter * 1.15 &&
        meanGap <= meanDiameter * 4.5 &&
        minGap > 0 &&
        maxGap / minGap <= 1.75;
  }

  static double _scoreGridWindow(List<_BubbleRow> rows, int totalQuestions) {
    if (rows.isEmpty) {
      return 0.0;
    }

    double groupScore = 0.0;
    int expectedGroups = 0;

    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      for (int colIndex = 0; colIndex < _columns; colIndex++) {
        final int questionIndex = (colIndex * _itemsPerColumn) + rowIndex;

        if (questionIndex < totalQuestions) {
          expectedGroups = expectedGroups + 1;
        }
      }

      final int rowExpectedGroups = _expectedGroupsForRow(
        rowIndex,
        totalQuestions,
      );
      groupScore =
          groupScore + min(rows[rowIndex].groups.length, rowExpectedGroups);
    }

    if (expectedGroups == 0) {
      return 0.0;
    }

    double regularityScore = 1.0;

    if (rows.length > 2) {
      final List<double> gaps = <double>[];

      for (int i = 1; i < rows.length; i++) {
        gaps.add(rows[i].centerY - rows[i - 1].centerY);
      }

      final double meanGap =
          gaps.reduce((double a, double b) => a + b) / gaps.length;
      double absoluteDeviation = 0.0;

      for (final double gap in gaps) {
        absoluteDeviation = absoluteDeviation + (gap - meanGap).abs();
      }

      final double averageDeviation = absoluteDeviation / gaps.length;
      regularityScore = 1.0 / (1.0 + (averageDeviation / max(1.0, meanGap)));
    }

    return (groupScore / expectedGroups) + regularityScore;
  }

  static int _expectedGroupsForRow(int rowIndex, int totalQuestions) {
    int expectedGroups = 0;

    for (int colIndex = 0; colIndex < _columns; colIndex++) {
      final int questionIndex = (colIndex * _itemsPerColumn) + rowIndex;

      if (questionIndex < totalQuestions) {
        expectedGroups = expectedGroups + 1;
      }
    }

    return expectedGroups;
  }

  static double _scoreBubbleCore(
    List<int> luminance,
    int width,
    int height,
    _BubbleCandidate bubble,
  ) {
    final double radius = max(3.0, bubble.diameter * 0.28);
    final int minX = max(0, (bubble.centerX - radius).floor());
    final int maxX = min(width - 1, (bubble.centerX + radius).ceil());
    final int minY = max(0, (bubble.centerY - radius).floor());
    final int maxY = min(height - 1, (bubble.centerY + radius).ceil());
    final double radiusSquared = radius * radius;
    double totalInk = 0.0;
    int sampledPixels = 0;

    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        final double dx = x - bubble.centerX;
        final double dy = y - bubble.centerY;

        if ((dx * dx) + (dy * dy) > radiusSquared) {
          continue;
        }

        final int value = luminance[(y * width) + x];
        final double darkness = ((205 - value) / 205).clamp(0.0, 1.0);
        totalInk = totalInk + darkness;
        sampledPixels = sampledPixels + 1;
      }
    }

    if (sampledPixels == 0) {
      return 0.0;
    }

    return totalInk / sampledPixels;
  }

  static int _selectMarkedChoice(List<double> scores) {
    if (scores.isEmpty) {
      return -1;
    }

    int bestIndex = 0;
    double bestScore = scores[0];
    double secondBestScore = 0.0;

    for (int i = 1; i < scores.length; i++) {
      final double score = scores[i];

      if (score > bestScore) {
        secondBestScore = bestScore;
        bestScore = score;
        bestIndex = i;
      } else if (score > secondBestScore) {
        secondBestScore = score;
      }
    }

    final bool isDarkEnough = bestScore >= 0.16;
    final bool isClearlyBest =
        bestScore - secondBestScore >= 0.04 ||
        bestScore >= secondBestScore * 1.35;

    if (isDarkEnough && isClearlyBest) {
      return bestIndex;
    }

    return -1;
  }
}

class _BubbleCandidate {
  final double centerX;
  final double centerY;
  final double diameter;

  const _BubbleCandidate({
    required this.centerX,
    required this.centerY,
    required this.diameter,
  });
}

class _CandidateRow {
  double centerY;
  final List<_BubbleCandidate> candidates;

  _CandidateRow({required this.centerY, required this.candidates});

  void add(_BubbleCandidate candidate) {
    candidates.add(candidate);
    double totalY = 0.0;

    for (final _BubbleCandidate item in candidates) {
      totalY = totalY + item.centerY;
    }

    centerY = totalY / candidates.length;
  }
}

class _BubbleGroup {
  final List<_BubbleCandidate> bubbles;

  const _BubbleGroup({required this.bubbles});
}

class _BubbleRow {
  final double centerY;
  final List<_BubbleGroup> groups;

  const _BubbleRow({required this.centerY, required this.groups});
}

class _DetectedGrid {
  final List<_BubbleRow> rows;

  const _DetectedGrid({required this.rows});
}

class _GridWindow {
  final List<_BubbleRow> rows;
  final double score;

  const _GridWindow({required this.rows, required this.score});
}
