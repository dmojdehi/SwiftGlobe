//
//  ViewController.swift
//  SwiftGlobe-tvOS
//
//  Created by David Mojdehi on 4/11/17.
//  Copyright © 2017 David Mojdehi. All rights reserved.
//

import UIKit
import SceneKit

class ViewController: UIViewController {
    @IBOutlet weak var sceneView : SCNView!
    
    var swiftGlobe = SwiftGlobe()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        sceneView.autoenablesDefaultLighting = false
        sceneView.scene = swiftGlobe.scene
        sceneView.allowsCameraControl = false
        //sceneView.pointOfView = swiftGlobe.cameraNode
        
        self.swiftGlobe.setupInSceneView(self.sceneView, allowPan: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

