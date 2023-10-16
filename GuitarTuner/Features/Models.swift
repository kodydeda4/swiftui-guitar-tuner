import Foundation

// MARK: - Note

public struct Note {
  public let description: String
  public let midi: UInt8
}

extension Note: Equatable {}
extension Note: Identifiable { public var id: UInt8 { midi } }

// MARK: - Instrument

public enum Instrument: String {
  case guitar = "Guitar"
  case bass = "Bass"
}

extension Instrument: Equatable {}
extension Instrument: CaseIterable {}
extension Instrument: Identifiable { public var id: String { rawValue } }
extension Instrument: CustomStringConvertible { public var description: String { rawValue} }


// MARK: - InstrumentTuning

public enum InstrumentTuning: String {
  case eStandard = "E Standard"
  case dropD = "Drop D"
  case dadgad = "DADGAD"
}

extension InstrumentTuning: Equatable {}
extension InstrumentTuning: CaseIterable {}
extension InstrumentTuning: Identifiable { public var id: String { rawValue } }
extension InstrumentTuning: CustomStringConvertible { public var description: String { rawValue } }

public extension InstrumentTuning {
  var notes: [Note] {
    switch self {
    case .eStandard:
      return [
        Note(description: "E2", midi: 40),
        Note(description: "A2", midi: 45),
        Note(description: "D3", midi: 50),
        Note(description: "G3", midi: 55),
        Note(description: "B3", midi: 59),
        Note(description: "e4", midi: 64)
      ]
      
    case .dropD:
      return [
        Note(description: "D2", midi: 38),
        Note(description: "A2", midi: 45),
        Note(description: "D3", midi: 50),
        Note(description: "G3", midi: 55),
        Note(description: "B3", midi: 59),
        Note(description: "e4", midi: 64)
      ]
      
    case .dadgad:
      return [
        Note(description: "D2", midi: 38),
        Note(description: "A2", midi: 45),
        Note(description: "D3", midi: 50),
        Note(description: "G3", midi: 55),
        Note(description: "A3", midi: 57),
        Note(description: "D4", midi: 64)
      ]
    }
  }
}
