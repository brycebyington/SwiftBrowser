//
//  ViewController.swift
//  SwiftBrowser
//
//  Created by Bryce Byington on 4/3/25.
//

import Cocoa

class ViewController: NSViewController {
    @IBOutlet var textView: NSTextView!
    
    override func viewDidAppear() {
        super.viewDidAppear()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.global(qos: .userInitiated).async {
            let browser = BrowserURL(urlString: "http://browser.engineering/")
            if let responseText = browser.request() {
                DispatchQueue.main.async {
                    self.textView.string = responseText
                }
            } else {
                DispatchQueue.main.async {
                    self.textView.string = "Failed to load content."
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

