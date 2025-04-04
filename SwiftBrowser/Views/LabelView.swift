//
//  LabelView.swift
//  SwiftBrowser
//
//  Created by Bryce Byington on 4/3/25.
//
import Cocoa
import CoreText

// prevent this class from being subclassed and protect its methods from being overriden
final class LabelView: NSView {
    // initialize a new NSView...
    override init(frame: CGRect) {
        // ...then initialize its parent NSView using super.init
        super.init(frame: frame)
    }
    
    /*  subclass (LabelView) needs to conform to its superclass (NSView).
        NSView conforms to the NSCoder protocol, which requires that a
        coder be initialized to translate (decode) storyboard code.
        if the superclass already references fatalError,
        we can just initialize its superclass with the decoder to reference it below.
     */
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /*
        dirtyRect: rectangle defining part of view that requires redrawing.
        helps with performance by specifying the portion of the view that needs drawn.
     */
    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)
        
        /*
            context: a CoreGraphics context that represents a 'Quartz2D' drawing destination.
            a graphics context contains drawing parameters and device specific
            information about the paint destination
            Quartz2D: a 2D rendering API part of the CoreGraphics framework
         */
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let text = "Hello, World!"
        
        // set text attributes, this will be useful after extracting attributes from html
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 16)
            ]
        
        // attributedString: a representation of text and its attributes like font, size, etc.
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        // creates an immutable line object from attributedString
        let ctLine = CTLineCreateWithAttributedString(attributedString)
        
        // create descent and leading variables...
        var descent: CGFloat = 0.0
        var leading: CGFloat = 0.0
        
        // ...then get the typographic bounds with their pointers as parameters.
        // descent and leading are then set to their appropriate values
        CTLineGetTypographicBounds(ctLine, nil, &descent, &leading)
        
        // saves graphics state parameters including font, size, color etc.
        context.saveGState()
        
        // position the text and draw to the CoreGraphics context (destination)
        context.textPosition = CGPoint(x: 0, y: bounds.height + descent + leading)
        CTLineDraw(ctLine, context)
        
    }
}
