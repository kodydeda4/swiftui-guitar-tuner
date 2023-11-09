import Foundation

extension SoundClient {
  enum Instrument: String, Equatable, Codable, CaseIterable {
    case metal = "Metal"
    case electric = "Electric"
    case acoustic = "Acoustic"
    case bass = "Bass"
  }
}

// MARK: - Extensions

extension SoundClient.Instrument: Identifiable {
  var id: Self { self }
}

extension SoundClient.Instrument: CustomStringConvertible {
  var description: String { rawValue }
}

extension SoundClient.Instrument {
  var imageLarge: ImageResource {
    switch self {
    case .metal: return .metal
    case .electric: return .electric
    case .acoustic: return .acoustic
    case .bass: return .bass
    }
  }
  
  var imageSmall: ImageResource {
    switch self {
    case .metal: return .metalThumbnail
    case .electric: return .electricThumbnail
    case .acoustic: return .acousticThumbnail
    case .bass: return .bassThumbnail
    }
  }
  
  var soundfontURL: URL {
    switch self {
    case .metal: Bundle.main.url(forResource: "Metal", withExtension: "sf2")!
    case .electric: Bundle.main.url(forResource: "Electric", withExtension: "sf2")!
    case .acoustic: Bundle.main.url(forResource: "Acoustic", withExtension: "sf2")!
    case .bass: Bundle.main.url(forResource: "Bass", withExtension: "sf2")!
    }
  }
}
