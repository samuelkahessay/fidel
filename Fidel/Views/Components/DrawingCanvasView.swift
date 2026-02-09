import SwiftUI
import PencilKit

/// A SwiftUI wrapper around PKCanvasView for finger-based character drawing.
struct DrawingCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var penWidth: CGFloat = 15
    private let inkColor = UIColor.systemIndigo.withAlphaComponent(0.42)

    private func makeTool() -> PKInkingTool {
        PKInkingTool(.marker, color: inkColor, width: penWidth)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.tool = makeTool()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Update pen width when slider changes
        canvas.tool = makeTool()

        // Sync drawing from SwiftUI state to UIKit (e.g. clear or undo)
        if drawing.strokes.count != canvas.drawing.strokes.count {
            context.coordinator.isSyncing = true
            canvas.drawing = drawing
            context.coordinator.isSyncing = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var drawing: Binding<PKDrawing>
        var isSyncing = false

        init(drawing: Binding<PKDrawing>) {
            self.drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isSyncing else { return }
            drawing.wrappedValue = canvasView.drawing
        }
    }
}
