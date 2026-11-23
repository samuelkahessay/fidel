import PencilKit
import UIKit

struct DrawingEvaluation: Equatable {
    let score: Double
    let coverage: Double
    let precision: Double
    let retryReason: DrawingRetryReason?

    var passed: Bool {
        retryReason == nil
    }
}

enum DrawingRetryReason: Equatable {
    case blankDrawing
    case tooLittleCoverage
    case tooMuchOutsideGuide
}

/// Evaluates user drawings against reference character paths using IoU similarity.
final class DrawingEvaluator {
    static let shared = DrawingEvaluator()

    /// Grid resolution for rasterization comparison
    private let gridSize = 96

    /// Minimum coverage and precision needed to pass review.
    private let coverageThreshold: Double = 0.18
    private let precisionThreshold: Double = 0.22
    private let minimumDrawingPixels = 8
    private let referenceToleranceRadius = 3
    private let drawingToleranceRadius = 2

    private init() {}

    /// Result of evaluating a user's drawing against a reference path.
    enum DrawingResult {
        case needsRetry(DrawingEvaluation)
        case passedForReview(DrawingEvaluation)

        var evaluation: DrawingEvaluation {
            switch self {
            case .needsRetry(let evaluation), .passedForReview(let evaluation):
                return evaluation
            }
        }
    }

    /// Evaluate a user's PKDrawing against a reference CGPath.
    /// The reference and drawing are rasterized and compared with a small tolerance
    /// so finger input is forgiving without accepting blank or off-target attempts.
    func evaluate(drawing: PKDrawing, referencePath: CGPath, canvasSize: CGSize) -> DrawingResult {
        let referenceGrid = rasterizePath(referencePath, canvasSize: canvasSize)
        let drawingGrid = rasterizeDrawing(drawing, canvasSize: canvasSize)
        let drawingPixels = countFilled(in: drawingGrid)

        guard !drawing.strokes.isEmpty, drawingPixels >= minimumDrawingPixels else {
            return .needsRetry(
                DrawingEvaluation(score: 0, coverage: 0, precision: 0, retryReason: .blankDrawing)
            )
        }

        let tolerantReference = dilate(referenceGrid, radius: referenceToleranceRadius)
        let tolerantDrawing = dilate(drawingGrid, radius: drawingToleranceRadius)

        let referencePixels = max(countFilled(in: referenceGrid), 1)
        let coveredReference = countOverlap(gridA: referenceGrid, gridB: tolerantDrawing)
        let preciseDrawing = countOverlap(gridA: drawingGrid, gridB: tolerantReference)
        let coverage = min(Double(coveredReference) / Double(referencePixels), 1)
        let precision = min(Double(preciseDrawing) / Double(max(drawingPixels, 1)), 1)
        let score = harmonicMean(coverage, precision)

        let retryReason: DrawingRetryReason?
        if coverage < coverageThreshold {
            retryReason = .tooLittleCoverage
        } else if precision < precisionThreshold {
            retryReason = .tooMuchOutsideGuide
        } else {
            retryReason = nil
        }

        let evaluation = DrawingEvaluation(
            score: score,
            coverage: coverage,
            precision: precision,
            retryReason: retryReason
        )

        return evaluation.passed ? .passedForReview(evaluation) : .needsRetry(evaluation)
    }

    // MARK: - Private

    /// Rasterize a CGPath to a boolean grid by filling it into a bitmap context.
    /// Uses fill since Noto Sans Ethiopic has uniform stroke width that fills cleanly,
    /// matching the filled guide shape the user traces over.
    private func rasterizePath(_ path: CGPath, canvasSize: CGSize) -> [[Bool]] {
        let width = gridSize
        let height = gridSize

        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            )
        else {
            return Array(repeating: Array(repeating: false, count: width), count: height)
        }

        // Clear to white
        context.setFillColor(gray: 1.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Scale path from canvas coordinates to grid coordinates
        let scaleX = CGFloat(width) / canvasSize.width
        let scaleY = CGFloat(height) / canvasSize.height
        var transform = CGAffineTransform(scaleX: scaleX, y: scaleY)

        if let scaledPath = path.copy(using: &transform) {
            context.setFillColor(gray: 0.0, alpha: 1.0)
            context.addPath(scaledPath)
            context.fillPath()
        }

        return extractGrid(from: context, width: width, height: height)
    }

    /// Rasterize a PKDrawing to a boolean grid.
    /// Uses an RGBA context to properly handle the transparent background of PKDrawing images.
    private func rasterizeDrawing(_ drawing: PKDrawing, canvasSize: CGSize) -> [[Bool]] {
        let width = gridSize
        let height = gridSize
        let imageSize = CGSize(width: CGFloat(width), height: CGFloat(height))

        // Render drawing to a small image
        let image = drawing.image(from: CGRect(origin: .zero, size: canvasSize), scale: CGFloat(width) / canvasSize.width)

        guard let cgImage = image.cgImage else {
            return Array(repeating: Array(repeating: false, count: width), count: height)
        }

        // Use RGBA context to properly detect strokes on transparent background
        let bytesPerRow = width * 4
        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return Array(repeating: Array(repeating: false, count: width), count: height)
        }

        // Clear to transparent
        context.clear(CGRect(origin: .zero, size: imageSize))

        // Draw the PKDrawing image
        context.draw(cgImage, in: CGRect(origin: .zero, size: imageSize))

        // Extract grid: a pixel is "filled" if it has any non-trivial alpha
        guard let data = context.data else {
            return Array(repeating: Array(repeating: false, count: width), count: height)
        }

        let pointer = data.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)
        var grid = Array(repeating: Array(repeating: false, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                let alpha = pointer[offset + 3]  // Alpha channel is 4th byte
                grid[y][x] = alpha > 30  // Any visible stroke
            }
        }

        return grid
    }

    /// Read pixel data from a grayscale context into a boolean grid.
    /// A pixel is considered "filled" if its gray value is below 128.
    private func extractGrid(from context: CGContext, width: Int, height: Int) -> [[Bool]] {
        guard let data = context.data else {
            return Array(repeating: Array(repeating: false, count: width), count: height)
        }

        let pointer = data.bindMemory(to: UInt8.self, capacity: width * height)
        var grid = Array(repeating: Array(repeating: false, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                let pixel = pointer[y * width + x]
                grid[y][x] = pixel < 128  // Dark pixel = filled
            }
        }

        return grid
    }

    private func countFilled(in grid: [[Bool]]) -> Int {
        grid.reduce(0) { total, row in
            total + row.filter { $0 }.count
        }
    }

    private func countOverlap(gridA: [[Bool]], gridB: [[Bool]]) -> Int {
        var overlap = 0
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                if gridA[y][x], gridB[y][x] {
                    overlap += 1
                }
            }
        }
        return overlap
    }

    private func dilate(_ grid: [[Bool]], radius: Int) -> [[Bool]] {
        guard radius > 0 else { return grid }

        var dilated = grid
        for y in 0..<gridSize {
            for x in 0..<gridSize where grid[y][x] {
                let minY = max(0, y - radius)
                let maxY = min(gridSize - 1, y + radius)
                let minX = max(0, x - radius)
                let maxX = min(gridSize - 1, x + radius)

                for dy in minY...maxY {
                    for dx in minX...maxX where hypot(Double(dx - x), Double(dy - y)) <= Double(radius) {
                        dilated[dy][dx] = true
                    }
                }
            }
        }
        return dilated
    }

    private func harmonicMean(_ a: Double, _ b: Double) -> Double {
        guard a > 0, b > 0 else { return 0 }
        return 2 * a * b / (a + b)
    }
}
