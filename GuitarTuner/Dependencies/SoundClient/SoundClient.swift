import Foundation
import AVKit
import AVFoundation
import Dependencies

struct SoundClient: DependencyKey {
  var play: @Sendable (Note) async -> Void
}

extension DependencyValues {
  var sound: SoundClient {
    get { self[SoundClient.self] }
    set { self[SoundClient.self] = newValue }
  }
}

// MARK: - Implementations

extension SoundClient {
  static var liveValue = Self.live
//  static var previewValue = Self.preview
//  static var testValue = Self.test
}
