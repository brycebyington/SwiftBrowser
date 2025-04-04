//
//  ViewController.swift
//  SwiftBrowser
//
//  Created by Bryce Byington on 4/3/25.
//

import Cocoa

class ViewController: NSViewController {
    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.title = "SwiftBrowser"
    }

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

