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

#if canImport(GoogleCast)

extension VideoPlayerType {

    // MARK: - Cast-Specific Profiles

    /// Device profile for Chromecast direct play support.
    ///
    /// Chromecast supports a wide range of codecs but has specific
    /// requirements for container format and streaming protocol.
    @ArrayBuilder<DirectPlayProfile>
    static var _castDirectPlayProfiles: [DirectPlayProfile] {
        DirectPlayProfile(type: .video) {
            AudioCodec.aac
            AudioCodec.ac3
            AudioCodec.eac3
        } videoCodecs: {
            VideoCodec.h264
        } containers: {
            MediaContainer.mp4
        }
        DirectPlayProfile(type: .video) {
            AudioCodec.aac
            AudioCodec.ac3
            AudioCodec.eac3
        } videoCodecs: {
            VideoCodec.hevc
        } containers: {
            MediaContainer.mp4
        }
        DirectPlayProfile(type: .video) {
            AudioCodec.opus
            AudioCodec.vorbis
        } videoCodecs: {
            VideoCodec.vp8
            VideoCodec.vp9
        } containers: {
            MediaContainer.webm
        }
        DirectPlayProfile(type: .video) {
            AudioCodec.aac
            AudioCodec.ac3
            AudioCodec.eac3
            AudioCodec.opus
            AudioCodec.vorbis
        } videoCodecs: {
            VideoCodec.h264
            VideoCodec.hevc
        } containers: {
            MediaContainer.mkv
        }
    }

    @ArrayBuilder<TranscodingProfile>
    static var _castTranscodingProfiles: [TranscodingProfile] {
        TranscodingProfile(
            isBreakOnNonKeyFrames: true,
            context: .streaming,
            enableSubtitlesInManifest: true,
            maxAudioChannels: "2",
            minSegments: 2,
            protocol: MediaStreamProtocol.hls,
            type: .video
        ) {
            AudioCodec.aac
        } videoCodecs: {
            VideoCodec.h264
        } containers: {
            MediaContainer.mp4
            MediaContainer.ts
        }
    }

    @ArrayBuilder<SubtitleProfile>
    static var _castSubtitleProfiles: [SubtitleProfile] {
        SubtitleProfile.build(method: .hls) {
            SubtitleFormat.subrip
            SubtitleFormat.ass
            SubtitleFormat.ssa
            SubtitleFormat.vtt
            SubtitleFormat.mov_text
        }
    }

    @ArrayBuilder<CodecProfile>
    static var _castCodecProfiles: [CodecProfile] {
        CodecProfile(
            codec: VideoCodec.h264.rawValue,
            type: .video,
            conditions: {
                ProfileCondition(
                    condition: .equalsAny,
                    isRequired: false,
                    property: .videoProfile
                ) {
                    H264Profile.main
                    H264Profile.high
                }
                ProfileCondition(
                    condition: .notEquals,
                    isRequired: false,
                    property: .isInterlaced,
                    value: "true"
                )
            }
        )
    }
}

#endif
