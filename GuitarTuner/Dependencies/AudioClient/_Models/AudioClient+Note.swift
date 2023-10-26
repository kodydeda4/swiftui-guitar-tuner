import Foundation

extension AudioClient {
  struct Note: Equatable {
    let description: String
    let midi: UInt8
  }
}

// MARK: - Extensions

extension AudioClient.Note: Identifiable {
  var id: UInt8 { midi }
}
