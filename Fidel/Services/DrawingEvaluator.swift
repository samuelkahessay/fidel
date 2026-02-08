import UIKit
import PencilKit

/// Evaluates user drawings against reference character paths using IoU similarity.
final class DrawingEvaluator {
    static let shared = DrawingEvaluator()

    /// Grid resolution for rasterization comparison
    private let gridSize = 32

    /// Minimum IoU score to pass (generous for finger drawing on small screens)
    let passThreshold: Double = 0.08

    private init() {}

    /// Result of evaluating a user's drawing against a reference path.
    enum DrawingResult {
        case needsRetry(score: Double)
        case passedForReview(score: Double)
    }

    /// Evaluate a user's PKDrawing against a reference CGPath.
    /// Both are rasterized to a 32×32 grid and compared via IoU.
    func evaluate(drawing: PKDrawing, referencePath: CGPath, canvasSize: CGSize) -> DrawingResult {
        let referenceGrid = rasterizePath(referencePath, canvasSize: canvasSize)
        let drawingGrid = rasterizeDrawing(drawing, canvasSize: canvasSize)
        let score = calculateIoU(gridA: referenceGrid, gridB: drawingGrid)

        if score >= passThreshold {
            return .passedForReview(score: score)
        } else {
            return .needsRetry(score: score)
        }
    }

    // MARK: - Private

    /// Rasterize a CGPath to a boolean grid by filling it into a bitmap context.
    /// Uses fill since Noto Sans Ethiopic has uniform stroke width that fills cleanly,
    /// matching the filled guide shape the user traces over.
    private func rasterizePath(_ path: CGPath, canvasSize: CGSize) -> [[Bool]] {
        let width = gridSize
        let height = gridSize

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
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
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
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

    /// Calculate Intersection over Union for two boolean grids.
    private func calculateIoU(gridA: [[Bool]], gridB: [[Bool]]) -> Double {
        var intersection = 0
        var union = 0

        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let a = gridA[y][x]
                let b = gridB[y][x]
                if a && b { intersection += 1 }
                if a || b { union += 1 }
            }
        }

        guard union > 0 else { return 0 }
        return Double(intersection) / Double(union)
    }
}
