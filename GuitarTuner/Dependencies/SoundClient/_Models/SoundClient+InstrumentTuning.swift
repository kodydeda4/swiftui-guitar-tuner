import Foundation
import Tonic

extension SoundClient {
  enum InstrumentTuning: String, Codable, Equatable, CaseIterable {
    case eStandard = "E Standard"
    case dropD = "Drop D"
    case dadgad = "DADGAD"
  }
}

// MARK: - Extensions

extension SoundClient.InstrumentTuning: Identifiable {
  var id: Self { self }
}

extension SoundClient.InstrumentTuning: CustomStringConvertible {
  var description: String { rawValue }
}

extension SoundClient.InstrumentTuning {
  var notes: [Note] {
    switch self {
    case .eStandard:
      return [40, 45, 50, 55, 59, 64]
        .map { Pitch.init(intValue: $0) }
        .map { Note.init(pitch: $0 )}
      
    case .dropD:
      return [38, 45, 50, 55, 59, 64]
        .map { Pitch.init(intValue: $0) }
        .map { Note.init(pitch: $0 )}
      
    case .dadgad:
      return [38 ,45 ,50 ,55 ,57 ,64]
        .map { Pitch.init(intValue: $0) }
        .map { Note.init(pitch: $0 )}
    }
  }
}
