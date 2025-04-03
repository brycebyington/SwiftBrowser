//
//  Layout.swift
//  SwiftBrowser
//
//  Created by Bryce Byington on 4/2/25.
//

class Layout {
    let (HSTEP, VSTEP) = (13, 18)
    var tokens: [Node]
    var displayList: [(x: Int, y: Int, word: String, font: String?)]
    
    var cursorX: Int
    var cursorY: Int
    
    var weight: String
    var style: String
    var size: Int
    
    var line: [(x: Int, y: Int, word: String, font: String?)]
    
    init(tokens: [Node]) {
        self.tokens = tokens
        self.displayList = []
        
        self.cursorX = HSTEP
        self.cursorY = VSTEP
        
        self.weight = "normal"
        self.style = "roman"
        self.size = 12
        
        self.line = []
        //recurse(tokens)
        //flush()
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
        else if tag == "br"{
            //flush()
        }
            
    }
    
}
