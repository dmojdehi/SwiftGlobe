//
//  SwiftGlobe.swift
//  SwiftGlobe
//
//  Created by David Mojdehi on 4/6/17.
//  Copyright © 2017 David Mojdehi. All rights reserved.
//

import Foundation
import SceneKit
#if os(watchOS)
import WatchKit
import SwiftUI
#else
import QuartzCore
// for tvOS siri remote access
import GameController
#endif

// In ARKit, 1.0 = 1 meter
let kGlobeRadius = Float(0.5)
let kCameraAltitude = Float(2.2)
let kGlowPointAltitude = Float(kGlobeRadius * 1.001)
let kDistanceToTheSun = Float(200)

let kDefaultCameraFov = CGFloat(60.0)
let kGlowPointWidth = CGFloat(0.025)
let kMinLatLonPerUnity = -0.1
let kMaxLatLonPerUnity = 1.1

// Speed of the default spin:  1 revolution in 60 seconds
let kGlobeDefaultRotationSpeedSeconds = 60.0

// Min & Maximum zoom (in degrees)
#if os(watchOS)
// on the watch, don't zoom in too much
let kMinFov = CGFloat(10.0)
// nor should we zoom out so much
let kMaxFov = CGFloat(30.0)
#else
let kMinFov = CGFloat(4.0)
let kMaxFov = CGFloat(60.0)
#endif

let kAmbientLightIntensity = CGFloat(20.0) // default is 1000!

// kDragWidthInDegrees  -- The amount to rotate the globe on one edge-to-edge swipe (in degrees)
let kDragWidthInDegrees = 180.0

let kTiltOfEarthsAxisInDegrees = 23.5
let kTiltOfEarthsAxisInRadians = (23.5 * Double.pi) / 180.0

let kSkyboxSize = CGFloat(1000.0)
let kTiltOfEclipticFromGalacticPlaneDegrees = 60.2
let kTiltOfEclipticFromGalacticPlaneRadians = Float( (60.2 * Float.pi) / 180.0)


// winter solstice is appx Dec 21, 22, or 23
let kDayOfWinterStolsticeInYear = 356.0
let kDaysInAYear = 365.0

let kAffectedBySpring = 1 << 1

class SwiftGlobe {
    
    
#if os(watchOS)
#else
    var gestureHost : SCNView?
#endif
    
    var scene = SCNScene()
    var camera = SCNCamera()
    var cameraNode = SCNNode()
    var skybox = SCNNode()
    var globe = SCNNode()
    var seasonalTilt = SCNNode()
    var userTiltAndRotation = SCNNode()
    var sun = SCNNode()
    let globeShape = SCNSphere(radius: CGFloat(kGlobeRadius) )

    var lastPanLoc : CGPoint?
    var lastFovBeforeZoom : CGFloat?
#if os(tvOS)
    var gameController : GCController?
#endif
    var userTiltRadians = Float(0)
    var userRotationRadians = Float(0)
    
    
    var upDownAlignment : UpDownAlignment


    enum UpDownAlignment {
        case poles
        case dayNightTerminator
    }
    
    internal init(alignment: UpDownAlignment) {
        // make the globe
        globeShape.segmentCount = 30
        // the texture revealed by diffuse light sources
        
        upDownAlignment = alignment
        
        // Use a higher resolution image on macOS
        guard let earthMaterial = globeShape.firstMaterial else { assert(false); return }
    #if os(OSX)
        earthMaterial.diffuse.contents = "world-ultra.jpg" //earth-diffuse.jpg"
    #else
        earthMaterial.diffuse.contents = "world-large.jpg" //earth-diffuse.jpg"
    #endif
        
        // TODO: show cities in the dark
        // - use a Scenekit Shader *modifier* to tweak built-in behavior
        //     - good example here https://stackoverflow.com/a/48119057
        //     - see "Use Shader Modifiers to Extend SceneKit Shading":
        //         https://developer.apple.com/reference/scenekit/scnshadable#//apple_ref/occ/intf/SCNShadable
        // - selfIllumination works, but is weak, & hard to balance with ambient
        //     - alpha seems to be ignored
        //     - earth-selfIllumuniation.jpg has lighting 00-7f
        //         - pixels 00-7f will be lit at night
        //         - pixels 80-ff will be lit during the daytime too
        // - unfortunately using 'emission' isn't sufficient
        //         - it bleeds through in daylight areas, too, leaving little white dots
        //         - apple's 2013 wwdc demo uses emission, but dims the whole scene to show it off (not day/night in the same scene)

        let emission = SCNMaterialProperty()
        emission.contents = "earth-emissive.jpg"
        earthMaterial.setValue(emission, forKey: "emissionTexture")
        let shaderModifier =    """
                                uniform sampler2D emissionTexture;

                                // how lit-up is this pixel?
                                float3 light = _lightingContribution.diffuse;
                                // compute the 'darkness' of this pixel, too
                                float lum = max(0.0, 1 - 16.0 * (0.2126*light.r + 0.7152*light.g + 0.0722*light.b));
                                // combine the textures, in proportion (regular earth textture & lightPollutionMap,aka emissionTexture)
                                float4 emission = texture2D(emissionTexture, _surface.diffuseTexcoord) * lum * 0.5;
                                _output.color += emission;
                                """
        earthMaterial.shaderModifiers = [.fragment: shaderModifier]
        

        
        // the texture revealed by specular light sources
        //earthMaterial.specular.contents = "earth_lights.jpg"
        earthMaterial.specular.contents = "earth-specular.jpg"
        earthMaterial.specular.intensity = 0.2
        //earthMaterial.shininess = 0.1
        
        // the oceans are reflecty & the land is matte
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, *) {
            earthMaterial.metalness.contents = "metalness-1000x500.png"
            earthMaterial.roughness.contents = "roughness-g-w-1000x500.png"
        }
        
        // make the mountains appear taller
        // (gives them shadows from point lights, but doesn't make them stick up beyond the edges)
        earthMaterial.normal.contents = "earth-bump.png"
        earthMaterial.normal.intensity = 0.3
        
        //earthMaterial.reflective.contents = "envmap.jpg"
        //earthMaterial.reflective.intensity = 0.5
        earthMaterial.fresnelExponent = 2
        globe.geometry = globeShape


        // tilt it on it's axis (23.5 degrees), varied by the actual day of the year
        // (note that children nodes are correctly tilted with the parents coordinate space)
        seasonalTilt.eulerAngles = SCNVector3(SwiftGlobe.computeSeasonalTilt(Date()),0.0, 0.0)
        
        
        //----------------------------------------
        // setup the heirarchy:
        //  rootNode
        //     |
        //     +---userTiltAndRotation
        //           |
        //           +---seasonalTilt
        //                  |
        //                  +globe
        //           +---Sun
        //     +...skybox
        //
        scene.rootNode.addChildHeirarchy( [  userTiltAndRotation,
                                             seasonalTilt,
                                             globe
                                        ])
        // Add the sun above the seasonal tilt! (ie, the season tilt affects the earth, not the sun)
        // NB: user interactivity (on userTiltAndRotation) is also aware of the seasonal tilt, but it must be separate to tilt the earth *and* sun!
        userTiltAndRotation.addChildNode(sun)

                
        //----------------------------------------
        // setup the sun (the light source)
        sun.position = SCNVector3(x: Float(0), y: Float(0), z: kDistanceToTheSun )
        sun.light = SCNLight()
        sun.light!.type = .omni
        // sun color temp at noon: 5600.
        // White is 6500
        // anything above 5000 is 'daylight'
        sun.light!.castsShadow = false
        sun.light!.temperature = 5600
        sun.light!.intensity = 1200 // default is 1000
        
        
        applyUserTiltAndRotation()

    }
    
    // Calculate how much to tilt the earth for the current season
    // The result is the angle in radianson it's axis (23.5 degrees), varied by the actual day of the year
    // (note that children nodes are correctly tilted with the parents coordinate space)
    public class func computeSeasonalTilt(_ today: Date) -> Double {
        let calendar = Calendar(identifier: .gregorian)
        let dayOfYear = Double( calendar.ordinality(of: .day, in: .year, for: today)! )
        let daysSinceWinterSolstice = remainder(dayOfYear + 10.0, kDaysInAYear)
        let daysSinceWinterSolsticeInRadians = daysSinceWinterSolstice * 2.0 * Double.pi / kDaysInAYear
        let tiltXRadians = -cos( daysSinceWinterSolsticeInRadians) * kTiltOfEarthsAxisInRadians
        return tiltXRadians
    }
    
    deinit {
    #if os(tvOS)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.GCControllerDidConnect, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.GCControllerDidDisconnect, object: nil)
    #endif
    }

    public func addMarker(_ marker: GlowingMarker) {
        // for now, just add directly to the scene
        // (in the future we could track these separately)
        globe.addChildNode(marker.node)
    }

#if os(watchOS)
    
    internal func setupOnAppear(enableAutomaticSpin: Bool) {
        finishNonARSetup(enableAutomaticSpin)
    }
    
    internal func setupForSceneView(_ v: SceneView, forARKit : Bool, enableAutomaticSpin: Bool) -> (SCNScene, SCNNode) {
        
        return (scene, cameraNode)
//        var options : SceneView.Options =
//        v.optio = false
//        v.scene = self.scene
//
//        //v.showsStatistics = true
//
//        self.gestureHost = v
//
//        finishNonARSetup(enableAutomaticSpin)
        
    }
#else
    internal func setupInSceneView(_ v: SCNView, forARKit : Bool, enableAutomaticSpin: Bool) {
                
        v.autoenablesDefaultLighting = false
        v.scene = self.scene

        //v.showsStatistics = true
        
        self.gestureHost = v
        
        if forARKit {
            v.allowsCameraControl = true
            
            skybox.removeFromParentNode()

        } else {
            finishNonARSetup(enableAutomaticSpin)
            
            v.pointOfView = cameraNode

            v.allowsCameraControl = false
            
            #if os(iOS)
                let pan = UIPanGestureRecognizer(target: self, action:#selector(SwiftGlobe.onPanGesture(pan:) ) )
                let pinch = UIPinchGestureRecognizer(target: self, action: #selector(SwiftGlobe.onPinchGesture(pinch:) ) )
                v.addGestureRecognizer(pan)
                v.addGestureRecognizer(pinch)
            #elseif os(tvOS)
                
                NotificationCenter.default.addObserver(self, selector: #selector( SwiftGlobe.handleControllerDidConnectNotification(notification:) ), name: NSNotification.Name.GCControllerDidConnect, object: nil)
            #elseif os(watchOS)
                let pan = WKPanGestureRegognizer()
            
            #elseif os(OSX)
                let pan = NSPanGestureRecognizer(target: self, action:#selector(SwiftGlobe.onPanGesture(pan:) ) )
                let pinch = NSMagnificationGestureRecognizer(target: self, action: #selector(SwiftGlobe.onPinchGesture(pinch:) ) )
                v.addGestureRecognizer(pan)
                v.addGestureRecognizer(pinch)
            #endif
        }


    }
    
#endif
    
    private func finishNonARSetup(_ enableAutomaticSpin: Bool) {
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
        
        // give us some ambient light (to light the rest of the model)
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = kAmbientLightIntensity // default is 1000!

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
        
        
        
        // the globe spins once per minute
        if enableAutomaticSpin {
            let spinRotation = SCNAction.rotate(by: 2 * .pi, around: SCNVector3(0, 1, 0), duration: kGlobeDefaultRotationSpeedSeconds)
            let spinAction = SCNAction.repeatForever(spinRotation)
            globe.runAction(spinAction)
        }

    }
    
    private func addPanGestures() {
        
    }
    
#if os(iOS)
    @objc fileprivate func onPanGesture(pan : UIPanGestureRecognizer) {
        // we get here on a tap!
        guard let sceneView = pan.view else { return }
        let loc = pan.location(in: sceneView)
        
        if pan.state == .began {
            handlePanBegan(loc)
        } else {
            guard pan.numberOfTouches == 1 else { return }
            self.handlePanCommon(loc, viewSize: sceneView.frame.size)
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
                //print("new zoom fov: \(newFov)")
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
        //guard let gameController = notification.object as? GCController else { return }
        
        
        // if it is a siri remote
        guard let microGamepad = self.gameController?.microGamepad else { return }
        guard let viewSize = gestureHost?.frame.size else { return }
        print("microGamepad found")
        print("\(#function)")
        //setup the handlers
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

            self.handlePanCommon( loc, viewSize: viewSize)
            
            //print("displacement:\(displacement)")
        }
        
        
        // TODO get the NEW Siri Remote inputs
        // (This doesn't work for some reason; maybe just the simulator isn't working right?)
        microGamepad.dpad.xAxis.valueChangedHandler = {  [unowned self] _, xValue in
            let yValue = microGamepad.dpad.yAxis.value
            let loc = CGPoint(x: CGFloat(xValue), y: CGFloat(yValue) )
            self.handlePanCommon( loc, viewSize: viewSize )
        }
        microGamepad.dpad.yAxis.valueChangedHandler = {  [unowned self] _, yValue in
            let xValue = microGamepad.dpad.yAxis.value
            let loc = CGPoint(x: CGFloat(xValue), y: CGFloat(yValue) )
            self.handlePanCommon( loc, viewSize: viewSize )
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
        guard let sceneView = pan.view else { return }
        
        var loc = pan.location(in: sceneView)
        // OSX has inverted Y coords; flip it before passing to handlePanCommon
        loc.y = sceneView.frame.height - loc.y

        if pan.state == .began {
            handlePanBegan(loc)
        } else {
            handlePanCommon(loc, viewSize: sceneView.frame.size)
        }

    }
    
    @objc fileprivate func onPinchGesture(pinch: NSMagnificationGestureRecognizer){
        // update the fov of the camera
        if pinch.state == .began {
            self.lastFovBeforeZoom = self.camera.fieldOfView
        } else {
            guard let lastFov = self.lastFovBeforeZoom else { return }
            
            // NB: pinch.magnification starts at '0.0', meaning 'no change'. So we add one for per-unity multiply/divide
            // NB: clamp pinch.magnification to positive numbers (raw values can be *negative*, but that messes up our scaling)
            let magnification = max(pinch.magnification + 1.0, 0.0)
            var newFov = lastFov / CGFloat(magnification)
            if newFov < kMinFov {
                newFov = kMinFov
            } else if newFov > kMaxFov {
                newFov = kMaxFov
            }
            
            self.camera.fieldOfView =  newFov
        }
        
    }
#endif
    
    // A simple zoom interface (for the watch)
    public var zoomFov : CGFloat {
        get {
            return self.camera.fieldOfView
        }
        set(newFov) {
            if newFov < kMinFov {
                self.camera.fieldOfView = kMinFov
            } else if newFov > kMaxFov {
                self.camera.fieldOfView = kMaxFov
            } else {
                self.camera.fieldOfView = newFov
            }
        }
    }
    
    public func handlePanBegan(_ loc: CGPoint) {
        lastPanLoc = loc
    }

    public func handlePanCommon(_ loc: CGPoint, viewSize: CGSize) {
        guard let lastPanLoc = lastPanLoc else { return }
        
        // measue the movement difference
        let delta = CGSize(width: (lastPanLoc.x - loc.x) / viewSize.width, height: (lastPanLoc.y - loc.y) / viewSize.height )
        
        handlePan(deltaPerUnity: delta)
        
        self.lastPanLoc = loc
    }
    public func handlePan(deltaPerUnity delta: CGSize) {
        //  DeltaX = amount of rotation to apply (about the world axis)
        //  DelyaY = amount of tilt to apply (to the axis itself)
        if delta.width != 0.0 || delta.height != 0.0 {
            
            // as the user zooms in (smaller fieldOfView value), the finger travel is reduced
            let fovProportion = (self.camera.fieldOfView - kMinFov) / (kMaxFov - kMinFov)
            let fovProportionRadians = Float(fovProportion * CGFloat(kDragWidthInDegrees) ) * ( .pi / 180)
            let rotationAboutAxis = Float(delta.width) * fovProportionRadians
            let tiltOfAxisItself = Float(delta.height) * fovProportionRadians

            // update the user values...
            userTiltRadians -= tiltOfAxisItself
            userRotationRadians -= rotationAboutAxis
            
            //print("User tilt: \(userTiltRadians), userRotation: \(userRotationRadians)")
            applyUserTiltAndRotation()
        }

    }
    
    public func focusOnLatLon(_ lat: Float, _ lon: Float) {

        // stop any auto-rotation
        globe.removeAllActions()
        
        // apply tilt to userTiltRadians
        userTiltRadians = lat / 180.0 * .pi
        userRotationRadians = lon / -180 * .pi

        applyUserTiltAndRotation()
        
        // Remove any rotation the earth may have made (from automatic spin animation)...
        let axisAngle = SCNVector4(0, 1, 0, 0 )
        let spinTo = SCNAction.rotate(toAxisAngle: axisAngle, duration: 0.1)
        globe.runAction(spinTo)
    }
    
    internal func applyUserTiltAndRotation() {
        // .. and recompute the interactivity matrix
        var matrix = SCNMatrix4Identity
        // now apply the user tilt
        matrix = SCNMatrix4RotateF(matrix, userTiltRadians, 1.0, 0.0, 0.0)
        
        let seasonalTilt = -Float(SwiftGlobe.computeSeasonalTilt(Date()))
        switch upDownAlignment {
        case .poles:
            // first, apply the rotation (along the Y axis)
            matrix = SCNMatrix4RotateF(matrix, userRotationRadians, 0.0, 1.0, 0.0)
            // now tilt it (about the X axis) for the seasonal rotation
            matrix = SCNMatrix4RotateF(matrix, seasonalTilt, 1.0, 0.0, 0.0)
        case .dayNightTerminator:
            // now tilt it (about the X axis) for the seasonal rotation
            matrix = SCNMatrix4RotateF(matrix, seasonalTilt, 1.0, 0.0, 0.0)
            // first, apply the rotation (along the Y axis)
            matrix = SCNMatrix4RotateF(matrix, userRotationRadians, 0.0, 1.0, 0.0)
        }
        userTiltAndRotation.transform = matrix
    }
    
}



// Utilities to reduce platform-specific #if's (Float on iOS, CGFloat on macos? 😢)
#if os(OSX)
extension SCNVector3 {
    init(x: Float, y: Float, z:Float ){
            self.init(x: CGFloat(x), y: CGFloat(y), z: CGFloat(z))
    }
}
#endif

func SCNMatrix4RotateF(_ src: SCNMatrix4, _ angle : Float, _ x : Float, _ y : Float, _ z : Float) -> SCNMatrix4 {
    #if os(iOS) || os(tvOS) || os(watchOS)
        return SCNMatrix4Rotate(src, angle, x, y, z)
    #elseif os(OSX)
        return SCNMatrix4Rotate(src, CGFloat(angle), CGFloat(x), CGFloat(y), CGFloat(z))
    #endif

}



extension SCNNode {
    
    // Add a list of nodes as children of eachother
    func addChildHeirarchy(_ nodes: [SCNNode]) {
        // must have at least one to connect!
        if nodes.count < 1 {
            return
        }
        var currentNode = self
        for node in nodes {
            currentNode.addChildNode(node)
            currentNode = node
        }
        
    }
}
