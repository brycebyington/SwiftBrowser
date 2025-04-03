//
//  HTMLParser.swift
//  SwiftBrowser
//
//  Created by Bryce Byington on 4/1/25.
//

// cool swift feature that lets you conform different classes to a common type
protocol Node {
    var children: [Node] { get }
}

// TextNodes do not have children, so any parent must be an ElementNode
// we assign a children property to TextNode for type conformance, but it will always be empty
class TextNode: Node, CustomStringConvertible {
    var text: String
    var parent: ElementNode?
    var children: [Node] { return [] }
    
    var description: String {
        return text
    }

    init(text: String, parent: ElementNode?) {
        self.text = text
        self.parent = parent
    }
}


// ElementNodes can have either TextNodes or other ElementNodes as children Nodes
class ElementNode: Node, CustomStringConvertible {
    var tag: String
    var attributes: [String: String]
    var parent: ElementNode?
    var children: [Node]
    
    var description: String {
        return "<\(tag)>"
    }

    init(tag: String, attributes: [String: String], parent: ElementNode?) {
        self.tag = tag
        self.attributes = attributes
        self.parent = parent
        self.children = []
    }
}
class HTMLParser {
    var body: String
    var unfinished: [Node] = []
    var SELF_CLOSING_TAGS = [String]()
    var HEAD_TAGS = [String]()

    init(body: String) {
        self.body = body
        self.unfinished = []
        self.SELF_CLOSING_TAGS = [
            "area", "base", "br", "col", "embed", "hr", "img", "input",
            "link", "meta", "param", "source", "track", "wbr",
        ]
        self.HEAD_TAGS = [
            "base", "basefont", "bgsound", "noscript",
            "link", "meta", "title", "style", "script",
        ]
    }
    

    func getAttributes(text: String) -> (
        tag: String, attributes: [String: String]
    ) {
        print("Parsing attributes for \(text)")
        let parts: [String] = text.components(separatedBy: " ")
        let tag: String = parts[0].lowercased()
        var attributes: [String: String] = [:]
        for attrpair in parts.dropFirst() {
            if attrpair.contains("=") {
                /*
                 this one is weird. stackoverflow says split returns a substring object, not a string.
                 apparently it's more memory efficient, so in order to conform to the string type
                 we have to map each substring to String(). thanks Joseph Astrahan!
                 */
                let kv = attrpair.split(separator: "=", maxSplits: 1).map {
                    String($0)
                }
                var (key, value) = (kv[0], kv[1])

                attributes[key.lowercased()] = value
                if value.count > 2
                    && (value.first == "'" || value.first == "\"")
                {
                    value = String(value.dropFirst().dropLast())
                }
            } else {
                attributes[attrpair.lowercased()] = ""
            }
        }
        print("Parsed attributes for \(text): \(attributes)")
        return (tag: tag, attributes: attributes)
    }

    func implicitTags(tag: String) {
        print("Comparing \(tag) to list of unfinished tags \(self.unfinished)")
        while true {
            /*
             compare ElementNode.tag or TextNode.tag (always nil) to list of unfinished tags
             to determine what's been omitted.
             compactMap iterates over each node in self.unfinished and then attempts to
             cast each node to an ElementNode. if successful (if ElementNode), then extract
             the tag property. if the cast fails, then the node is a TextNode by default and
             will return nil. $0 represents each Node in self.unfinished.

             */
            let openTags = self.unfinished.compactMap {
                ($0 as? ElementNode)?.tag
            }
            if openTags == [] && tag != "html" {
                addTag(tag: "html")
            } else if openTags == ["html"]
                && !["head", "body", "/html"].contains(tag)
            {
                if self.HEAD_TAGS.contains(tag) {
                    addTag(tag: "head")
                } else {
                    addTag(tag: "body")
                }
            } else if openTags == ["html", "head"]
                && (!["/head"].contains(tag) && !self.HEAD_TAGS.contains(tag))
            {
                addTag(tag: "/head")
            } else {
                break
            }
        }
    }
    
    func finish() -> ElementNode {
        print("Finishing unfinished tags: \(self.unfinished)")
        while self.unfinished.count > 1 {
            let node: Node = self.unfinished.popLast() as! ElementNode
            let parent = self.unfinished.last as! ElementNode
            parent.children.append(node)
        }
        print("Root ElementNode: \(self.unfinished.last!)")
        return self.unfinished.popLast() as! ElementNode
    }
    
    func parse() -> ElementNode {
        print("Parsing body: \(self.body)")
        var text = ""
        var inTag = false
        for c in self.body {
            if c == "<" {
                inTag = true
                if text.count > 0 {
                    addText(text: text)
                    text = ""
                }
            }
            else if c == ">" {
                inTag = false
                addTag(tag: text)
                text = ""
            }
            else {
                text += String(c)
            }
        }
        if !inTag && text.count > 0 {
            addText(text: text)
        }
        return finish()
    }

    func addText(text: String) {
        print("Constructing TextNode: \(text)")
        // ignore whitespace for now, also String does not have access to isWhitespace so this is necessary
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }
        implicitTags(tag: "")  // in python this is None (nil), but i think empty string works
        guard let parent = self.unfinished.last as? ElementNode else { return } // parent has to be ElementNode
        let newTextNode = TextNode(text: text, parent: parent)
        print("Successfully constructed TextNode: \(text)")
        parent.children.append(newTextNode)
    }

    func addTag(tag: String) {
        print("Constructing ElementNode: \(tag)")
        let (tag, attributes) = getAttributes(text: tag)
        if tag.starts(with: "!") { return }
        implicitTags(tag: tag)
        if tag.starts(with: "/") {
            // if last tag, nothing to close
            if self.unfinished.count == 1 { return }
            // close tag, finish last unfinished node by adding to previous unfinished node in list
            let node = self.unfinished.removeLast()
            guard let parent = self.unfinished.last as? ElementNode else {
                return
            }
            parent.children.append(node)
        } else if self.SELF_CLOSING_TAGS.contains(tag) {
            print("Self-closing tag: \(tag)")
            guard let parent = self.unfinished.last as? ElementNode else {
                return
            }
            let newElementNode = ElementNode(
                tag: tag, attributes: attributes, parent: parent)
            parent.children.append(newElementNode)
        } else {
            let parent = self.unfinished.last as? ElementNode
            let newElementNode = ElementNode(
                tag: tag, attributes: attributes, parent: parent)
            print("Unfinished node added to stack: \(tag)")
            self.unfinished.append(newElementNode)
        }
        print("Successfully constructed ElementNode: \(tag)")
    }
}

// print html tree recursively
func printTree(node: Node, indent: Int = 0) {
    print(String(repeating: " ", count: indent), node)
    for child in node.children {
        printTree(node: child, indent: indent + 2)
    }
}
