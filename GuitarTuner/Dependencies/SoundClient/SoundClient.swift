import Dependencies
import Tonic

struct SoundClient: DependencyKey {
  var play: @Sendable (Note) async -> Void
  var stop: @Sendable (Note) async -> Void
  var setInstrument: @Sendable (Instrument) async -> Void
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
}
