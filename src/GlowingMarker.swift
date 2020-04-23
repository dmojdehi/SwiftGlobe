//
//  GlowingMarker.swift
//  SwiftGlobe
//
//  Created by David Mojdehi on 4/21/20.
//  Copyright © 2020 David Mojdehi. All rights reserved.
//

import Foundation
import SceneKit
#if os(watchOS)
import SwiftUI
#elseif os(macOS)
#else
import UIKit
#endif

func +(left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}
func -(left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x - right.x, y: left.y - right.y)
}
func +(left: CGPoint, right: CGSize) -> CGPoint {
    return CGPoint(x: left.x + right.width, y: left.y + right.height)
}
func -(left: CGPoint, right: CGSize) -> CGPoint {
    return CGPoint(x: left.x - right.width, y: left.y - right.height)
}


// code to encapsulate individual glow points
// (extend this to get different glow effects)
class GlowingMarker {
    var latitude : Float = 0.0
    var longitude : Float = 0.0
    
    enum Style {
        case dot
#if os(watchOS)
        case beam(Color)
#elseif os(macOS)
        case beam(NSColor)
#else
        case beam(UIColor)
#endif
        case ribbon
    }
    
    // The SceneKit node for this point (must be added to the scene!)
    internal var node : SCNNode!
    
    init(lat: Float, lon: Float, altitude:Float, markerZindex: Int, style: Style) {
        latitude = lat
        longitude = lon
        
        // NB: our textures *center* on 0,0, so adjust by 90 degrees
        let adjustedLon = lon + 90

        // convert lat & lon to xyz
        let cosLat = cosf(lat * Float.pi / 180.0)
        let sinLat = sinf(lat * Float.pi / 180.0);
        let cosLon = cosf(adjustedLon * Float.pi / 180.0);
        let sinLon = sinf(adjustedLon * Float.pi / 180.0);
        let thisPointAltitude = altitude + Float(markerZindex) * 0.0001
        let x = thisPointAltitude * cosLat * cosLon;
        let y = thisPointAltitude * cosLat * sinLon;
        let z = thisPointAltitude * sinLat;
        // convert to scenekit coordinate space:
        //      Camera looks  down the Z axis (down from +z)
        //      Right is +x, left is -x
        //      Up is +y, down is -y
        let sceneKitX = -x
        let sceneKitY = z
        let sceneKitZ = y

        // make the geometry
        let geometry : SCNGeometry
        // ... and the 'out' axis, which varies by geometry)
        let axisToPointOutward : SCNVector3?
        switch style {
        case .dot:
            geometry = SCNPlane(width: kGlowPointWidth, height: kGlowPointWidth)
            // when we point it, make sure it's upright (negative Z because it's 'bottom' should be visible?)
            axisToPointOutward = SCNVector3(0,0,-1)
            
            geometry.firstMaterial!.diffuse.contents = "yellowGlow-32x32.png"
            // appear a little washed out in daylight...
            geometry.firstMaterial!.diffuse.intensity = 0.2
            geometry.firstMaterial!.emission.contents = "yellowGlow-32x32.png"
            // but brigheter in dark areas
            geometry.firstMaterial!.emission.intensity = 2.0
            //geometry.firstMaterial!.emission.intensity = 0.7

        case .beam(let color):
            geometry = SCNCone(topRadius: 0.0,
                               bottomRadius: kGlowPointWidth/8,
                               height: kGlowPointWidth * 3)
            // when we point it, make sure it's upright (it is on its side by default)
            axisToPointOutward = SCNVector3(0,-1,0)
            // visible spike in the daytime
            // use intensity for the HDR 'bloom' glow
            //geometry.firstMaterial!.transparent.contents = color
            geometry.firstMaterial!.diffuse.contents = color
            geometry.firstMaterial!.diffuse.intensity = 8.0
            // make a very bright glow for nighttime
            geometry.firstMaterial!.emission.contents = color
            geometry.firstMaterial!.emission.intensity = 12.0
        
        case .ribbon:
            // from a good answer on Stack Overflow by "0x141E", on the use of SCNGeometryElement
            // Answering "What is an example of drawing custom nodes with vertices in swift SceneKit?"
            // https://stackoverflow.com/a/44600834/235229
            
            // unit size
            let u = Float(0.01)
            // make all the vertices & normals
            let vertices:[SCNVector3] = [
                    SCNVector3(x:-u, y:-u, z:u),    // 0
                    SCNVector3(x:u, y:u, z:u),      // 2
                    SCNVector3(x:-u, y:u, z:u),      // 3

                    SCNVector3(x:-u, y:-u, z:u),    // 0
                    SCNVector3(x:u, y:-u, z:u),     // 1
                    SCNVector3(x:u, y:u, z:u)       // 2
            ]
            let normals:[SCNVector3] = [
                    SCNVector3(x:0, y:0, z:u),      // 0
                    SCNVector3(x:0, y:0, z:u),      // 2
                    SCNVector3(x:0, y:0, z:u),      // 3

                    SCNVector3(x:0, y:0, z:u),      // 0
                    SCNVector3(x:0, y:0, z:u),      // 1
                    SCNVector3(x:0, y:0, z:u)       // 2
            ]
            
            let vertexSource = SCNGeometrySource(vertices: vertices)
            let normalSource = SCNGeometrySource(normals: normals)
            
            
            // now make a geometryElement from them
            let indices:[Int32] = [0, 1, 2, 3, 4, 5]
            let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
            //let indexData = NSData(bytes: &indices, length: MemoryLayout<Int32>.size * indices.count)
            //let element = SCNGeometryElement(data: indexData as Data, primitiveType: .triangles, primitiveCount: indices.count, bytesPerIndex: MemoryLayout<Int32>.size)

            // finally put it into the geometry
            geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
            axisToPointOutward = SCNVector3(0,0,-1)

#if os(watchOS)
            let color = Color.yellow
#elseif os(macOS)
            let color = NSColor.yellow
#else
            let color = UIColor.yellow
#endif
            geometry.firstMaterial!.diffuse.contents = color
            geometry.firstMaterial!.diffuse.intensity = 8.0
            geometry.firstMaterial!.emission.contents = color
            geometry.firstMaterial!.emission.intensity = 12.0
//            geometry.firstMaterial!.transparent.contents = color
//            geometry.firstMaterial!.transparency = 0.01
//
//            geometry.firstMaterial!.emission.contents = color
//            geometry.firstMaterial!.emission.intensity = 12.0
        }
        
        node = SCNNode(geometry: geometry )
        node.castsShadow = false
        
        let pos = SCNVector3(x: sceneKitX, y: sceneKitY, z: sceneKitZ )
        node.position = pos
        
        if let axisToPointOutward = axisToPointOutward {
            node.look(at: SCNVector3(0,0,0), up: SCNVector3(0,0,1), localFront: axisToPointOutward)
        }

    }
    
    func addPulseAnimation() {
// CoreAnimation isn't available on watchOS :-(
#if os(iOS) || os(tvOS) || os(macOS)
        let animation = CABasicAnimation(keyPath: "scale")
        animation.fromValue = SCNVector3(x: Float(0.5), y: Float(0.5), z: Float(0.5))
        animation.toValue = SCNVector3(x: Float(3.0), y: Float(3.0), z: Float(3.0))
        animation.duration = 1.0
        animation.autoreverses = true
        animation.repeatCount = Float.infinity
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        node.addAnimation(animation, forKey: "throb")
#endif
    }
    
}
