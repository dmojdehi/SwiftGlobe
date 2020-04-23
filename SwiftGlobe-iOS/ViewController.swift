//
//  ViewController.swift
//  SwiftGlobe
//
//  Created by David Mojdehi on 4/6/17.
//  Copyright © 2017 David Mojdehi. All rights reserved.
//

import UIKit
import QuartzCore
import SceneKit


class ViewController: UIViewController {

    @IBOutlet weak var sceneView : SCNView!
    
    var swiftGlobe = SwiftGlobe(alignment: .poles)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        swiftGlobe.setupInSceneView(sceneView, forARKit: false, enableAutomaticSpin: true)
        swiftGlobe.addDemoMarkers()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

