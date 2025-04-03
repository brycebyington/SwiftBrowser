//
//  ViewController.swift
//  SwiftBrowser
//
//  Created by Bryce Byington on 4/3/25.
//

import Cocoa
import AppKit
import CoreText

final class LabelView: NSView {
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let text = "Hello, World!"
        let attributedString = NSAttributedString(string: text)
        let ctLine = CTLineCreateWithAttributedString(attributedString)
        
        context.textPosition = CGPoint(x: 0, y: bounds.height)
        CTLineDraw(ctLine, context)
        
    }
}

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        super.view.addSubview(LabelView())
        
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

