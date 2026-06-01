import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class OMRProcessor {
  /// Analyzes a scanned photo to determine which choices were filled in.
  /// returns a list of integers representing choices (0=A, 1=B, 2=C, 3=D)
  static List<int> processAnswerSheet(File imageFile, int totalQuestions, int choicesPerQuestion) {
    List<int> detectedAnswers = [];
    
    // 1. Read the raw file bytes and decode into an image object
    List<int> bytes = imageFile.readAsBytesSync();
    img.Image? originalImage = img.decodeImage(Uint8List.fromList(bytes));
    if (originalImage == null) return [];

    // 2. Turn the image grayscale to eliminate color bias (lighting artifacts)
    img.Image grayscale = img.grayscale(originalImage);
    
    int width = grayscale.width;
    int height = grayscale.height;

    // 3. Math to establish the boundaries of each option grid
    double rowHeight = height / totalQuestions;
    double colWidth = width / choicesPerQuestion;

    // 4. Scan through every row (question) and column (choice)
    for (int q = 0; q < totalQuestions; q++) {
      int highestDarkPixelCount = 0;
      int selectedChoice = -1; // -1 means blank/no answer detected

      for (int c = 0; c < choicesPerQuestion; c++) {
        int darkPixels = 0;

        // Calculate bounding coordinates for this specific bubble zone
        int startX = (c * colWidth).toInt();
        int startY = (q * rowHeight).toInt();
        int endX = ((c + 1) * colWidth).toInt();
        int endY = ((q + 1) * rowHeight).toInt();

        // Loop over individual pixels within the specific bubble boundary box
        for (int x = startX; x < endX; x++) {
          for (int y = startY; y < endY; y++) {
            var pixel = grayscale.getPixel(x, y);
            
            // In the 'image' package, we look at the red channel value 
            // since grayscale makes r, g, and b identical. (0 is pure black, 255 is pure white)
            if (pixel.r < 110) { 
              darkPixels++;
            }
          }
        }

        // The bubble with the highest concentration of dark pencil/pen strokes wins
        if (darkPixels > highestDarkPixelCount && darkPixels > 40) { 
          highestDarkPixelCount = darkPixels;
          selectedChoice = c; 
        }
      }
      detectedAnswers.add(selectedChoice);
    }

    return detectedAnswers;
  }
}