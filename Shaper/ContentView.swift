//
//  ContentView.swift
//  Shaper
//
//  Created by 曹天航 on 2026/2/10.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: ShaperDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(ShaperDocument()))
}
