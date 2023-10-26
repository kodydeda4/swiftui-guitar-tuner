import Foundation

extension AudioClient {
  enum InstrumentTuning: String, Codable, Equatable, CaseIterable {
    case eStandard = "E Standard"
    case dropD = "Drop D"
    case dadgad = "DADGAD"
  }
}

// MARK: - Extensions

extension AudioClient.InstrumentTuning: Identifiable {
  var id: Self { self }
}

extension AudioClient.InstrumentTuning: CustomStringConvertible {
  var description: String { rawValue }
}

extension AudioClient.InstrumentTuning {
  var notes: [AudioClient.Note] {
    switch self {
    case .eStandard:
      return [
        .init(description: "E2", midi: 40),
        .init(description: "A2", midi: 45),
        .init(description: "D3", midi: 50),
        .init(description: "G3", midi: 55),
        .init(description: "B3", midi: 59),
        .init(description: "e4", midi: 64)
      ]
      
    case .dropD:
      return [
        .init(description: "D2", midi: 38),
        .init(description: "A2", midi: 45),
        .init(description: "D3", midi: 50),
        .init(description: "G3", midi: 55),
        .init(description: "B3", midi: 59),
        .init(description: "e4", midi: 64)
      ]
      
    case .dadgad:
      return [
        .init(description: "D2", midi: 38),
        .init(description: "A2", midi: 45),
        .init(description: "D3", midi: 50),
        .init(description: "G3", midi: 55),
        .init(description: "A3", midi: 57),
        .init(description: "D4", midi: 64)
      ]
    }
  }
}
