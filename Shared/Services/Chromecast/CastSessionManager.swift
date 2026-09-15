//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import GoogleCast
import JellyfinAPI
import SwiftUI

#if canImport(GoogleCast)

/// Manages the Google Cast session lifecycle, device discovery, and connection state.
///
/// Wraps `GCKCastContext` and `GCKSessionManager` to provide a SwiftUI-friendly
/// interface for casting to Chromecast devices on the local network.
@MainActor
final class CastSessionManager: NSObject, ObservableObject, GCKSessionManagerListener, GCKDiscoveryManagerListener {

    // MARK: - Published State

    @Published private(set) var isConnected = false
    @Published private(set) var isDiscovering = false
    @Published private(set) var connectedDeviceName: String?
    @Published private(set) var availableDeviceCount = 0

    /// The current Cast session, non-nil when connected to a device.
    private(set) var currentSession: GCKCastSession?

    // MARK: - Singleton

    static let shared = CastSessionManager()

    // MARK: - Init

    override init() {
        super.init()

        let context = GCKCastContext.sharedInstance()
        context.sessionManager.addListener(self)
        context.discoveryManager.addListener(self)
        context.discoveryManager.startDiscovery()
    }

    // MARK: - Session Lifecycle

    /// Launches the Jellyfin Cast receiver on the specified device.
    func castTo(device: GCKDevice) {
        GCKCastContext.sharedInstance().sessionManager.startSession(with: device)
    }

    /// Disconnects from the current Cast session.
    func disconnect() {
        GCKCastContext.sharedInstance().sessionManager.endSession()
    }

    /// Shows the built-in Cast device discovery dialog.
    func showCastDialog() {
        GCKCastContext.sharedInstance().presentCastDialog()
    }

    // MARK: - GCKSessionManagerListener

    nonisolated func sessionManager(
        _ sessionManager: GCKSessionManager,
        didStart session: GCKSession
    ) {
        Task { @MainActor in
            guard let castSession = session as? GCKCastSession else { return }
            self.currentSession = castSession
            self.isConnected = true
            self.connectedDeviceName = castSession.device.friendlyName
        }
    }

    nonisolated func sessionManager(
        _ sessionManager: GCKSessionManager,
        didEnd session: GCKSession,
        withError error: Error?
    ) {
        Task { @MainActor in
            self.currentSession = nil
            self.isConnected = false
            self.connectedDeviceName = nil
        }
    }

    nonisolated func sessionManager(
        _ sessionManager: GCKSessionManager,
        didSuspend session: GCKSession,
        with reason: GCKConnectionSuspendReason
    ) {
        Task { @MainActor in
            self.isConnected = false
        }
    }

    nonisolated func sessionManager(
        _ sessionManager: GCKSessionManager,
        didResume session: GCKSession
    ) {
        Task { @MainActor in
            self.isConnected = true
            self.connectedDeviceName = (session as? GCKCastSession)?.device.friendlyName
        }
    }

    // MARK: - GCKDiscoveryManagerListener

    nonisolated func didUpdateDeviceList() {
        Task { @MainActor in
            self.availableDeviceCount = GCKCastContext.sharedInstance().discoveryManager.deviceCount
        }
    }
}

#endif
