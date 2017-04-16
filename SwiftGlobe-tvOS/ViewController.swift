//
//  ViewController.swift
//  SwiftGlobe-tvOS
//
//  Created by David Mojdehi on 4/11/17.
//  Copyright © 2017 David Mojdehi. All rights reserved.
//

import UIKit
import SceneKit
import GameController

class ViewController: UIViewController {
    @IBOutlet weak var sceneView : SCNView!
    
    var swiftGlobe = SwiftGlobe()
    var gameController : GCController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.swiftGlobe.setupInSceneView(self.sceneView, allowPan: true)
        
        // detect our wireless controllers
        GCController.startWirelessControllerDiscovery { 
            // 
            self.connectToControllers()

        }
        self.connectToControllers()
        self.registerForGameControllerNotifications()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func registerForGameControllerNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector( ViewController.handleControllerDidConnectNotification(notification:) ), name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector( ViewController.handleControllerDidDisconnectNotification(notification:) ), name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
    }

    func handleControllerDidConnectNotification(notification: NSNotification) {
        print("\(#function)")
        // assign the gameController which is found - will break if more than 1
        gameController = notification.object as! GCController
        // we have a controller so go and setup handlers
        self.setupGCEvents()
        
    }
    
    
    func handleControllerDidDisconnectNotification(notification: NSNotification) {
        // if a controller disconnects we should see it
        print("\(#function)")
        
    }
    

    private func connectToControllers() {
        // iterate over all controllers, making sure they're configured for us
        
        let allOfThem = GCController.controllers()
        var x = 99
        
        for c in GCController.controllers() {
            if let microPad = c.microGamepad {
                microPad.valueChangedHandler = { (gamepad, element) in
                    
                    // we get here when a controller value has changed!
                    
                    var x = 99
                }
            }
            
        }
    }

    func setupGCEvents(){
        //if it is a siri remote
        if let microGamepad = self.gameController.microGamepad {
            print("microGamepad found")
            registermicroGamepadEvents(microGamepad)
        }
    }
    
    // from "Example of Siri Remote Access in Swift" posted to an Apple developer discussion forum
    // from https://forums.developer.apple.com/thread/25440
    func registermicroGamepadEvents( _ microGamepad :GCMicroGamepad){
        print("\(#function)")
        //setup the handlers
        gameController.controllerPausedHandler = { [unowned self] _ in
            //self.pauseGame()
        }
        let buttonHandler: GCControllerButtonValueChangedHandler = {  button, _, pressed in
            print("buttonHandler")
        }
        let movementHandler: GCControllerDirectionPadValueChangedHandler = {  _, xValue, yValue in
            let displacement = float2(x: xValue, y: yValue)
            // we get here for passive swipes on surface
            self.swiftGlobe.cameraGoalLongitude += Double(xValue) / 70.0
            self.swiftGlobe.cameraGoalLatitude += Double(yValue) / 70.0

            print("displacement:\(displacement)")
        }
        
        
        let motionHandler :GCMotionValueChangedHandler = {(motion: GCMotion)->() in
            // we get here for wii-like tilt of the controller itself 
            //print("acc:\(motion.userAcceleration)")
            //print("grav:\(motion.gravity)")
            
            //print("att:\(motion.attitude)") //  not currently support on tvOS
            //print("rot:\(motion.rotationRate)") //  not currently support on tvOS
            
            
        }
        microGamepad.buttonA.pressedChangedHandler = buttonHandler
        microGamepad.buttonX.pressedChangedHandler = buttonHandler
        microGamepad.allowsRotation = true
        microGamepad.dpad.valueChangedHandler = movementHandler
        // ignored error checking, but for example
        gameController.motion?.valueChangedHandler = motionHandler
    }
}

