//
//  SwiftGlobe.swift
//  SwiftGlobe
//
//  Created by David Mojdehi on 4/6/17.
//  Copyright © 2017 David Mojdehi. All rights reserved.
//

import Foundation

import SceneKit

let kGlobeRadius = 5.0
let kGlowPointAltitude = kGlobeRadius * 1.01
let kGlowPointWidth = CGFloat(0.5)

let kTiltOfEarthsAxisInDegrees = 23.5






class GlobeGlowPoint {
    var latitude = 0.0
    var longitude = 0.0
    // varies from 0..1
    var currentPhase = 0.0
    // peak-to-peak duration
    var duration = 4.0
    
    // the node of this point (once it has been added to the scene)
    fileprivate var node : SCNNode!
    
    init(lat: Double, lon: Double) {
        self.latitude = lat
        self.longitude = lon
        
        self.node = SCNNode(geometry: SCNPlane(width: kGlowPointWidth, height: kGlowPointWidth) )
        self.node.geometry!.firstMaterial!.diffuse.contents = "yellowGlow-32x32.png"
        self.node.castsShadow = false
        // convert lat & lon to fixed space
        
        // our textures *center* on 0,0, so adjust by 90 degrees
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
        
        let pos = SCNVector3(x: CGFloat(sceneKitX), y: CGFloat(sceneKitY), z:CGFloat(sceneKitZ) )
        self.node.position = pos
        
        
        // and compute the normal pitch, yaw & roll (facing away from the globe)
        //1. Pitch (the x component) is the rotation about the node's x-axis (in radians)
        let pitch = -lat * Double.pi / 180.0
        //2. Yaw   (the y component) is the rotation about the node's y-axis (in radians)
        let yaw = lon * Double.pi / 180.0
        //3. Roll  (the z component) is the rotation about the node's z-axis (in radians)
        let roll = 0.0
        self.node.eulerAngles = SCNVector3(x: CGFloat(pitch), y: CGFloat(yaw), z: CGFloat(roll) )
        
        
        
    }
    
}

class SwiftGlobe {
    
    
    var scene = SCNScene()
    var camera = SCNCamera()
    var cameraNode = SCNNode()
    var globe = SCNNode()
    var glowingSpots = [SCNNode]()

    init() {
        // make the globe
        let globeShape = SCNSphere(radius: CGFloat(kGlobeRadius) )
        globeShape.segmentCount = 30
        globeShape.isGeodesic = false
        // the texture revealed by diffuse light sources
        globeShape.firstMaterial!.diffuse.contents = "world2700x1350.jpg" //earth-diffuse.jpg"
        
        // the texture revealed by specular light sources
        //globeShape.firstMaterial!.specular.contents = "earth_lights.jpg"
        globeShape.firstMaterial!.specular.contents = "earth-specular.jpg"
        globeShape.firstMaterial!.specular.intensity = 0.2
        //globeShape.firstMaterial!.shininess = 0.1
        
        // the oceans are reflecty & the land is matte
        globeShape.firstMaterial!.metalness.contents = "metalness-1000x500.png"
        globeShape.firstMaterial!.roughness.contents = "roughness-1000x500.png"
        
        //globeShape.firstMaterial!.reflective.contents = "envmap.jpg"
        //globeShape.firstMaterial!.reflective.intensity = 0.5
        globeShape.firstMaterial!.fresnelExponent = 2
        
        // tilt it on it's axis (23.5 degrees)
        // (note that children nodes are correctly tilted with the parents coordinate space)
        #if os(iOS)
            let tiltInRadians = Float( kTiltOfEarthsAxisInDegrees  * M_PI / 180 )
        #elseif os(OSX)
            let tiltInRadians = CGFloat( kTiltOfEarthsAxisInDegrees  * Double.pi / 180 )
        #endif
        globe.eulerAngles = SCNVector3(x: tiltInRadians, y: 0, z: 0)
        
        
        
        //------------------------------------------
        // make some glowing nodes
        // x: 0.0, y: 0.0, z: 5.05
        let zz = GlobeGlowPoint(lat: 0,lon: 0)
        // make this one white!
        zz.node.geometry!.firstMaterial?.diffuse.contents = "whiteGlow-32x32.png"
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
                globe.addChildNode(spot.node)
            }
        }
        //------------------------------------------

        
        // add the galaxy skybox
        scene.background.contents = "eso0932a-milkyway360-dimmed"
        scene.background.intensity = 0.01
        
        globe.geometry = globeShape
        scene.rootNode.addChildNode(globe)

        
        // override SceneKit's arcball rotation
        //
        //  - drag Left<->Right: 
        //                      rotates globe around axis
        //                      does not affect camera position or angle
        //
        //  - drag Up<->Down:   
        //                      tilts the axis up and down
        //                      *does* affect the camera position & angle; the skybox tilts correpsondigly
        //
        
        
        // create and add a camera to the scene
        // configure the camera itself
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 9
        camera.zNear = 0
        camera.zFar = 100
        // its node (so it can live in the scene)
        #if os(iOS)
            cameraNode.position = SCNVector3(x: 0, y: 0, z:  Float( kGlobeRadius * 2.0)  )
        #elseif os(OSX)
            // uggh; MacOS uses CGFloat instead of float :-(
            cameraNode.position = SCNVector3(x: 0, y: 0, z:  CGFloat( kGlobeRadius * 2.0)  )
        #endif
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)
    
    }
    
    
}
