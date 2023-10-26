import Foundation

extension SoundClient {
  struct Note: Equatable {
    let description: String
    let midi: UInt8
  }
}

// MARK: - Extensions

extension SoundClient.Note: Identifiable {
  var id: UInt8 { midi }
}
