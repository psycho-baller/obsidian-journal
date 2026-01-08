import SwiftUI
import UIKit

/// A UITextView wrapper that exposes cursor position for text injection.
/// Adapted from AudioRecorderPavanKumar inspiration.
struct CursorAwareTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var cursorPosition: Int
    var onTextChange: (() -> Void)?
    var isEditable: Bool = true

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 100, right: 16) // Bottom padding for FAB
        textView.isScrollEnabled = true
        textView.keyboardDismissMode = .interactive
        textView.returnKeyType = .default
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.isEditable = isEditable

        // Only update text if it actually changed to prevent loops and cursor jumps
        if uiView.text != text {
            uiView.text = text
            // If text completely replaced (e.g. switching drafts), reset cursor?
            // Or keep it safe.
            /*
            let safeLength = text.count
            let safeCursor = min(cursorPosition, safeLength)
             */
        }

        // Handle external cursor updates if necessary (e.g. precise insertion flow)
        // But usually we trust the View to drive this from the Delegate.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CursorAwareTextEditor

        init(_ parent: CursorAwareTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            // Update bindings
            parent.text = textView.text
            if let range = textView.selectedTextRange {
                let location = textView.offset(from: textView.beginningOfDocument, to: range.start)
                parent.cursorPosition = location
            }
            parent.onTextChange?()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if let range = textView.selectedTextRange {
                let location = textView.offset(from: textView.beginningOfDocument, to: range.start)
                parent.cursorPosition = location
            }
        }
    }
}
