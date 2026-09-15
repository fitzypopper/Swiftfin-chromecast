//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
import Foundation
import GoogleCast
import JellyfinAPI
import Logging
import SwiftUI

#if canImport(GoogleCast)

/// A media player proxy that delegates playback to a connected Chromecast device.
///
/// Wraps `CastPlayerManager` and `CastSessionManager` to present a `MediaPlayerProxy`
/// interface that integrates with `MediaPlayerManager`.
@MainActor
class CastMediaPlayerProxy: VideoMediaPlayerProxy {

    private let logger = Logger.swiftfin()

    // MARK: - PublishedBox properties

    let isBuffering: PublishedBox<Bool> = .init(initialValue: false)
    let videoSize: PublishedBox<CGSize> = .init(initialValue: .zero)
    let droppedFrames: PublishedBox<Int> = .init(initialValue: 0)
    let corruptedFrames: PublishedBox<Int> = .init(initialValue: 0)

    // MARK: - MediaPlayerProxy

    weak var manager: MediaPlayerManager? {
        didSet {
            if let manager {
                managerItemObserver = manager.$playbackItem
                    .sink { playbackItem in
                        if let playbackItem {
                            Task { await self.playNew(item: playbackItem) }
                        }
                    }

                managerStateObserver = manager.$state
                    .sink { state in
                        switch state {
                        case .stopped:
                            self.stop()
                        default:
                            break
                        }
                    }
            } else {
                managerItemObserver?.cancel()
                managerStateObserver?.cancel()
            }
        }
    }

    var observers: [any MediaPlayerObserver] = []

    // MARK: - Private State

    private let castSessionManager = CastSessionManager.shared
    private let castPlayerManager = CastPlayerManager()
    private var managerItemObserver: AnyCancellable?
    private var managerStateObserver: AnyCancellable?
    private var statusObservation: Any?

    // MARK: - Init

    init() {
        castPlayerManager.attachToSession(castSessionManager.currentSession!)
    }

    // MARK: - Playback Controls

    func play() {
        castPlayerManager.play()
    }

    func pause() {
        castPlayerManager.pause()
    }

    func stop() {
        castPlayerManager.stop()
    }

    func jumpForward(_ seconds: Duration) {
        let target = castPlayerManager.currentTime + seconds.timeInterval
        castPlayerManager.seek(to: target)
    }

    func jumpBackward(_ seconds: Duration) {
        let target = max(castPlayerManager.currentTime - seconds.timeInterval, 0)
        castPlayerManager.seek(to: target)
    }

    func setRate(_ rate: Float) {
        // Google Cast doesn't support variable playback rate directly
        // The standard media receiver ignores this; custom receiver could handle it
    }

    func setSeconds(_ seconds: Duration) {
        castPlayerManager.seek(to: seconds.timeInterval)
    }

    // MARK: - Audio/Subtitle Track Configuration

    func setAudioStream(_ stream: MediaStream) {
        // Track switching on Cast requires custom receiver support
        // Standard receiver doesn't support remote track selection
    }

    func setSubtitleStream(_ stream: MediaStream) {
        // Track switching on Cast requires custom receiver support
        // Standard receiver doesn't support remote track selection
    }

    // MARK: - Media Loading

    private func playNew(item: MediaPlayerItem) async {
        guard let userSession = Container.shared.currentUserSession() else {
            logger.error("No user session available for Cast playback")
            return
        }

        do {
            try await castPlayerManager.loadMedia(from: item, userSession: userSession)
            manager?.state = .playback
        } catch {
            logger.error("Failed to load media on Cast device", metadata: [
                "error": .string(error.localizedDescription),
            ])
            manager?.state = .error
        }
    }

    // MARK: - VideoMediaPlayerProxy

    func setAspectFill(_ aspectFill: Bool) {
        // Chromecast doesn't support aspect fill control
    }

    var videoPlayerBody: some View {
        EmptyView()
    }
}

#endif
