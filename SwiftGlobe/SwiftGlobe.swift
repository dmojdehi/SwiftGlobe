//
//  SwiftGlobe.swift
//  SwiftGlobe
//
//  Created by David Mojdehi on 4/6/17.
//  Copyright © 2017 David Mojdehi. All rights reserved.
//

import Foundation

import SceneKit

let kGlobeRadius = 10.0
let kCameraAltitude = 80.0
let kDefaultCameraFov = 20.0
let kMinFov = 5.0
let kMaxFov = 30.0
let kGlowPointAltitude = kGlobeRadius * 1.001
let kGlowPointWidth = CGFloat(0.5)

let kTiltOfEarthsAxisInDegrees = 23.5
let kTiltOfEarthsAxisInRadians = (23.5 * Double.pi) / 180.0


// winter solstice is appx Dec 21, 22, or 23
let kDayOfWinterStolsticeInYear = 356.0
let kDaysInAYear = 365.0

let kAffectedBySpring = 1 << 1



class GlobeGlowPoint {
    var latitude = 0.0
    var longitude = 0.0
    
    // the node of this point (once it has been added to the scene)
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
        
        #if os(iOS)
            let pos = SCNVector3(x: Float(sceneKitX), y: Float(sceneKitY), z: Float(sceneKitZ) )
        #elseif os(OSX)
            let pos = SCNVector3(x: CGFloat(sceneKitX), y: CGFloat(sceneKitY), z:CGFloat(sceneKitZ) )
        #endif
        self.node.position = pos
        
        
        // and compute the normal pitch, yaw & roll (facing away from the globe)
        //1. Pitch (the x component) is the rotation about the node's x-axis (in radians)
        let pitch = -lat * Double.pi / 180.0
        //2. Yaw   (the y component) is the rotation about the node's y-axis (in radians)
        let yaw = lon * Double.pi / 180.0
        //3. Roll  (the z component) is the rotation about the node's z-axis (in radians)
        let roll = 0.0
        
        
        #if os(iOS)
            self.node.eulerAngles = SCNVector3(x: Float(pitch), y: Float(yaw), z: Float(roll) )
        #elseif os(OSX)
            self.node.eulerAngles = SCNVector3(x: CGFloat(pitch), y: CGFloat(yaw), z: CGFloat(roll) )
        #endif

    }
    
}

class SwiftGlobe {
    
    
    var sceneView : SCNView?
    var scene = SCNScene()
    var camera = SCNCamera()
    var cameraNode = SCNNode()
    var cameraGoal = SCNNode()
    var globe = SCNNode()
    var seasonalTilt = SCNNode()
    var glowingSpots = [SCNNode]()
    var sun = SCNNode()
    var _cameraGoalLatitude = 0.5
    var _cameraGoalLongitude = 0.4

    var lastPanLoc : CGPoint?
    var lastFovBeforeZoom : Double?
    
    
    internal init() {
        // make the globe
        let globeShape = SCNSphere(radius: CGFloat(kGlobeRadius) )
        globeShape.segmentCount = 30
        // the texture revealed by diffuse light sources
        globeShape.firstMaterial!.diffuse.contents = "world2700x1350.jpg" //earth-diffuse.jpg"
        
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
        ambientLight.intensity = 20.0 // default is 1000!

        
        // the texture revealed by specular light sources
        //globeShape.firstMaterial!.specular.contents = "earth_lights.jpg"
        globeShape.firstMaterial!.specular.contents = "earth-specular.jpg"
        globeShape.firstMaterial!.specular.intensity = 0.2
        //globeShape.firstMaterial!.shininess = 0.1
        
        // the oceans are reflecty & the land is matte
        globeShape.firstMaterial!.metalness.contents = "metalness-1000x500.png"
        globeShape.firstMaterial!.roughness.contents = "roughness-g-w-1000x500.png"
        
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
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        sf.node.addAnimation(animation, forKey: "throb")
        globe.addChildNode(sf.node)
        
        let madagascar = GlobeGlowPoint(lat: -18.91368, lon: 47.53613)
        globe.addChildNode(madagascar.node)
        
        let madrid = GlobeGlowPoint(lat: 40.4168, lon: -3.7038)
        globe.addChildNode(madrid.node)
        
        for i in stride(from:-90.0, through: 90.0, by: 10.0) {
            let spot = GlobeGlowPoint(lat: i, lon: 0.0)
            if i != 0 {
                seasonalTilt.addChildNode(spot.node)
            }
        }
        //------------------------------------------

        
        // give the globe an angular inertia
        let globePhysics = SCNPhysicsBody(type: .dynamic, shape: nil)
        globePhysics.angularVelocity = SCNVector4Make(0.0, 1.0, 0.0, 0.5 /*this is the speed*/)
        globePhysics.angularDamping = 0.0
        globePhysics.mass = 1000000
        globePhysics.isAffectedByGravity = false
        globePhysics.categoryBitMask = 0
        globe.physicsBody = globePhysics
        
        seasonalTilt.addChildNode(globe)

        
        
        // tilt it on it's axis (23.5 degrees), varied by the actual day of the year
        // (note that children nodes are correctly tilted with the parents coordinate space)
        let calendar = Calendar(identifier: .gregorian)
        let dayOfYear = Double( calendar.ordinality(of: .day, in: .year, for: Date())! )
        let daysSinceWinterSolstice = remainder(dayOfYear + 10.0, kDaysInAYear)
        let daysSinceWinterSolsticeInRadians = daysSinceWinterSolstice * 2.0 * Double.pi / kDaysInAYear
        let tiltXRadians = -cos( daysSinceWinterSolsticeInRadians) * kTiltOfEarthsAxisInRadians
        //
        #if os(iOS)
            seasonalTilt.eulerAngles = SCNVector3(x: Float(tiltXRadians), y: 0.0, z: 0)
        #elseif os(OSX)
            seasonalTilt.eulerAngles = SCNVector3(x: CGFloat(tiltXRadians), y: 0.0, z: 0)
        #endif
        scene.rootNode.addChildNode(seasonalTilt)

        
        // TODO: override SceneKit's arcball rotation
        //
        //  - drag Left<->Right: 
        //                      rotates globe around axis
        //                      does not affect camera position or angle
        //
        //  - drag Up<->Down:   
        //                      tilts the axis up and down (actually does this by moving the camera up and down an arc over the globe)
        //                      *does* affect the camera position & angle; the skybox tilts correpsondigly
        //
        
        
        // setup the sun as a light source
        sun.position = SCNVector3(x: 0, y:0, z: 200.0)
        sun.light = SCNLight()
        sun.light!.type = .omni
        // sun color temp at noon: 5600.
        // White is 6500
        // anything above 5000 is 'daylight'
        sun.light!.temperature = 5600
        sun.light!.castsShadow = false
        sun.light!.intensity = 1200 // default is 1000
        scene.rootNode.addChildNode(sun)
        
        // add the galaxy skybox
        scene.background.contents = "eso0932a-milkyway360-dimmed.jpg"
        scene.background.intensity = 0.01
        
 

        // setup our special camera constraints
        // the cameraNode follows the cameraGoal closely
        //  We create a spring (as a physics field)
        let cameraNodeSpring = SCNPhysicsField.spring()
        cameraNodeSpring.categoryBitMask = kAffectedBySpring
        #if os(iOS)
            cameraGoal.position = SCNVector3(x: 0, y: 0, z:  Float( kGlobeRadius + kCameraAltitude )  )
        #elseif os(OSX)
            // uggh; MacOS uses CGFloat instead of float :-(
            cameraGoal.position = SCNVector3(x: 0, y: 0, z:  CGFloat( kGlobeRadius  + kCameraAltitude)  )
        #endif
        cameraGoal.physicsField = cameraNodeSpring
        
        //let debugBall = SCNSphere(radius: 0.5)
        //cameraGoal.geometry = debugBall
        scene.rootNode.addChildNode(cameraGoal)
        
        
        //---------------------------------------
        // create and add a camera to the scene
        // set up a 'telephoto' shot (to avoid any fisheye effects)
        // (telephoto: narrow field of view at a long distance
        camera.xFov = kDefaultCameraFov
        camera.zFar = 10000
        // its node (so it can live in the scene)
        #if os(iOS)
            cameraNode.position = SCNVector3(x: 0, y: 0, z:  Float( kGlobeRadius + kCameraAltitude)  )
        #elseif os(OSX)
            // uggh; MacOS uses CGFloat instead of float :-(
            cameraNode.position = SCNVector3(x: 0, y: 0, z:  CGFloat( kGlobeRadius + kCameraAltitude)  )
        #endif
        
        
        //-----------------------------------
        // Setup the camera node itself, which chases after the 'cameraGoal' but is always looking at the globe
        // We use physics to follow the 'camera goal' smoothly 
        // (the user manipulates the goal, not the camera!)
        // NB: SCNPhysicsBody requires a shape to be affected by the spring.
        let fakeCameraShape = SCNPhysicsShape(geometry: SCNSphere(radius: 0.001), options: nil)
        let cameraNodePhysics = SCNPhysicsBody(type: .dynamic, shape: fakeCameraShape)
        cameraNodePhysics.isAffectedByGravity = false
        cameraNodePhysics.categoryBitMask = kAffectedBySpring
        cameraNodePhysics.damping = 2.0
        //cameraNodePhysics.velocityFactor = SCNVector3(x:0.8, y:0.8, z: 0.8)
        cameraNode.physicsBody = cameraNodePhysics
        cameraNode.physicsBody?.allowsResting = false
        cameraNode.constraints = [ SCNLookAtConstraint(target: self.globe) ]
        cameraNode.light = ambientLight
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)
        
        // make a hinge, to keep the camera at a fixed distance from the center
        // (This helps, but only partially ; there's still some 'lean in' when making big changes to the angle)
//        let x = SCNPhysicsHingeJoint(body: cameraNodePhysics, axis: SCNVector3(x:1.0,y:0,z:0), anchor: SCNVector3(x: 0, y: 0, z:  -CGFloat( kGlobeRadius + kCameraAltitude) ))
//        scene.physicsWorld.addBehavior(x)
        
        self.updateCameraGoal()
    }
    
    internal func setupInSceneView(_ v: SCNView, allowPan : Bool) {
        // Do any additional setup after loading the view.
        self.sceneView = v
    #if os(iOS)
        let pan = UIPanGestureRecognizer(target: self, action:#selector(SwiftGlobe.onPanGesture(pan:) ) )
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(SwiftGlobe.onPinchGesture(pinch:) ) )
        v.addGestureRecognizer(pinch)
    #elseif os(OSX)
        let pan = NSPanGestureRecognizer(target: self, action:#selector(SwiftGlobe.onPanGesture(pan:) ) )
    #endif
        v.addGestureRecognizer(pan)

    }
    
#if os(iOS)
    @objc fileprivate func onPanGesture(pan : UIPanGestureRecognizer) {
        // we get here on a tap!
        if let sceneView = self.sceneView{
            let loc = pan.location(in: sceneView)
            //
            if pan.state == .began {
                self.lastPanLoc = loc
            } else if let lastPanLoc = self.lastPanLoc {
                // measue the movement difference
                let delta = CGSize(width: lastPanLoc.x - loc.x, height: lastPanLoc.y - loc.y)
                self.cameraGoalLatitude += Double(delta.height) / 500.0
                self.cameraGoalLongitude -= Double(delta.width) / 300.0
                // vertical delta should move the camera goal along the
            }
            self.lastPanLoc = loc
        }
    }
    @objc fileprivate func onPinchGesture(pinch: UIPinchGestureRecognizer){
        // update the fov of the camera
        if pinch.state == .began {
            self.lastFovBeforeZoom = self.camera.xFov
        } else {
            
        }
        
        if let lastFov = self.lastFovBeforeZoom {
            var newFov = lastFov / Double(pinch.scale)
            if newFov < kMinFov {
                newFov = kMinFov
            } else if newFov > kMaxFov {
                newFov = kMaxFov
            }
            
            self.camera.xFov =  newFov
        }
    }
#elseif os(OSX)

    @objc fileprivate func onPanGesture(pan : NSPanGestureRecognizer) {
        // we get here on a tap!
        if let sceneView = self.sceneView{
            let loc = pan.location(in: sceneView)
            //
            if pan.state == .began {
                self.lastPanLoc = loc
            } else if let lastPanLoc = self.lastPanLoc {
                // measue the movement difference
                let delta = NSMakeSize(lastPanLoc.x - loc.x, lastPanLoc.y - loc.y)
                self.cameraGoalLatitude -= Double(delta.height) / 500.0
                self.cameraGoalLongitude -= Double(delta.width) / 300.0
                // vertical delta should move the camera goal along the
            }
            self.lastPanLoc = loc
        }
    }
#endif

    
    // a value 0 - 1.0, representing the new location
    var cameraGoalLatitude : Double {
        get {
            return _cameraGoalLatitude
        }
        set(newGoalVal) {
            
            // set the new value (but pin it between 0.0 & 1.0
            _cameraGoalLatitude = newGoalVal
            if _cameraGoalLatitude > 1.0 {
                _cameraGoalLatitude = 1.0
            } else if _cameraGoalLatitude < 0.0 {
                _cameraGoalLatitude = 0.0
            }
            
            self.updateCameraGoal()

        }
    }
    var cameraGoalLongitude : Double {
        get {
            return _cameraGoalLongitude
        }
        set(newGoalVal) {
            
            _cameraGoalLongitude = newGoalVal
            if _cameraGoalLongitude > 1.0 {
                _cameraGoalLongitude = 1.0
            } else if _cameraGoalLongitude < 0 {
                _cameraGoalLongitude = 0.0
            }
            self.updateCameraGoal()
            
        }
    }
    
    private func updateCameraGoal() {
        print("new goal: \(_cameraGoalLatitude),  \(_cameraGoalLongitude)")
        // amount left & right
        var newX = cos( _cameraGoalLongitude * Double.pi) * (kGlobeRadius + kCameraAltitude) // sin( newGoalVal * Double.pi * 2.0 ) * kGlobeRadius * 10
        var newY = cos( _cameraGoalLatitude * Double.pi ) * (kGlobeRadius + kCameraAltitude)
        var newZ = sin( _cameraGoalLatitude * Double.pi ) * (kGlobeRadius + kCameraAltitude)
        
        
        #if os(iOS)
            cameraGoal.position = SCNVector3(x: Float(newX), y: Float(newY), z:  Float(newZ)  )
        #elseif os(OSX)
            // uggh; MacOS uses CGFloat instead of float :-(
            cameraGoal.position = SCNVector3(x: CGFloat(newX), y: CGFloat(newY), z:  CGFloat(newZ)  )
        #endif

    }
    
}
