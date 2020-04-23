//
//  InterfaceController.swift
//  SwiftGlobe-Watch Extension
//
//  Created by David Mojdehi on 4/21/20.
//  Copyright © 2020 David Mojdehi. All rights reserved.
//

import WatchKit
import Foundation
import SceneKit

class InterfaceController: WKInterfaceController, WKCrownDelegate {
    @IBOutlet var scnInterface: WKInterfaceSCNScene!

    @IBOutlet var panGesture: WKPanGestureRecognizer!
    
    var swiftGlobe = SwiftGlobe(alignment: .poles)

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        crownSequencer.delegate = self
        
        // Create a new scene
        let scene = SCNScene()
        self.scnInterface.scene = scene
        swiftGlobe.setupInSceneView(scnInterface, forARKit: false, enableAutomaticSpin: true)

//        let scene = SCNScene(named: "art.scnassets/ship.scn")!
//
//        // Create and add a camera to the scene
//        let cameraNode = SCNNode()
//        cameraNode.camera = SCNCamera()
//        scene.rootNode.addChildNode(cameraNode)
//
//        // Place the camera
//        cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)
//
//        // Create and add a light to the scene
//        let lightNode = SCNNode()
//        lightNode.light = SCNLight()
//        lightNode.light!.type = .omni
//        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
//        scene.rootNode.addChildNode(lightNode)
//
//        // Create and add an ambient light to the scene
//        let ambientLightNode = SCNNode()
//        ambientLightNode.light = SCNLight()
//        ambientLightNode.light!.type = .ambient
//        ambientLightNode.light!.color = UIColor.darkGray
//        scene.rootNode.addChildNode(ambientLightNode)
//
//        // Retrieve the ship node
//        let ship = scene.rootNode.childNode(withName: "ship", recursively: true)!
//
//        // Animate the 3d object
//        ship.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 2, z: 0, duration: 1)))
//
//        // Set the scene to the view
//        self.scnInterface.scene = scene
        
        // hide statistics such as fps and timing information (for now)
        self.scnInterface.showsStatistics = false
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        // to send us values the crown must have focus 
        crownSequencer.focus()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    @IBAction func panRecognized(_ sender: WKPanGestureRecognizer) {
        let screenBounds = WKInterfaceDevice.current().screenBounds
        let loc = sender.locationInObject()
        if sender.state == .began {
            swiftGlobe.handlePanBegan(loc)
        } else {
            swiftGlobe.handlePanCommon( loc, viewSize: screenBounds.size)
        }
    }
    
    func crownDidRotate(_ crownSequencer: WKCrownSequencer?, rotationalDelta: Double) {
        swiftGlobe.zoomFov -= CGFloat(rotationalDelta * 15.0)
    }

}
