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

#if canImport(GoogleCast)

/// Manages media playback on a connected Chromecast device via `GCKRemoteMediaClient`.
///
/// Handles loading media items, sending playback commands (play/pause/seek),
/// and observing remote playback status.
@MainActor
final class CastPlayerManager: NSObject, ObservableObject, GCKRemoteMediaClientListener, GCKRequestDelegate {

    private let logger = Logger.swiftfin()

    // MARK: - Published State

    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var isBuffering = false
    @Published private(set) var playerState: GCKMediaPlayerState = .unknown

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
        playerState = .unknown
    }

    // MARK: - Media Loading

    /// Loads a Jellyfin media item onto the Chromecast device.
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
        if let tag = item.baseItem.backdropImageTags?.first,
           let itemID = item.baseItem.id
        {
            let urlString = "\(userSession.client.configuration.url)/Items/\(itemID)/Images/Backdrop?tag=\(tag)&maxWidth=1920&maxHeight=1080"
            if let imageURL = URL(string: urlString) {
                mediaMetadata.addImage(GCKImage(url: imageURL, width: 1920, height: 1080))
            }
        }

        // Build media info
        let mediaInfoBuilder = GCKMediaInformationBuilder(contentURL: streamURL)
        mediaInfoBuilder.streamType = .buffered
        mediaInfoBuilder.contentType = "video/mp4"
        mediaInfoBuilder.metadata = mediaMetadata

        // Load media via the recommended load request API
        let loadDataBuilder = GCKMediaLoadRequestDataBuilder()
        loadDataBuilder.mediaInformation = mediaInfoBuilder.build()
        loadDataBuilder.autoplay = true
        loadDataBuilder.startTime = item.baseItem.startSeconds?.seconds ?? 0

        let request = remoteMediaClient.loadMedia(with: loadDataBuilder.build())
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
        let options = GCKMediaSeekOptions()
        options.interval = seconds
        options.relative = false
        options.resumeState = .play
        remoteMediaClient?.seek(withOptions: options)
    }

    func setVolume(_ volume: Float) {
        GCKCastContext.sharedInstance().sessionManager.currentSession?.setDeviceVolume(volume)
    }

    // MARK: - GCKRemoteMediaClientListener

    nonisolated func remoteMediaClient(
        _ client: GCKRemoteMediaClient,
        didUpdate mediaStatus: GCKMediaStatus?
    ) {
        Task { @MainActor in
            guard let mediaStatus else { return }

            self.playerState = mediaStatus.playerState
            self.isPlaying = mediaStatus.playerState == .playing
            self.isBuffering = mediaStatus.playerState == .buffering
            self.currentTime = mediaStatus.streamPosition
            self.duration = mediaStatus.mediaInformation?.streamDuration ?? 0
        }
    }

    // MARK: - GCKRequestDelegate

    nonisolated func request(
        _ request: GCKRequest,
        didFailWithError error: GCKError
    ) {
        Task { @MainActor in
            logger.error("Cast request failed", metadata: [
                "error": .string(error.localizedDescription),
            ])
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