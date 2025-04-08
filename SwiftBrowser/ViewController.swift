//
//  ViewController.swift
//  SwiftBrowser
//
//  Created by Bryce Byington on 4/3/25.
//

import Cocoa
import CoreText
import Foundation

class BrowserView: NSView {
    // flip the coordinate system so that the origin point is at the top-left
    override var isFlipped: Bool { return true }

    var layout: Layout?

    init(frame: NSRect, layout: Layout) {
        self.layout = layout
        super.init(frame: frame)
    }

    // required by superclass NSView
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func draw(_ dirtyRect: NSRect) {
        // dirtyRect is a rectange that defines the portion of a view that requires updating
        super.draw(dirtyRect)
        // the page layout, which is calculated after parsing the html
        guard let layout = layout,
            // the current graphical context, which we are going to draw to
            let context = NSGraphicsContext.current?.cgContext
        else { return }

        // flip the text matrix since text was upside-down
        context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)

        // iterate over each item in the displayList and draw each word with its parsed font
        for item in layout.displayList {
            // get the CTFont object from the displayList
            let ctFont = item._font
            let fontName = CTFontCopyPostScriptName(ctFont) as String
            let fontSize = CTFontGetSize(ctFont)
            // create the new font object
            let nsFont =
                NSFont(name: fontName, size: fontSize)
                ?? NSFont.systemFont(ofSize: fontSize)

            // create the attributes to apply to the word
            let attributes: [NSAttributedString.Key: Any] = [
                .font: nsFont,
                .foregroundColor: NSColor.labelColor,
            ]
            // create an attributedString, which includes the text and its font attributes
            let attributedString = NSAttributedString(
                string: item.word, attributes: attributes)
            // create the line of text
            let line = CTLineCreateWithAttributedString(attributedString)

            // grab the descent value of the cont and subtract it from the y position
            let descent = CTFontGetDescent(ctFont)
            let ascent = CTFontGetAscent(ctFont)
            // use displayList's x and y coordinates to position the text and draw to the current context
            // to be honest i have no idea why the text position is shifted down VSTEP (18) * 2, but adding 36 fixes it
            // EXCEPT when i wrappped it with a scrollview, then the problem went away i guess
            context.textPosition = CGPoint(
                x: CGFloat(item.x),
                y: CGFloat(item.y) + CGFloat(descent)
                    - CGFloat(ascent) /*+ 36*/)
            CTLineDraw(line, context)
        }
    }
}

class ViewController: NSViewController {

    override func viewDidAppear() {
        super.viewDidAppear()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.global(qos: .userInitiated).async {
            let browser = BrowserURL(urlString: "https://browser.engineering/html.html")
            if let layout = browser.request() {
                DispatchQueue.main.async {
                    let maxYPositionOfText = layout.displayList.map({ $0.y })
                        .max()
                    let pageHeight = CGFloat(maxYPositionOfText!)

                    let browserView = BrowserView(
                        frame: NSRect(
                            x: 0, y: 0, width: 800, height: pageHeight),
                        layout: layout)
                    let scrollView = NSScrollView(frame: self.view.bounds)

                    scrollView.autoresizingMask = [.width, .height]
                    scrollView.hasVerticalScroller = true
                    scrollView.documentView = browserView

                    self.view.addSubview(scrollView)
                }
            } else {
                DispatchQueue.main.async {
                    print("loading failed")
                }
            }
        }

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}
