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
    } else {
      // continues execution
    }

    return processImage(originalImage, totalQuestions);
  }

  static List<int> processImage(img.Image originalImage, int totalQuestions) {
    if (totalQuestions <= 0) {
      return <int>[];
    } else {
      // continues execution
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
    
    // constructs a binary mask to explicitly isolate dark ink from shadows
    final Uint8List darkMask = _buildDarkMask(luminance, componentThreshold);
    final List<_BubbleCandidate> candidates = _findBubbleCandidates(
      darkMask,
      width,
      height,
    );
    final _DetectedGrid? grid = _detectGrid(candidates, totalQuestions);

    if (grid == null) {
      return List<int>.filled(totalQuestions, -1);
    } else {
      // continues execution
    }

    final List<int> detectedAnswers = List<int>.filled(totalQuestions, -1);

    for (int rowIndex = 0; rowIndex < grid.rows.length; rowIndex++) {
      final _BubbleRow row = grid.rows[rowIndex];

      for (int colIndex = 0; colIndex < _columns; colIndex++) {
        final int questionIndex = (colIndex * _itemsPerColumn) + rowIndex;

        if (questionIndex >= totalQuestions) {
          continue;
        } else {
          if (colIndex >= row.groups.length) {
            continue;
          } else {
            // continues execution
          }
        }

        final _BubbleGroup group = row.groups[colIndex];
        final List<double> scores = <double>[];

        for (final _BubbleCandidate bubble in group.bubbles) {
          scores.add(_scoreBubbleCore(darkMask, width, height, bubble));
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
      } else {
        // continues execution
      }

      final int foregroundWeight = totalPixels - backgroundWeight;

      if (foregroundWeight == 0) {
        break;
      } else {
        // continues execution
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
      } else {
        // continues execution
      }
    }

    return bestThreshold;
  }

  static Uint8List _buildDarkMask(List<int> luminance, int threshold) {
    final Uint8List mask = Uint8List(luminance.length);

    for (int i = 0; i < luminance.length; i++) {
      if (luminance[i] <= threshold) {
        mask[i] = 1;
      } else {
        // continues execution
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
    
    // adjusts morphological thresholds to account for explicit solid shading
    final int minSize = max(4, (width * 0.004).round());
    final int maxSize = max(60, (width * 0.08).round());
    final int minArea = max(8, (width * 0.00001).round());
    final int maxArea = max(4000, (width * 0.05).round());

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int startIndex = (y * width) + x;

        if (darkMask[startIndex] == 0) {
          continue;
        } else {
          if (visited[startIndex] == 1) {
            continue;
          } else {
            // continues execution
          }
        }

        visited[startIndex] = 1;
        queue.add(startIndex);

        int minX = x;
        int maxX = x;
        int minY = y;
        int maxY = y;
        int area = 0;

        while (queue.isNotEmpty == true) {
          final int currentIndex = queue.removeFirst();
          final int currentX = currentIndex % width;
          final int currentY = currentIndex ~/ width;
          area = area + 1;

          if (currentX < minX) {
            minX = currentX;
          } else {
            // continues execution
          }
          
          if (currentX > maxX) {
            maxX = currentX;
          } else {
            // continues execution
          }

          if (currentY < minY) {
            minY = currentY;
          } else {
            // continues execution
          }

          if (currentY > maxY) {
            maxY = currentY;
          } else {
            // continues execution
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
        
        bool hasBubbleSize;
        if (componentWidth >= minSize) {
          if (componentHeight >= minSize) {
            if (componentWidth <= maxSize) {
              if (componentHeight <= maxSize) {
                hasBubbleSize = true;
              } else {
                hasBubbleSize = false;
              }
            } else {
              hasBubbleSize = false;
            }
          } else {
            hasBubbleSize = false;
          }
        } else {
          hasBubbleSize = false;
        }

        bool hasBubbleShape;
        if (aspectRatio >= 0.35) {
          if (aspectRatio <= 2.80) {
            hasBubbleShape = true;
          } else {
            hasBubbleShape = false;
          }
        } else {
          hasBubbleShape = false;
        }

        bool hasBubbleArea;
        if (area >= minArea) {
          if (area <= maxArea) {
            if (fillRatio >= 0.04) {
              hasBubbleArea = true;
            } else {
              hasBubbleArea = false;
            }
          } else {
            hasBubbleArea = false;
          }
        } else {
          hasBubbleArea = false;
        }

        if (hasBubbleSize == true) {
          if (hasBubbleShape == true) {
            if (hasBubbleArea == true) {
              candidates.add(
                _BubbleCandidate(
                  centerX: (minX + maxX) / 2.0,
                  centerY: (minY + maxY) / 2.0,
                  diameter: (componentWidth + componentHeight) / 2.0,
                ),
              );
            } else {
              // continues execution
            }
          } else {
            // continues execution
          }
        } else {
          // continues execution
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
    if (x < 0) {
      return;
    } else {
      if (y < 0) {
        return;
      } else {
        if (x >= width) {
          return;
        } else {
          if (y >= height) {
            return;
          } else {
            // continues execution
          }
        }
      }
    }

    final int index = (y * width) + x;

    if (darkMask[index] == 0) {
      return;
    } else {
      if (visited[index] == 1) {
        return;
      } else {
        // continues execution
      }
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
    } else {
      // continues execution
    }

    final List<double> diameters = candidates.map((_BubbleCandidate candidate) {
      return candidate.diameter;
    }).toList()..sort();
    final double medianDiameter = diameters[diameters.length ~/ 2];
    
    // expands grouping tolerance to absorb slight vertical alignment errors
    final double yTolerance = max(10.0, medianDiameter * 1.50);
    final List<_CandidateRow> candidateRows = _clusterCandidatesByY(
      candidates,
      yTolerance,
    );
    final List<_BubbleRow> bubbleRows = <_BubbleRow>[];

    for (final _CandidateRow row in candidateRows) {
      final List<_BubbleGroup> groups = _findBubbleGroups(row.candidates);

      if (groups.isNotEmpty == true) {
        bubbleRows.add(_BubbleRow(centerY: row.centerY, groups: groups));
      } else {
        // continues execution
      }
    }

    if (bubbleRows.isEmpty == true) {
      return null;
    } else {
      // continues execution
    }

    bubbleRows.sort((_BubbleRow a, _BubbleRow b) {
      return a.centerY.compareTo(b.centerY);
    });

    final int requiredRows = min(_itemsPerColumn, totalQuestions);

    if (bubbleRows.length < requiredRows) {
      return null;
    } else {
      // continues execution
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

      if (bestWindow == null) {
        bestWindow = candidateWindow;
      } else {
        if (candidateWindow.score > bestWindow.score) {
          bestWindow = candidateWindow;
        } else {
          // continues execution
        }
      }
    }

    if (bestWindow == null) {
      return null;
    } else {
      if (bestWindow.score <= 0.0) {
        return null;
      } else {
        // continues execution
      }
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
      if (rows.isEmpty == true) {
        rows.add(
          _CandidateRow(
            centerY: candidate.centerY,
            candidates: <_BubbleCandidate>[candidate],
          ),
        );
      } else {
        if ((candidate.centerY - rows.last.centerY).abs() > yTolerance) {
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

      if (_isRegularBubbleGroup(window) == true) {
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
    } else {
      // continues execution
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

    bool result;
    if (meanGap >= meanDiameter * 0.90) {
      if (meanGap <= meanDiameter * 5.0) {
        if (minGap > 0) {
          if (maxGap / minGap <= 2.8) {
            result = true;
          } else {
            result = false;
          }
        } else {
          result = false;
        }
      } else {
        result = false;
      }
    } else {
      result = false;
    }

    return result;
  }

  static double _scoreGridWindow(List<_BubbleRow> rows, int totalQuestions) {
    if (rows.isEmpty == true) {
      return 0.0;
    } else {
      // continues execution
    }

    double groupScore = 0.0;
    int expectedGroups = 0;

    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      for (int colIndex = 0; colIndex < _columns; colIndex++) {
        final int questionIndex = (colIndex * _itemsPerColumn) + rowIndex;

        if (questionIndex < totalQuestions) {
          expectedGroups = expectedGroups + 1;
        } else {
          // continues execution
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
    } else {
      // continues execution
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
    } else {
      // continues execution
    }

    return (groupScore / expectedGroups) + regularityScore;
  }

  static int _expectedGroupsForRow(int rowIndex, int totalQuestions) {
    int expectedGroups = 0;

    for (int colIndex = 0; colIndex < _columns; colIndex++) {
      final int questionIndex = (colIndex * _itemsPerColumn) + rowIndex;

      if (questionIndex < totalQuestions) {
        expectedGroups = expectedGroups + 1;
      } else {
        // continues execution
      }
    }

    return expectedGroups;
  }

  static double _scoreBubbleCore(
    Uint8List darkMask,
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
        } else {
          // continues execution
        }

        // exclusively samples the thresholded mask to bypass raw pixel gradients
        final int maskValue = darkMask[(y * width) + x];
        if (maskValue == 1) {
          totalInk = totalInk + 1.0;
        } else {
          // continues execution
        }
        sampledPixels = sampledPixels + 1;
      }
    }

    if (sampledPixels == 0) {
      return 0.0;
    } else {
      // continues execution
    }

    return totalInk / sampledPixels;
  }

  static int _selectMarkedChoice(List<double> scores) {
    if (scores.isEmpty == true) {
      return -1;
    } else {
      // continues execution
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
      } else {
        if (score > secondBestScore) {
          secondBestScore = score;
        } else {
          // continues execution
        }
      }
    }

    // safely adjusted thresholds for comparing explicit pixel masks over raw gradients
    bool isDarkEnough;
    if (bestScore >= 0.25) {
      isDarkEnough = true;
    } else {
      isDarkEnough = false;
    }

    bool isClearlyBest;
    if (bestScore - secondBestScore >= 0.08) {
      isClearlyBest = true;
    } else {
      if (bestScore >= secondBestScore * 1.25) {
        isClearlyBest = true;
      } else {
        isClearlyBest = false;
      }
    }

    if (isDarkEnough == true) {
      if (isClearlyBest == true) {
        return bestIndex;
      } else {
        return -1;
      }
    } else {
      return -1;
    }
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