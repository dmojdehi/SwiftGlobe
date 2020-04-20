//
//  SwiftGlobe.swift
//  SwiftGlobe
//
//  Created by David Mojdehi on 4/6/17.
//  Copyright © 2017 David Mojdehi. All rights reserved.
//

import Foundation
import SceneKit
// for tvOS siri remote access
import GameController
import QuartzCore

let kGlobeRadius = 10.0
let kCameraAltitude = 80.0
let kDefaultCameraFov = CGFloat(30.0)
let kGlowPointAltitude = kGlobeRadius * 1.001
let kGlowPointWidth = CGFloat(0.5)
let kMinLatLonPerUnity = -0.1
let kMaxLatLonPerUnity = 1.1

// Speed of the default spin:  1 revolution in 60 seconds
let kGlobeDefaultRotationSpeedSeconds = 60.0

// Min & Maximum zoom (in degrees)
let kMinFov = CGFloat(4.0)
let kMaxFov = CGFloat(40.0)

// kDragWidthInDegrees  -- The amount to rotate the globe on one edge-to-edge swipe (in degrees)
let kDragWidthInDegrees = 180.0

let kTiltOfEarthsAxisInDegrees = 23.5
let kTiltOfEarthsAxisInRadians = (23.5 * Double.pi) / 180.0

let kSkyboxSize = CGFloat(1000.0)
let kTiltOfEclipticFromGalacticPlaneDegrees = 60.2
let kTiltOfEclipticFromGalacticPlaneRadians = (60.2 * Double.pi) / 180.0


// winter solstice is appx Dec 21, 22, or 23
let kDayOfWinterStolsticeInYear = 356.0
let kDaysInAYear = 365.0

let kAffectedBySpring = 1 << 1

class SwiftGlobe {
    
    
    var sceneView : SCNView?
    var scene = SCNScene()
    var camera = SCNCamera()
    var cameraNode = SCNNode()
    var cameraGoal = SCNNode()
    var skybox = SCNNode()
    var globe = SCNNode()
    var seasonalTilt = SCNNode()
    var userRotation = SCNNode()
    var userTilt = SCNNode()
    var glowingSpots = [SCNNode]()
    var sun = SCNNode()
    
    var lastPanLoc : CGPoint?
    var lastFovBeforeZoom : CGFloat?
#if os(tvOS)
    var gameController : GCController?
#endif

    
    internal init() {
        // make the globe
        let globeShape = SCNSphere(radius: CGFloat(kGlobeRadius) )
        globeShape.segmentCount = 30
        // the texture revealed by diffuse light sources
        
    #if os(OSX)
        globeShape.firstMaterial!.diffuse.contents = "world10800x5400.jpg" //earth-diffuse.jpg"
    #else
        globeShape.firstMaterial!.diffuse.contents = "world2700x1350.jpg" //earth-diffuse.jpg"
    #endif
        
        // TODO: show cities in the dark
        //      - unfortunately using 'emission' isn't sufficient
        //          - it bleeds through in daylight areas, too, leaving little white dots
        //          - apple's 2013 wwdc demo uses emission, but dims the whole scene to show it off (not day/night in the same scene)
        //      - alternative: write a custom shader?
        //          - looks like we can use a Scenekit Shader *modifier* to tweak built-in behavior
        //              see "Use Shader Modifiers to Extend SceneKit Shading":
        //              https://developer.apple.com/reference/scenekit/scnshadable#//apple_ref/occ/intf/SCNShadable
        //              (looks like we'd want to run in the 'lightingModel' stage?)
//        globeShape.firstMaterial!.emission.contents = "earth-emissive.jpg"
//        globeShape.firstMaterial!.reflective.intensity = 0.3
//        globeShape.firstMaterial!.emission.intensity = 0.1
        
        // give us some ambient light (to light the rest of the model)
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, *) {
            ambientLight.intensity = 20.0 // default is 1000!
        }

        
        // the texture revealed by specular light sources
        //globeShape.firstMaterial!.specular.contents = "earth_lights.jpg"
        globeShape.firstMaterial!.specular.contents = "earth-specular.jpg"
        globeShape.firstMaterial!.specular.intensity = 0.2
        //globeShape.firstMaterial!.shininess = 0.1
        
        // the oceans are reflecty & the land is matte
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, *) {
            globeShape.firstMaterial!.metalness.contents = "metalness-1000x500.png"
            globeShape.firstMaterial!.roughness.contents = "roughness-g-w-1000x500.png"
        }
        
        // make the mountains appear taller
        // (gives them shadows from point lights, but doesn't make them stick up beyond the edges)
        globeShape.firstMaterial!.normal.contents = "earth-bump.png"
        globeShape.firstMaterial!.normal.intensity = 0.3
        
        //globeShape.firstMaterial!.reflective.contents = "envmap.jpg"
        //globeShape.firstMaterial!.reflective.intensity = 0.5
        globeShape.firstMaterial!.fresnelExponent = 2
        globe.geometry = globeShape
        
        
        //------------------------------------------
        // make some glowing nodes
        // x: 0.0, y: 0.0, z: 5.05
        let zz = GlobeGlowPoint(lat: 0,lon: 0)
        // make this one white!
        zz.node.geometry!.firstMaterial!.diffuse.contents = "whiteGlow-32x32.png"
        globe.addChildNode(zz.node)
        
        let sf = GlobeGlowPoint(lat: 37.7749,lon: -122.4194)
        let animation = CABasicAnimation(keyPath: "scale")
        animation.fromValue = SCNVector3(x: 0.5, y: 0.5, z: 0.5)
        animation.toValue = SCNVector3(x: 3.0, y: 3.0, z: 3.0)
        animation.duration = 1.0
        animation.autoreverses = true
        animation.repeatCount = Float.infinity
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        sf.node.addAnimation(animation, forKey: "throb")
        globe.addChildNode(sf.node)
        
        let madagascar = GlobeGlowPoint(lat: -18.91368, lon: 47.53613)
        globe.addChildNode(madagascar.node)
        
        let madrid = GlobeGlowPoint(lat: 40.4168, lon: -3.7038)
        globe.addChildNode(madrid.node)

        // a row of dots down the prime meridian
//        for i in stride(from:-90.0, through: 90.0, by: 10.0) {
//            let spot = GlobeGlowPoint(lat: i, lon: 0.0)
//            if i != 0 {
//                seasonalTilt.addChildNode(spot.node)
//            }
//        }

        
        // the globe spins once per minute
        let spinRotation = SCNAction.rotate(by: 2 * .pi, around: SCNVector3(0, 1, 0), duration: kGlobeDefaultRotationSpeedSeconds)
        let spinAction = SCNAction.repeatForever(spinRotation)
        globe.runAction(spinAction)
        

        
        // tilt it on it's axis (23.5 degrees), varied by the actual day of the year
        // (note that children nodes are correctly tilted with the parents coordinate space)
        let calendar = Calendar(identifier: .gregorian)
        let dayOfYear = Double( calendar.ordinality(of: .day, in: .year, for: Date())! )
        let daysSinceWinterSolstice = remainder(dayOfYear + 10.0, kDaysInAYear)
        let daysSinceWinterSolsticeInRadians = daysSinceWinterSolstice * 2.0 * Double.pi / kDaysInAYear
        let tiltXRadians = -cos( daysSinceWinterSolsticeInRadians) * kTiltOfEarthsAxisInRadians
        let tiltTransform : SCNMatrix4
        #if os(iOS) || os(tvOS)
            tiltTransform = SCNMatrix4MakeRotation(Float(tiltXRadians), 0.0, 1.0, 0.0)
        #elseif os(OSX)
            tiltTransform = SCNMatrix4MakeRotation(CGFloat(tiltXRadians), 0.0, 1.0, 0.0)
        #endif

        seasonalTilt.setWorldTransform(tiltTransform)
        
        //----------------------------------------
        // setup the heirarchy:
        //  rootNode
        //     |
        //     +---userTilt
        //           |
        //           +---userRotation
        //                  |
        //                  +---seasonalTilt
        //                        |
        //                        +globe
        //                  +---Sun
        scene.rootNode.addChildNode(userTilt)
          userTilt.addChildNode(userRotation)
            userRotation.addChildNode(seasonalTilt)
              seasonalTilt.addChildNode(globe)

                
        //----------------------------------------
        // setup the sun (the light source)
        sun.position = SCNVector3(x: 0, y:0, z: 200.0)
        sun.light = SCNLight()
        sun.light!.type = .omni
        // sun color temp at noon: 5600.
        // White is 6500
        // anything above 5000 is 'daylight'
        sun.light!.castsShadow = false
        // NB: Dragging & zooming doesn't affect the light falling on the earth
        //     (ie., the sun is contained *within* the userRotation coordinate system)
        userRotation.addChildNode(sun)
        //scene.rootNode.addChildNode(sun)
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, *) {
            sun.light!.temperature = 5600
            sun.light!.intensity = 1200 // default is 1000
        }
        
        //----------------------------------------
        // add the galaxy skybox
        // we make a custom skybox instead of using scene.background) so we can control the galaxy tilt
        let cubemapTextures = ["eso0932a_front.png","eso0932a_right.png",
                                "eso0932a_back.png", "eso0932a_left.png",
                               "eso0932a_top.png", "eso0932a_bottom.png" ]
        let cubemapMaterials = cubemapTextures.map { (name) -> SCNMaterial in
            let material = SCNMaterial()
            material.diffuse.contents = name
            material.isDoubleSided = true
            material.lightingModel = .constant
            return material
        }
        skybox.geometry = SCNBox(width: kSkyboxSize, height: kSkyboxSize, length: kSkyboxSize, chamferRadius: 0.0)
        skybox.geometry!.materials = cubemapMaterials
        skybox.eulerAngles = SCNVector3(x: kTiltOfEclipticFromGalacticPlaneRadians, y: 0.0, z: 0.0 )
        scene.rootNode.addChildNode(skybox)
        

        //---------------------------------------
        // create and add a camera to the scene
        // set up a 'telephoto' shot (to avoid any fisheye effects)
        // (telephoto: narrow field of view at a long distance
        camera.fieldOfView = kDefaultCameraFov
        camera.zFar = 10000
        cameraNode.position = SCNVector3(x: 0, y: 0, z:  kGlobeRadius + kCameraAltitude )
        cameraNode.constraints = [ SCNLookAtConstraint(target: self.globe) ]
        cameraNode.light = ambientLight
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)
    }
    
    deinit {
    #if os(tvOS)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
    #endif
    }

    
    internal func setupInSceneView(_ v: SCNView, allowPan : Bool) {
        // Do any additional setup after loading the view.
        //
        v.autoenablesDefaultLighting = false
        v.scene = self.scene

        v.showsStatistics = true
        
        self.sceneView = v
        
        if allowPan {
            v.allowsCameraControl = false
            #if os(iOS)
                let pan = UIPanGestureRecognizer(target: self, action:#selector(SwiftGlobe.onPanGesture(pan:) ) )
                let pinch = UIPinchGestureRecognizer(target: self, action: #selector(SwiftGlobe.onPinchGesture(pinch:) ) )
                v.addGestureRecognizer(pan)
                v.addGestureRecognizer(pinch)
            #elseif os(tvOS)
                
                NotificationCenter.default.addObserver(self, selector: #selector( SwiftGlobe.handleControllerDidConnectNotification(notification:) ), name: NSNotification.Name.GCControllerDidConnect, object: nil)
                
            #elseif os(OSX)
                let pan = NSPanGestureRecognizer(target: self, action:#selector(SwiftGlobe.onPanGesture(pan:) ) )
                let pinch = NSMagnificationGestureRecognizer(target: self, action: #selector(SwiftGlobe.onPinchGesture(pinch:) ) )
                v.addGestureRecognizer(pan)
                v.addGestureRecognizer(pinch)
            #endif
        } else {
            v.allowsCameraControl = true
            
        }
        

    }
    
#if os(iOS)
    @objc fileprivate func onPanGesture(pan : UIPanGestureRecognizer) {
        // we get here on a tap!
        if let sceneView = self.sceneView {
            let loc = pan.location(in: sceneView)
            
            if pan.state == .began {
                lastPanLoc = loc
            }
            guard pan.numberOfTouches == 1 else { return }

            self.handlePanCommon(loc)

            self.lastPanLoc = loc
        }
    }
    @objc fileprivate func onPinchGesture(pinch: UIPinchGestureRecognizer){
        // update the fov of the camera
        if pinch.state == .began {
            self.lastFovBeforeZoom = self.camera.fieldOfView
        } else {
            if let lastFov = self.lastFovBeforeZoom {
                var newFov = lastFov / CGFloat(pinch.scale)
                if newFov < kMinFov {
                    newFov = kMinFov
                } else if newFov > kMaxFov {
                    newFov = kMaxFov
                }
                
                self.camera.fieldOfView =  newFov
            }
        }
        

    }
#elseif os(tvOS)
    
    // adapted from "Example of Siri Remote Access in Swift" posted to an Apple developer discussion forum
    // at https://forums.developer.apple.com/thread/25440

    
    @objc func handleControllerDidConnectNotification(notification: NSNotification) {
        print("\(#function)")
        // assign the gameController which is found - will break if more than 1
        guard let gameController = notification.object as? GCController else { return }
        
        
        // if it is a siri remote
        guard let microGamepad = self.gameController?.microGamepad else { return }
        print("microGamepad found")
        print("\(#function)")
        //setup the handlers
        
        gameController.controllerPausedHandler = {  _ in
            // handle play/pause
        }
        
        microGamepad.buttonA.pressedChangedHandler = {  button, _, pressed in
            print("button A tapped")
        }
        microGamepad.buttonX.pressedChangedHandler = {  button, _, pressed in
            print("button B tapped")
        }
        
        // get the OLD remote inputs (direction buttons)
        microGamepad.dpad.valueChangedHandler = { [unowned self] _, xValue, yValue in
            //let displacement = float2(x: xValue, y: yValue)
            // we get here for passive swipes on surface
            let loc = CGPoint(x: CGFloat(xValue), y: CGFloat(yValue) )

            self.handlePanCommon( loc )
            
            //print("displacement:\(displacement)")
        }
        
        // TODO get the NEW Siri Remote inputs
        // (This doesn't work for some reason; maybe just the simulator isn't working right?)
        microGamepad.dpad.xAxis.valueChangedHandler = {  [unowned self] _, xValue in
            let yValue = microGamepad.dpad.yAxis.value
            let loc = CGPoint(x: CGFloat(xValue), y: CGFloat(yValue) )
            self.handlePanCommon( loc )
        }
        microGamepad.dpad.yAxis.valueChangedHandler = {  [unowned self] _, yValue in
            let xValue = microGamepad.dpad.yAxis.value
            let loc = CGPoint(x: CGFloat(xValue), y: CGFloat(yValue) )
            self.handlePanCommon( loc )
        }

        // ignored error checking, but for example
//                microGamepad.allowsRotation = true
//                gameController.motion?.valueChangedHandler = {(motion: GCMotion)->() in
//                    // we get here for wii-like tilt of the controller itself
//                    //print("acc:\(motion.userAcceleration)")
//                    //print("grav:\(motion.gravity)")
//                    
//                    //print("att:\(motion.attitude)") //  not currently support on tvOS
//                    //print("rot:\(motion.rotationRate)") //  not currently support on tvOS
//                }
    }
    
    
#elseif os(OSX)

    @objc fileprivate func onPanGesture(pan : NSPanGestureRecognizer) {
        // we get here on a tap!
        guard let sceneView = self.sceneView else { return }
        
        var loc = pan.location(in: sceneView)
        // OSX has inverted Y coords; flip it before passing to handlePanCommon
        loc.y = sceneView.frame.height - loc.y

        if pan.state == .began {
            lastPanLoc = loc
        }
        
        self.handlePanCommon(loc)

        self.lastPanLoc = loc
    }
    
    @objc fileprivate func onPinchGesture(pinch: NSMagnificationGestureRecognizer){
        // update the fov of the camera
        if pinch.state == .began {
            self.lastFovBeforeZoom = self.camera.fieldOfView
        } else {
            if let lastFov = self.lastFovBeforeZoom {
                var newFov = lastFov / CGFloat(pinch.magnification)
                if newFov < kMinFov {
                    newFov = kMinFov
                } else if newFov > kMaxFov {
                    newFov = kMaxFov
                }
                
                self.camera.fieldOfView =  newFov
            }
            
        }
        
    }
#endif
    
    
    private func handlePanCommon(_ loc: CGPoint) {
        guard let lastPanLoc = lastPanLoc else { return }
        guard let sceneView = sceneView else { return }
        
        // measue the movement difference
        let delta = CGSize(width: (lastPanLoc.x - loc.x) / sceneView.frame.width, height: (lastPanLoc.y - loc.y) / sceneView.frame.height )
        
        //  DeltaX = amount of rotation to apply (about the world axis)
        //  DelyaY = amount of tilt to apply (to the axis itself)
        if delta.width != 0.0 || delta.height != 0.0 {
            
            // as the user zooms in (smaller fieldOfView value), the finger travel is reduced
            let fovProportion = (self.camera.fieldOfView - kMinFov) / (kMaxFov - kMinFov)
            let fovProportionRadians = Float(fovProportion * CGFloat(kDragWidthInDegrees) ) * ( .pi / 180)
            let rotationAboutAxis = Float(delta.width) * fovProportionRadians
            let tiltOfAxisItself = Float(delta.height) * fovProportionRadians
            
            // first, apply the rotation
            let rotate = SCNMatrix4RotateF(userRotation.worldTransform, -rotationAboutAxis, 0.0, 1.0, 0.0)
            userRotation.setWorldTransform(rotate)
            
            // now apply the tilt
            let tilt = SCNMatrix4RotateF(userTilt.worldTransform, -tiltOfAxisItself, 1.0, 0.0, 0.0)
            userTilt.setWorldTransform(tilt)
        }
            

    }
    
}



// simple extension to reduce platform-specific #if's (for some reason SCNVector uses CGFloat on macOS)
extension SCNVector3 {
    init(x: Double, y: Double, z:Double ){
        #if os(iOS) || os(tvOS)
            self.init(x: Float(x), y: Float(y), z: Float(z))
        #elseif os(OSX)
            self.init(x: CGFloat(x), y: CGFloat(y), z: CGFloat(z))
        #endif
    }
}

func SCNMatrix4RotateF(_ src: SCNMatrix4, _ angle : Float, _ x : Float, _ y : Float, _ z : Float) -> SCNMatrix4 {
    #if os(iOS) || os(tvOS)
        return SCNMatrix4Rotate(src, angle, x, y, z)
    #elseif os(OSX)
        return SCNMatrix4Rotate(src, CGFloat(angle), CGFloat(x), CGFloat(y), CGFloat(z))
    #endif

}


// code to encapsulate individual glow points
// (extend this to get different glow effects)
class GlobeGlowPoint {
    var latitude = 0.0
    var longitude = 0.0
    
    // the node of this point (must be added to the scene)
    fileprivate var node : SCNNode!
    
    init(lat: Double, lon: Double) {
        self.latitude = lat
        self.longitude = lon
        
        self.node = SCNNode(geometry: SCNPlane(width: kGlowPointWidth, height: kGlowPointWidth) )
        self.node.geometry!.firstMaterial!.diffuse.contents = "yellowGlow-32x32.png"
        // appear a little washed out in daylight...
        self.node.geometry!.firstMaterial!.diffuse.intensity = 0.2
        self.node.geometry!.firstMaterial!.emission.contents = "yellowGlow-32x32.png"
        // but brigheter in dark areas
        self.node.geometry!.firstMaterial!.emission.intensity = 0.7
        self.node.castsShadow = false
        
        // NB: our textures *center* on 0,0, so adjust by 90 degrees
        let adjustedLon = lon + 90
        
        // convert lat & lon to xyz
        // Note scenekit coordinate space:
        //      Camera looks  down the Z axis (down from +z)
        //      Right is +x, left is -x
        //      Up is +y, down is -y
        let cosLat = cos(lat * Double.pi / 180.0)
        let sinLat = sin(lat * Double.pi / 180.0);
        let cosLon = cos(adjustedLon * Double.pi / 180.0);
        let sinLon = sin(adjustedLon * Double.pi / 180.0);
        let x = kGlowPointAltitude * cosLat * cosLon;
        let y = kGlowPointAltitude * cosLat * sinLon;
        let z = kGlowPointAltitude * sinLat;
        //
        let sceneKitX = -x
        let sceneKitY = z
        let sceneKitZ = y
        
        //print("convered lat: \(lat) lon: \(lon) to \(sceneKitX),\(sceneKitY),\(sceneKitZ)")
        
        let pos = SCNVector3(x: sceneKitX, y: sceneKitY, z: sceneKitZ )
        self.node.position = pos
        
        
        // and compute the normal pitch, yaw & roll (facing away from the globe)
        //1. Pitch (the x component) is the rotation about the node's x-axis (in radians)
        let pitch = -lat * Double.pi / 180.0
        //2. Yaw   (the y component) is the rotation about the node's y-axis (in radians)
        let yaw = lon * Double.pi / 180.0
        //3. Roll  (the z component) is the rotation about the node's z-axis (in radians)
        let roll = 0.0
        
        
        self.node.eulerAngles = SCNVector3(x: pitch, y: yaw, z: roll )
        
    }
    
}
