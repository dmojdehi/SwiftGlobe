//
//  ContentView.swift
//  SwiftGlobe-Watch WatchKit Extension
//
//  Created by David Mojdehi on 4/21/20.
//  Copyright © 2020 David Mojdehi. All rights reserved.
//

import SwiftUI
import SceneKit

struct ContentView: View {
    var body: some View {
        ZStack {
            SceneView(
            Text("Hello, World!")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
