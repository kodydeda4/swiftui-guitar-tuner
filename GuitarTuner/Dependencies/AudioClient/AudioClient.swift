import Dependencies

struct AudioClient: DependencyKey {
  var play: @Sendable (Note) async -> Void
  var setInstrument: @Sendable (Instrument) async -> Void
}

extension DependencyValues {
  var sound: AudioClient {
    get { self[AudioClient.self] }
    set { self[AudioClient.self] = newValue }
  }
}

// MARK: - Implementations

extension AudioClient {
  static var liveValue = Self.live
}
