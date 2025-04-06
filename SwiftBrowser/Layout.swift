//
//  Layout.swift
//  SwiftBrowser
//
//  Created by Bryce Byington on 4/2/25.
//

import CoreText
import Foundation

struct FontKey: Hashable {
    let size : Int
    let weight, style: String
}

struct FontValue: Hashable {
    let _font: CTFont
    let label: String
}

func measureStringWidth(text: String, _font: CTFont) -> CGFloat {
    // use the current font to create the attributes object
    let attributes: [NSAttributedString.Key: Any] = [
        .font: _font
    ]
    // create attributedString with text and attributes
    let attributedString = NSAttributedString(string: text, attributes: attributes)
    // create line
    let line = CTLineCreateWithAttributedString(attributedString)
    // get the width of the line, do not need other typographic bounds for now
    // (ascent, descent, leading)
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    return CGFloat(width)
}

func getFontMetrics(word: String, _font: CTFont) -> (ascent: CGFloat, descent: CGFloat, leading: CGFloat) {
    
    let attributes: [NSAttributedString.Key: Any] = [
        .font: _font
    ]
    let attributedString = NSAttributedString(string: word, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attributedString)
    
    var ascent: CGFloat = 0.0
    var descent: CGFloat = 0.0
    var leading: CGFloat = 0.0
    // get typographic bounds for given line of text, update metrics and return
    CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
    return (ascent, descent, leading)
}

class Layout {
    let (HSTEP, VSTEP) = (13, 18)
    let (WIDTH, HEIGHT) = (800, 600)
    var FONTS: [FontKey : FontValue] = [:]
    var tokens: Node
    var displayList: [(x: Int, y: Int, word: String, _font: CTFont)]
    
    var cursorX, cursorY: Int
    
    var weight, style: String
    var size: Int
    
    var line: [(x: Int, word: String, font: CTFont)]
    
    init(tokens: Node) {
        self.tokens = tokens
        self.displayList = []
        
        self.cursorX = HSTEP
        self.cursorY = VSTEP
        
        self.weight = "normal"
        self.style = "roman"
        self.size = 12
        
        self.line = []
        recurse(tree: tokens)
        flush()
    }
    
    func getFont(size: Int, weight: String, style: String) -> CTFont {
        let key = FontKey(size: size, weight: weight, style: style)
        
        if FONTS[key] == nil {
            let fontName = "Helvetica"
            // create the new font object with its size, hard-coding Helvetica for now
            let ctFont = CTFontCreateWithName(fontName as CFString, CGFloat(size), nil)
            let label = "\(fontName) \(size)"
            FONTS[key] = FontValue(_font: ctFont, label: label)
        }
        return FONTS[key]!._font
    }
    
    func flush() {
        if self.line.isEmpty { return }
        var metrics: [(ascent: CGFloat, descent: CGFloat, leading: CGFloat)] = []
        for (_, word, _font) in self.line {
            metrics.append(getFontMetrics(word: word, _font: _font))
        }
        let maxAscent = metrics.map({ $0.ascent }).max()!
        let baseline = CGFloat(cursorY) + 1.25 * maxAscent
        
        for (x, word, _font) in self.line {
            let y = baseline - getFontMetrics(word: word, _font: _font).ascent
            self.displayList.append((x, Int(y), word, _font))
        }
        let maxDescent = metrics.map({$0.descent}).max()!
        self.cursorY = Int(baseline + 1.25 * maxDescent)
        self.cursorX = HSTEP
        self.line = []
        
    }
    
    func word(word: String) {
        let _font: CTFont = getFont(size: self.size, weight: self.weight, style: self.style)
        // using the font object, measure the line width given some text
        let width = measureStringWidth(text: word, _font: _font)
        if self.cursorX + Int(width) > WIDTH - HSTEP {
            flush()
        }
        self.line.append((self.cursorX, word, _font))
        self.cursorX += Int(width + measureStringWidth(text: " ", _font: _font))
        
    }
    
    func recurse(tree: Node) {
        if let textNode = tree as? TextNode {
            for token in textNode.text.split(separator: " ") {
                word(word: String(token))
            }
        } else if let elementNode = tree as? ElementNode {
            openTag(tag: elementNode.tag)
            for child in elementNode.children {
                recurse(tree: child)
            }
            closeTag(tag: elementNode.tag)
        }
    }
    
    func openTag(tag: String) {
        if tag == "i" {
            self.style = "italic"
        }
        else if tag == "b" {
            self.weight = "bold"
        }
        else if tag == "small" {
            self.size -= 2
        }
        else if tag == "big" {
            self.size += 2
        }
        else if tag == "br" {
            flush()
        }
            
    }
    
    func closeTag(tag: String) {
        if tag == "/i" {
            self.style = "roman"
        }
        else if tag == "/b" {
            self.weight = "normal"
        }
        else if tag == "/small" {
            self.size += 2
        }
        else if tag == "/big" {
            self.size -= 2
        }
        else if tag == "/p" {
            flush()
            cursorY += VSTEP
        }
    }
    
}
