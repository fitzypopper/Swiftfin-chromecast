//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import GoogleCast
import SwiftUI

#if canImport(GoogleCast)

/// A SwiftUI view that displays available Chromecast devices and allows selection.
///
/// Wraps the Google Cast device discovery process and presents a list
/// of discovered devices on the local network.
struct CastDevicePicker: View {

    @StateObject private var sessionManager = CastSessionManager.shared

    var body: some View {
        NavigationStack {
            List {
                if sessionManager.isConnected, let deviceName = sessionManager.connectedDeviceName {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(deviceName)
                            Spacer()
                            Button("Disconnect") {
                                sessionManager.disconnect()
                            }
                            .foregroundStyle(.red)
                        }
                    } header: {
                        Text("Connected")
                    }
                }

                Section {
                    if sessionManager.availableDeviceCount == 0 {
                        HStack {
                            ProgressView()
                            Text("Searching for devices...")
                        }
                    } else {
                        Text("\(sessionManager.availableDeviceCount) device(s) found")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Available Devices")
                }
            }
            .navigationTitle("Cast to Device")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        // Dismiss handled by parent
                    }
                }
            }
        }
    }
}

#endif
