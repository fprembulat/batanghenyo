import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class OMRProcessor {
  // processes the physical answer sheet utilizing dynamic bounding box geometry
  static List<int> processAnswerSheet(File imageFile, int totalQuestions) {
    final List<int> detectedAnswers = [];
    final List<int> bytes = imageFile.readAsBytesSync();
    final img.Image? originalImage = img.decodeImage(Uint8List.fromList(bytes));
    
    if (originalImage == null) {
      return detectedAnswers;
    } else {
      // continues processing since image is valid
    }

    final img.Image grayscale = img.grayscale(originalImage);
    
    // scales the image down to standard width to exponentially increase thresholding speed
    final img.Image scaledImage = img.copyResize(grayscale, width: 800);
    
    // applies the adaptive threshold to isolate dark pencil marks against shadows and lighting variables
    final img.Image binaryImage = _applyAdaptiveThreshold(scaledImage, 40, 15);

    final int width = binaryImage.width;
    final int height = binaryImage.height;

    int minX = width;
    int maxX = 0;
    int minY = height;
    int maxY = 0;

    // ignores outer five percent of image to prevent desk boundaries from skewing layout
    final double rawMarginX = width * 0.05;
    final double rawMarginY = height * 0.05;
    final int marginX = rawMarginX.toInt();
    final int marginY = rawMarginY.toInt();

    // scans for the extreme edges of all text and bubbles to establish the core content box
    for (int y = marginY; y < height - marginY; y++) {
      for (int x = marginX; x < width - marginX; x++) {
        final img.Pixel pixel = binaryImage.getPixel(x, y);
        final num redChannel = pixel.r;
        
        if (redChannel > 128) {
          if (x < minX) {
            minX = x;
          } else {
            // keeps current min bound
          }
          
          if (x > maxX) {
            maxX = x;
          } else {
            // keeps current max bound
          }
          
          if (y < minY) {
            minY = y;
          } else {
            // keeps current min bound
          }
          
          if (y > maxY) {
            maxY = y;
          } else {
            // keeps current max bound
          }
        } else {
          // ignores dark background pixels
        }
      }
    }

    if (minX >= maxX) {
      return detectedAnswers;
    } else {
      if (minY >= maxY) {
        return detectedAnswers;
      } else {
        // valid bounding box located
      }
    }

    // calculates relative grid boundaries based on the standard batanghenyo physical template
    final double contentWidth = (maxX - minX).toDouble();
    final double contentHeight = (maxY - minY).toDouble();

    // places grid starting point safely below the header text elements
    final double gridStartYOffset = contentHeight * 0.17;
    final double gridStartY = minY + gridStartYOffset;
    final double gridHeight = contentHeight * 0.83;
    
    final double colWidth = contentWidth / 3.0;
    final double rowHeight = gridHeight / 20.0;

    final int itemsPerColumn = 20;
    final int choicesPerQuestion = 5;

    // iterates through the 3 macro columns mapping the choice coordinates dynamically
    for (int col = 0; col < 3; col++) {
      final double colStartXOffset = col * colWidth;
      final double colStartX = minX + colStartXOffset;
      
      final double bubblesStartXOffset = colWidth * 0.18;
      final double bubblesStartX = colStartX + bubblesStartXOffset;
      
      final double bubblesWidth = colWidth * 0.80;
      final double choiceWidth = bubblesWidth / 5.0;
      
      for (int row = 0; row < itemsPerColumn; row++) {
        final int currentQuestionNumber = (col * itemsPerColumn) + row;
        
        if (currentQuestionNumber >= totalQuestions) {
          // breaks early if the defined exam length is reached
          break;
        } else {
          int highestWhitePixelCount = 0;
          int selectedChoice = -1;
          
          final double boxStartYOffset = row * rowHeight;
          final double boxStartY = gridStartY + boxStartYOffset;

          for (int c = 0; c < choicesPerQuestion; c++) {
            final double boxStartXOffset = c * choiceWidth;
            final double boxStartX = bubblesStartX + boxStartXOffset;

            // shrinks sample box by thirty percent on all sides to isolate the deep bubble core
            final double rawPaddingX = choiceWidth * 0.30;
            final double rawPaddingY = rowHeight * 0.30;
            final int paddingX = rawPaddingX.toInt();
            final int paddingY = rawPaddingY.toInt();

            final int boxStartXInt = boxStartX.toInt();
            final int boxStartYInt = boxStartY.toInt();
            final int boxEndXInt = (boxStartX + choiceWidth).toInt();
            final int boxEndYInt = (boxStartY + rowHeight).toInt();

            final int sampleStartX = boxStartXInt + paddingX;
            final int sampleEndX = boxEndXInt - paddingX;
            final int sampleStartY = boxStartYInt + paddingY;
            final int sampleEndY = boxEndYInt - paddingY;

            int whitePixels = 0;
            int totalSamplePixels = 0;

            // evaluates pixels exclusively inside the core to guarantee empty outlines return zero hits
            for (int x = sampleStartX; x <= sampleEndX; x++) {
              for (int y = sampleStartY; y <= sampleEndY; y++) {
                totalSamplePixels = totalSamplePixels + 1;
                
                if (x >= 0) {
                  if (x < width) {
                    if (y >= 0) {
                      if (y < height) {
                        final img.Pixel corePixel = binaryImage.getPixel(x, y);
                        final num coreLuminance = corePixel.r;
                        
                        if (coreLuminance > 128) {
                          whitePixels = whitePixels + 1;
                        } else {
                          // ignores empty core space
                        }
                      } else {
                        // ignores out of bounds vertical index
                      }
                    } else {
                      // ignores out of bounds vertical index
                    }
                  } else {
                    // ignores out of bounds horizontal index
                  }
                } else {
                  // ignores out of bounds horizontal index
                }
              }
            }

            // registers choice if the core density exceeds the baseline shading tolerance
            if (whitePixels > highestWhitePixelCount) {
              final double toleranceLimit = totalSamplePixels * 0.15;
              if (whitePixels > toleranceLimit) {
                highestWhitePixelCount = whitePixels;
                selectedChoice = c;
              } else {
                // insufficient shading intensity
              }
            } else {
              // choice is lighter than previously checked option
            }
          }
          
          detectedAnswers.add(selectedChoice);
        }
      }
    }

    return detectedAnswers;
  }

  // executes the bradley-roth algorithm to dynamically evaluate local contrast explicitly
  static img.Image _applyAdaptiveThreshold(img.Image grayscale, int windowSize, int contrastThreshold) {
    final int width = grayscale.width;
    final int height = grayscale.height;
    
    final img.Image binaryImage = img.Image(width: width, height: height);
    final List<int> integralImage = List<int>.filled(width * height, 0);

    // builds integral image matrix for rapid area sum calculations
    for (int y = 0; y < height; y++) {
      int sum = 0;
      for (int x = 0; x < width; x++) {
        final img.Pixel pixel = grayscale.getPixel(x, y);
        final int luminance = pixel.r.toInt();
        sum = sum + luminance;
        
        if (y == 0) {
          final int index = y * width + x;
          integralImage[index] = sum;
        } else {
          final int currentIndex = y * width + x;
          final int previousRowIndex = (y - 1) * width + x;
          final int previousRowVal = integralImage[previousRowIndex];
          integralImage[currentIndex] = previousRowVal + sum;
        }
      }
    }

    final int halfWindow = windowSize ~/ 2;

    // evaluates local contrast for each pixel to isolate dark pencil marks from the background
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        int rx1 = x - halfWindow;
        if (rx1 < 0) {
          rx1 = 0;
        } else {
          // keeps constrained coordinate
        }
        
        int rx2 = x + halfWindow;
        if (rx2 >= width) {
          rx2 = width - 1;
        } else {
          // keeps constrained coordinate
        }
        
        int ry1 = y - halfWindow;
        if (ry1 < 0) {
          ry1 = 0;
        } else {
          // keeps constrained coordinate
        }
        
        int ry2 = y + halfWindow;
        if (ry2 >= height) {
          ry2 = height - 1;
        } else {
          // keeps constrained coordinate
        }

        final int boxWidth = rx2 - rx1 + 1;
        final int boxHeight = ry2 - ry1 + 1;
        final int count = boxWidth * boxHeight;

        final int bottomRightIndex = ry2 * width + rx2;
        final int sumBottomRight = integralImage[bottomRightIndex];
        
        int sumTopRight;
        if (ry1 > 0) {
          final int topRightIndex = (ry1 - 1) * width + rx2;
          sumTopRight = integralImage[topRightIndex];
        } else {
          sumTopRight = 0;
        }
        
        int sumBottomLeft;
        if (rx1 > 0) {
          final int bottomLeftIndex = ry2 * width + (rx1 - 1);
          sumBottomLeft = integralImage[bottomLeftIndex];
        } else {
          sumBottomLeft = 0;
        }
        
        int sumTopLeft;
        if (rx1 > 0) {
          if (ry1 > 0) {
            final int topLeftIndex = (ry1 - 1) * width + (rx1 - 1);
            sumTopLeft = integralImage[topLeftIndex];
          } else {
            sumTopLeft = 0;
          }
        } else {
          sumTopLeft = 0;
        }

        final int totalSum = sumBottomRight - sumTopRight - sumBottomLeft + sumTopLeft;
        final int averageLuminance = totalSum ~/ count;
        
        final img.Pixel currentPixel = grayscale.getPixel(x, y);
        final int currentLuminance = currentPixel.r.toInt();
        final int limit = averageLuminance - contrastThreshold;

        // assigns white to pixels significantly darker than their immediate surroundings
        if (currentLuminance < limit) {
          binaryImage.setPixelRgba(x, y, 255, 255, 255, 255);
        } else {
          binaryImage.setPixelRgba(x, y, 0, 0, 0, 255);
        }
      }
    }

    return binaryImage;
  }
}