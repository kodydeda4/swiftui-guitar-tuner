import Foundation

extension SoundClient {
  enum Instrument: String, Equatable, Codable, CaseIterable {
    case guitar = "Guitar"
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
    case .guitar: return .guitar
    case .bass: return .bass
    }
  }
  
  var imageThumbnail: ImageResource {
    switch self {
    case .guitar: return .guitarThumbnail
    case .bass: return .bassThumbnail
    }
  }
  
  var soundfontURL: URL {
    switch self {
    case .guitar: Bundle.main.url(forResource: "Guitar", withExtension: "sf2")!
    case .bass: Bundle.main.url(forResource: "Bass", withExtension: "sf2")!
    }
  }
}
