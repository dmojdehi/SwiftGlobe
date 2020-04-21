//
//  DemoMarkers.swift
//  SwiftGlobe
//
//  Created by David Mojdehi on 4/21/20.
//  Copyright © 2020 David Mojdehi. All rights reserved.
//

import Foundation

extension SwiftGlobe {
    
    public func addDemoMarkers() {
        //------------------------------------------
        // make some glowing nodes
        // x: 0.0, y: 0.0, z: 5.05
        let zz = GlowingMarker(lat: 0,lon: 0)
        // make this one white!
        zz.node.geometry!.firstMaterial!.diffuse.contents = "whiteGlow-32x32.png"
        self.addMarker(zz)
                
        let sf = GlowingMarker(lat: 37.7749,lon: -122.4194)
        sf.addPulseAnimation()
        self.addMarker(sf)
                
        let madagascar = GlowingMarker(lat: -18.91368, lon: 47.53613)
        self.addMarker(madagascar)
                
        let madrid = GlowingMarker(lat: 40.4168, lon: -3.7038)
        self.addMarker(madrid)

        // a row of dots down the 'noon' meridian
//        for i in stride(from:-90.0, through: 90.0, by: 10.0) {
//            let spot = GlowingMarker(lat: i, lon: 0.0)
//            if i != 0 {
//                self.addMarker(spot)
//            }
//        }

    }
}
