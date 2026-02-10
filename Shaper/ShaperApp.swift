//
//  ShaperApp.swift
//  Shaper
//
//  Created by 曹天航 on 2026/2/10.
//

import SwiftUI

@main
struct ShaperApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: ShaperDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
