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

    var lastPanLoc : NSPoint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.autoenablesDefaultLighting = false
        sceneView.scene = swiftGlobe.scene
        sceneView.allowsCameraControl = false
        //sceneView.pointOfView = swiftGlobe.cameraNode

        // Do any additional setup after loading the view.
        let pan = NSPanGestureRecognizer(target: self, action:#selector(ViewController.onPanGesture(pan:) ) )
        self.sceneView.addGestureRecognizer(pan)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func onPanGesture(pan : NSPanGestureRecognizer) {
        // we get here on a tap!
        let loc = pan.location(in: sceneView)
        
        //
        if pan.state == .began {
            self.lastPanLoc = loc
        } else if let lastPanLoc = self.lastPanLoc {
            // measue the movement difference
            let delta = NSMakeSize(lastPanLoc.x - loc.x, lastPanLoc.y - loc.y)
            self.swiftGlobe.cameraGoalLatitude -= Double(delta.height) / 100.0
            // vertical delta should move the camera goal along the 
        }
        
        
        self.lastPanLoc = loc
    }


}

