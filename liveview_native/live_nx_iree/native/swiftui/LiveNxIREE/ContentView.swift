//
//  ContentView.swift
//  LiveNxIREE
//

import SwiftUI
import LiveViewNative
import LiveViewNativeLiveForm

struct ContentView: View {
    var body: some View {
        #LiveView(
            .automatic(
                development: URL(string: "http://192.168.0.99:4000/")!, //.localhost(path: "/"),
                production: URL(string: "https://example.com")!
            ),
            addons: [
                .liveForm,
                .nxAddon
            ]
        ) {
            ConnectingView()
        } disconnected: {
            DisconnectedView()
        } reconnecting: { content, isReconnecting in
            ReconnectingView(isReconnecting: isReconnecting) {
                content
            }
        } error: { error in
            ErrorView(error: error)
        }
    }
}
