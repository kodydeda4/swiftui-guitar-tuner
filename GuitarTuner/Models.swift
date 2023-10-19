import Foundation

// MARK: - Note

public struct Note {
  public let description: String
  public let midi: UInt8
}

extension Note: Equatable {}
extension Note: Identifiable { public var id: UInt8 { midi } }

// MARK: - Instrument

public enum Instrument: String, Codable {
  case acoustic = "Acoustic"
  case electric = "Electric"
  case bass = "Bass"
  case ukelele = "Ukelele"
}

extension Instrument: Equatable {}
extension Instrument: CaseIterable {}
extension Instrument: Identifiable { public var id: String { rawValue } }
extension Instrument: CustomStringConvertible { public var description: String { rawValue } }

extension Instrument {
  var image: ImageResource {
    switch self {
    case .acoustic:
      return .acoustic
    case .electric:
      return .electric
    case .bass:
      return .bass
    case .ukelele:
      return .ukelele
    }
  }
  var thumnailImage: ImageResource {
    switch self {
    case .acoustic:
      return .acousticThumbnail
    case .electric:
      return .electricThumbnail
    case .bass:
      return .bassThumbnail
    case .ukelele:
      return .uekeleThumbnail
    }
  }
}


// MARK: - InstrumentTuning

public enum InstrumentTuning: String, Codable {
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

// MARK: - UserDefaults.Dependency.Settings

extension UserDefaults.Dependency {
  struct Settings: Equatable, Codable {
    var instrument = Instrument.acoustic
    var tuning = InstrumentTuning.eStandard
  }
}

import Tagged

extension UserDefaults.Dependency {
  enum Key: String, Identifiable, Equatable {
    var id: Self { self }
    case settings = "Settings"
  }
}
