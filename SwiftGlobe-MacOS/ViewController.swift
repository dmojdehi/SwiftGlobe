//
//  ViewController.swift
//  SwiftGlobe-MacOS
//
//  Created by David Mojdehi on 4/6/17.
//  Copyright © 2017 Mindful Bear Apps. All rights reserved.
//

import Cocoa
import SceneKit

class ViewController: NSViewController {

    @IBOutlet weak var sceneView : SCNView!
    
    var swiftGlobe = SwiftGlobe()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.autoenablesDefaultLighting = true
        sceneView.scene = swiftGlobe.scene
        sceneView.allowsCameraControl = true

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

