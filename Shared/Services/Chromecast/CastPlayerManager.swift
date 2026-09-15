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
import Logging
import SwiftUI

#if canImport(GoogleCast)

/// Manages media playback on a connected Chromecast device via `GCKRemoteMediaClient`.
///
/// Handles loading media items, sending playback commands (play/pause/seek),
/// and observing remote playback status.
@MainActor
final class CastPlayerManager: NSObject, ObservableObject, GCKRemoteMediaClientListener {

    private let logger = Logger.swiftfin()

    // MARK: - Published State

    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var isBuffering = false
    @Published private(set) var mediaStatus: GCKMediaPlayerStatus = .unknown

    /// The remote media client for the current session.
    private var remoteMediaClient: GCKRemoteMediaClient?

    // MARK: - Lifecycle

    func attachToSession(_ session: GCKCastSession) {
        remoteMediaClient?.remove(self)
        remoteMediaClient = session.remoteMediaClient
        remoteMediaClient?.add(self)
    }

    func detachFromSession() {
        remoteMediaClient?.remove(self)
        remoteMediaClient = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        isBuffering = false
    }

    // MARK: - Media Loading

    /// Loads a Jellyfin media item onto the Chromecast device.
    ///
    /// - Parameters:
    ///   - item: The `MediaPlayerItem` containing the stream URL and metadata.
    ///   - userSession: The current user session for building authenticated URLs.
    func loadMedia(from item: MediaPlayerItem, userSession: UserSession) async throws {
        guard let remoteMediaClient else {
            logger.error("No remote media client available")
            throw CastPlayerError.notConnected
        }

        let streamURL = item.url

        // Build media metadata for the Chromecast receiver
        let mediaMetadata = GCKMediaMetadata(metadataType: .movie)
        mediaMetadata.setString(item.baseItem.displayTitle ?? "Unknown", forKey: kGCKMetadataKeyTitle)

        if let seriesName = item.baseItem.seriesName {
            mediaMetadata.setString(seriesName, forKey: kGCKMetadataKeyStudio)
        }

        if let overview = item.baseItem.overview {
            mediaMetadata.setString(overview, forKey: kGCKMetadataKeySubtitle)
        }

        // Load thumbnail if available
        if let imageURL = item.baseItem.getBackdropImageURL(baseUrl: userSession.client.serverURL) {
            let image = GCKImage(url: imageURL, width: 1920, height: 1080)
            mediaMetadata.addImage(image)
        }

        // Build media info
        let mediaInfoBuilder = GCKMediaInformationBuilder(contentURL: streamURL)
        mediaInfoBuilder.streamType = item.mediaSource.transcodingURL != nil ? .buffered : .none
        mediaInfoBuilder.contentType = "video/mp4"
        mediaInfoBuilder.metadata = mediaMetadata
        let mediaInfo = mediaInfoBuilder.build()

        // Build media queue item
        let queueItem = GCKMediaQueueItemBuilder()
        queueItem.mediaInformation = mediaInfo
        queueItem.autoplay = true
        queueItem.startTime = item.baseItem.startSeconds.map { $0.timeInterval } ?? 0
        let queueItemBuilt = queueItem.build()

        // Load media
        let request = remoteMediaClient.mediaQueue.insert(
            queueItems: [queueItemBuilt],
            at: 0,
            autoplay: true,
            startTime: queueItemBuilt.startTime
        )
        request?.delegate = self
    }

    // MARK: - Playback Controls

    func play() {
        remoteMediaClient?.play()
    }

    func pause() {
        remoteMediaClient?.pause()
    }

    func stop() {
        remoteMediaClient?.stop()
    }

    func seek(to seconds: TimeInterval) {
        let position = GCKMediaPosition()
        position.setTime(seconds)
        position.resumeState = .play
        remoteMediaClient?.seek(to: position)
    }

    func setVolume(_ volume: Float) {
        remoteMediaClient?.setStreamVolume(volume)
    }

    // MARK: - GCKRemoteMediaClientListener

    nonisolated func remoteMediaClient(
        _ remoteMediaClient: GCKRemoteMediaClient,
        didUpdate mediaStatus: GCKMediaStatus
    ) {
        Task { @MainActor in
            self.mediaStatus = mediaStatus.playerState
            self.isPlaying = mediaStatus.playerState == .playing
            self.isBuffering = mediaStatus.playerState == .buffering
            self.currentTime = mediaStatus.streamPosition
            self.duration = mediaStatus.mediaInformation?.streamDuration ?? 0
        }
    }
}

// MARK: - Errors

enum CastPlayerError: LocalizedError {
    case notConnected
    case loadFailed

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to a Cast device"
        case .loadFailed:
            return "Failed to load media on Cast device"
        }
    }
}

#endif
