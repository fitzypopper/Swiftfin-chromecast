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

/// A button that initiates Chromecast device discovery and connection.
///
/// Displays the standard Google Cast icon. When tapped, shows the
/// Cast device discovery dialog. When connected, shows a highlighted state.
struct CastButton: View {

    @StateObject private var sessionManager = CastSessionManager.shared

    var body: some View {
        Button {
            if sessionManager.isConnected {
                sessionManager.disconnect()
            } else {
                sessionManager.showCastDialog()
            }
        } label: {
            Image(systemName: sessionManager.isConnected ? "play.fill.rectangle" : "rectangle.fill.on.rectangle.fill")
                .foregroundStyle(sessionManager.isConnected ? .jellyfinPurple : .secondary)
                .font(.title3)
        }
        .accessibilityLabel(
            sessionManager.isConnected
                ? "Casting to \(sessionManager.connectedDeviceName ?? "device")"
                : "Cast to device"
        )
    }
}

#endif
