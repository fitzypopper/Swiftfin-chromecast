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
        DirectPlayProfile(
            container: "mp4",
            codec: "h264",
            audioCodec: "aac,ac3,eac3"
        )
        DirectPlayProfile(
            container: "mp4",
            codec: "hevc",
            audioCodec: "aac,ac3,eac3"
        )
        DirectPlayProfile(
            container: "webm",
            codec: "vp8,vp9",
            audioCodec: "opus,vorbis"
        )
        DirectPlayProfile(
            container: "mkv",
            codec: "h264,hevc",
            audioCodec: "aac,ac3,eac3,opus,vorbis"
        )
    }

    @ArrayBuilder<TranscodingProfile>
    static var _castTranscodingProfiles: [TranscodingProfile] {
        TranscodingProfile(
            container: .mp4,
            codec: .h264,
            audioCodec: "aac",
            maxAudioChannels: 2,
            type: .video
        )
        TranscodingProfile(
            container: .hls,
            codec: .h264,
            audioCodec: "aac",
            maxAudioChannels: 2,
            type: .video
        )
    }

    @ArrayBuilder<SubtitleProfile>
    static var _castSubtitleProfiles: [SubtitleProfile] {
        SubtitleProfile(format: "srt", deliveryMethod: .hls)
        SubtitleProfile(format: "ass", deliveryMethod: .hls)
        SubtitleProfile(format: "ssa", deliveryMethod: .hls)
        SubtitleProfile(format: "webvtt", deliveryMethod: .hls)
        SubtitleProfile(format: "subrip", deliveryMethod: .hls)
        SubtitleProfile(format: "mov_text", deliveryMethod: .hls)
    }

    @ArrayBuilder<CodecProfile>
    var _castCodecProfiles: [CodecProfile] {
        CodecProfile(
            container: "mp4,webm,mkv",
            type: .videoVideo
        ) {
            ProfileCondition(
                condition: .equalsAny,
                isRequired: false,
                property: .videoProfile,
                value: "main,main 10,high"
            )
        }
    }
}

#endif
