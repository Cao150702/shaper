//
//  ContentView.swift
//  Shaper
//
//  Created by 曹天航 on 2026/2/10.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        NavigationStack {
            HomeView()
        }
        .environmentObject(appState)
    }
}

#Preview {
    ContentView()
}
