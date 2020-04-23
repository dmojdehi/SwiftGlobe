//
//  ContentView.swift
//  SwiftGlobe-Watch Watch App
//
//  Created by David Mojdehi on 6/8/23.
//  Copyright © 2023 David Mojdehi. All rights reserved.
//

import SwiftUI
import SceneKit

struct ContentView: View {
    let swiftGlobe = SwiftGlobe(alignment: .poles)
    @State var crownScrollPerUnity = 0.0
    
    var body: some View {
        GeometryReader { geo in
            SceneView(scene: swiftGlobe.scene)
                .onAppear() {
                    swiftGlobe.setupOnAppear(enableAutomaticSpin: true)
                    swiftGlobe.zoomFov = 26.0
                }
                // allow finger swipes to zoom in & rotate the globe
                .gesture(DragGesture(minimumDistance: 0.0, coordinateSpace: .local)
                         
                    .onChanged({ newValue in
                        // reduce our drag amounts for a less-twitchy response
                        let kLessTwitchy = 0.05
                        // swipe up and down to tilt the poles
                        let deltaV = (-newValue.translation.height / geo.size.height )
                        // swipe left and right to rotate
                        let deltaH = -newValue.translation.width / geo.size.width
                        swiftGlobe.handlePan(deltaPerUnity: CGSize(width: deltaH * kLessTwitchy, height: deltaV * kLessTwitchy))
                    }) )
                // allow the crown to zoom in & out
                .focusable(true)
                .digitalCrownRotation($crownScrollPerUnity, from: 0.0, through: 1.0, by: 0.05, isContinuous: false, isHapticFeedbackEnabled:true)
                .onChange(of: crownScrollPerUnity) { newValue in
                    // scale the range by the rotation amount
                    let newFov = (kMaxFov-kMinFov) * CGFloat( 1.0 - newValue) + kMinFov
                    swiftGlobe.zoomFov = CGFloat(newFov)
                }
        }
        .edgesIgnoringSafeArea(.all)

    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
