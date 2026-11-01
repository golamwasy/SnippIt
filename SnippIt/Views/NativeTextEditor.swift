import SwiftUI
import AppKit

struct TextPosition: Equatable {
    var line = 1
    var column = 1
}

/// UTF-16 offsets match AppKit's selection and glyph APIs, including non-ASCII text.
struct TextLineMap {
    let text: String
    let starts: [Int]

    init(_ text: String) {
        self.text = text
        let string = text as NSString
        var starts = [0]
        var index = 0
        while index < string.length {
            var end = 0
            var contentsEnd = 0
            string.getLineStart(nil, end: &end, contentsEnd: &contentsEnd,
                                for: NSRange(location: index, length: 0))
            if end > contentsEnd { starts.append(end) }
            guard end > index else { break }
            index = end
        }
        self.starts = starts
    }

    func lineIndex(at offset: Int) -> Int {
        var low = 0
        var high = starts.count
        while low < high {
            let middle = (low + high) / 2
            if starts[middle] <= offset { low = middle + 1 }
            else { high = middle }
        }
        return max(0, low - 1)
    }

    func position(at offset: Int) -> TextPosition {
        let string = text as NSString
        let offset = min(max(0, offset), string.length)
        let index = lineIndex(at: offset)
        let prefix = string.substring(with: NSRange(location: starts[index], length: offset - starts[index]))
        return TextPosition(line: index + 1, column: prefix.count + 1)
    }
}

struct NativeTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var position: TextPosition
    var fontSize: Double
    var showsLineNumbers: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.clipsToBounds = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        // TextKit 1 exposes the line fragments used to align the custom gutter.
        let textView = NoteTextView(usingTextLayoutManager: false)
        textView.frame = scrollView.contentView.bounds
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .textColor
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.string = text
        textView.setAccessibilityIdentifier("noteEditor")
        textView.setAccessibilityLabel("Note text")
        textView.delegate = context.coordinator
        scrollView.documentView = textView

        let ruler = LineNumberRuler(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = showsLineNumbers
        context.coordinator.ruler = ruler
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.font?.pointSize != CGFloat(fontSize) {
            textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
            context.coordinator.ruler?.needsDisplay = true
        }
        if scrollView.rulersVisible != showsLineNumbers {
            scrollView.rulersVisible = showsLineNumbers
        }
        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            // The note changed outside this editor. Old undo ranges are no longer valid.
            textView.undoManager?.removeAllActions()
            context.coordinator.ruler?.updateLines()
            textView.setSelectedRange(NSRange(location: min(selection.location, (text as NSString).length), length: 0))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeTextEditor
        weak var ruler: LineNumberRuler?

        init(_ parent: NativeTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            ruler?.updateLines()
            updatePosition(textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            updatePosition(textView)
        }

        private func updatePosition(_ textView: NSTextView) {
            let map = ruler?.lineMap ?? TextLineMap(textView.string)
            let position = map.position(at: textView.selectedRange().location)
            // Selection notifications may occur during a SwiftUI view update.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.parent.position != position { self.parent.position = position }
            }
            ruler?.needsDisplay = true
        }
    }
}

final class NoteTextView: NSTextView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window, self.window === window else { return }
            window.makeFirstResponder(self)
        }
    }
}

final class LineNumberRuler: NSRulerView {
    private weak var textView: NSTextView?
    private(set) var lineMap: TextLineMap
    private let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    private var observers: [NSObjectProtocol] = []

    override var isFlipped: Bool { true }

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        lineMap = TextLineMap(textView.string)
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clipsToBounds = true
        clientView = textView
        textView.postsFrameChangedNotifications = true
        scrollView.contentView.postsBoundsChangedNotifications = true
        for (name, object) in [
            (NSView.boundsDidChangeNotification, scrollView.contentView),
            (NSView.frameDidChangeNotification, textView)
        ] {
            observers.append(NotificationCenter.default.addObserver(
                forName: name, object: object, queue: .main
            ) { [weak self] _ in self?.needsDisplay = true })
        }
        updateLines()
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    func updateLines() {
        guard let textView else { return }
        lineMap = TextLineMap(textView.string)
        let width = ("\(lineMap.starts.count)" as NSString)
            .size(withAttributes: [.font: numberFont]).width
        let thickness = max(48, ceil(width) + 26)
        if ruleThickness != thickness { ruleThickness = thickness }
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height).fill()

        guard let textView, let layout = textView.layoutManager,
              let container = textView.textContainer else { return }
        let inset = textView.textContainerInset
        let visible = textView.visibleRect.offsetBy(dx: -inset.width, dy: -inset.height)
        layout.ensureLayout(forBoundingRect: visible, in: container)
        let glyphs = layout.glyphRange(forBoundingRect: visible, in: container)
        let firstCharacter = glyphs.location < layout.numberOfGlyphs
            ? layout.characterIndexForGlyph(at: glyphs.location) : (textView.string as NSString).length
        let firstLine = lineMap.lineIndex(at: firstCharacter)
        let selectedLine = lineMap.lineIndex(at: textView.selectedRange().location)
        let length = (textView.string as NSString).length

        for index in firstLine..<lineMap.starts.count {
            let start = lineMap.starts[index]
            let lineRect: NSRect
            if start < length {
                let glyph = layout.glyphIndexForCharacter(at: start)
                lineRect = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            } else {
                lineRect = layout.extraLineFragmentRect
            }
            let height = lineRect.height > 0 ? lineRect.height
                : layout.defaultLineHeight(for: textView.font ?? numberFont)
            let origin = convert(NSPoint(x: 0, y: lineRect.minY + inset.height), from: textView)
            if origin.y > bounds.maxY { break }
            if origin.y + height < bounds.minY { continue }
            let label = "\(index + 1)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: numberFont,
                .foregroundColor: index == selectedLine ? NSColor.labelColor : NSColor.secondaryLabelColor
            ]
            let size = label.size(withAttributes: attributes)
            label.draw(
                at: NSPoint(x: ruleThickness - size.width - 12,
                            y: origin.y + (height - size.height) / 2),
                withAttributes: attributes
            )
        }
    }
}
