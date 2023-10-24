import Foundation
import AVKit
import AVFoundation
import Dependencies

struct SoundFontClient: DependencyKey {
  var play: @Sendable (Note) async -> Void
  var setInstrument: @Sendable (Instrument) async -> Void
}

extension DependencyValues {
  var sound: SoundFontClient {
    get { self[SoundFontClient.self] }
    set { self[SoundFontClient.self] = newValue }
  }
}

// MARK: - Implementations

extension SoundFontClient {
  static var liveValue = Self.live
//  static var previewValue = Self.preview
//  static var testValue = Self.test
}
