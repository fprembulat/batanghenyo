import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:batanghenyo/services/omr_processor.dart';

void main() {
  test('blank answer sheet returns unanswered choices', () {
    final img.Image sheet = _buildAnswerSheet(totalQuestions: 45);

    final List<int> answers = OMRProcessor.processImage(sheet, 45);

    expect(answers, hasLength(45));
    expect(answers.every((int answer) => answer == -1), isTrue);
  });

  test('single filled bubble returns only that answer', () {
    final img.Image sheet = _buildAnswerSheet(
      totalQuestions: 45,
      filledAnswers: <int, int>{0: 2},
    );

    final List<int> answers = OMRProcessor.processImage(sheet, 45);

    expect(answers, hasLength(45));
    expect(answers[0], 2);
    expect(answers.skip(1).every((int answer) => answer == -1), isTrue);
  });

  test('solid edited bubble is detected without false positives', () {
    final img.Image sheet = _buildAnswerSheet(
      totalQuestions: 45,
      filledAnswers: <int, int>{24: 4},
    );

    final List<int> answers = OMRProcessor.processImage(sheet, 45);

    expect(answers, hasLength(45));
    expect(answers[24], 4);
    expect(
      answers
          .asMap()
          .entries
          .where((MapEntry<int, int> entry) => entry.key != 24)
          .every((MapEntry<int, int> entry) => entry.value == -1),
      isTrue,
    );
  });
}

img.Image _buildAnswerSheet({
  required int totalQuestions,
  Map<int, int> filledAnswers = const <int, int>{},
}) {
  final img.Image sheet = img.Image(width: 1000, height: 1400);
  final img.ColorRgb8 white = img.ColorRgb8(255, 255, 255);
  final img.ColorRgb8 black = img.ColorRgb8(0, 0, 0);

  for (int y = 0; y < sheet.height; y++) {
    for (int x = 0; x < sheet.width; x++) {
      sheet.setPixel(x, y, white);
    }
  }

  const List<double> columnStarts = <double>[110.0, 410.0, 710.0];
  const double firstRowY = 250.0;
  const double rowGap = 46.0;
  const double choiceGap = 31.0;
  const double radius = 9.0;

  for (int col = 0; col < 3; col++) {
    for (int row = 0; row < 20; row++) {
      final int questionIndex = (col * 20) + row;

      if (questionIndex >= totalQuestions) {
        continue;
      }

      for (int choice = 0; choice < 5; choice++) {
        final double centerX = columnStarts[col] + (choice * choiceGap);
        final double centerY = firstRowY + (row * rowGap);
        _drawRing(sheet, centerX, centerY, radius, black);

        if (filledAnswers[questionIndex] == choice) {
          _fillCircle(sheet, centerX, centerY, radius - 1.0, black);
        }
      }
    }
  }

  return sheet;
}

void _drawRing(
  img.Image image,
  double centerX,
  double centerY,
  double radius,
  img.Color color,
) {
  final int minX = (centerX - radius - 2).floor();
  final int maxX = (centerX + radius + 2).ceil();
  final int minY = (centerY - radius - 2).floor();
  final int maxY = (centerY + radius + 2).ceil();

  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      final double dx = x - centerX;
      final double dy = y - centerY;
      final double distance = (dx * dx) + (dy * dy);

      if (distance >= (radius - 1.4) * (radius - 1.4) &&
          distance <= (radius + 1.4) * (radius + 1.4)) {
        image.setPixel(x, y, color);
      }
    }
  }
}

void _fillCircle(
  img.Image image,
  double centerX,
  double centerY,
  double radius,
  img.Color color,
) {
  final int minX = (centerX - radius).floor();
  final int maxX = (centerX + radius).ceil();
  final int minY = (centerY - radius).floor();
  final int maxY = (centerY + radius).ceil();

  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      final double dx = x - centerX;
      final double dy = y - centerY;

      if ((dx * dx) + (dy * dy) <= radius * radius) {
        image.setPixel(x, y, color);
      }
    }
  }
}
