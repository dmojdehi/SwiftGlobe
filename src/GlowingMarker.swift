//
//  GlowingMarker.swift
//  SwiftGlobe
//
//  Created by David Mojdehi on 4/21/20.
//  Copyright © 2020 David Mojdehi. All rights reserved.
//

import Foundation
import SceneKit



// code to encapsulate individual glow points
// (extend this to get different glow effects)
class GlowingMarker {
    var latitude = 0.0
    var longitude = 0.0
    
    // The SceneKit node for this point (must be added to the scene!)
    internal var node : SCNNode!
    
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
    
    func addPulseAnimation() {
        let animation = CABasicAnimation(keyPath: "scale")
        animation.fromValue = SCNVector3(x: 0.5, y: 0.5, z: 0.5)
        animation.toValue = SCNVector3(x: 3.0, y: 3.0, z: 3.0)
        animation.duration = 1.0
        animation.autoreverses = true
        animation.repeatCount = Float.infinity
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        node.addAnimation(animation, forKey: "throb")
    }
    
}
