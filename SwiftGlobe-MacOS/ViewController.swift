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
    
    var swiftGlobe = SwiftGlobe()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.autoenablesDefaultLighting = false
        sceneView.scene = swiftGlobe.scene
        sceneView.allowsCameraControl = false
        //sceneView.pointOfView = swiftGlobe.cameraNode

        self.swiftGlobe.setupInSceneView(self.sceneView, allowPan: true)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    

}

