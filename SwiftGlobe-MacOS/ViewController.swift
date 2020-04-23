//
//  ViewController.swift
//  SwiftGlobe-MacOS
//
//  Created by David Mojdehi on 4/6/17.
//  Copyright © 2017 David Mojdehi. All rights reserved.
//

import Cocoa
import SceneKit

class ViewController: NSViewController {

    @IBOutlet weak var sceneView : SCNView!
    
    var swiftGlobe = SwiftGlobe(alignment: .dayNightTerminator)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        swiftGlobe.setupInSceneView(self.sceneView, forARKit: false, enableAutomaticSpin: true)
        swiftGlobe.addDemoMarkers()
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    

}

