import Foundation

extension SoundClient {
  enum Instrument: String, Equatable, Codable, CaseIterable {
    case acoustic = "Acoustic"
    case electric = "Electric"
    case bass = "Bass"
    case ukelele = "Ukelele"
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
    case .acoustic: return .acoustic
    case .electric: return .electric
    case .bass: return .bass
    case .ukelele: return .ukelele
    }
  }
  
  var imageSmall: ImageResource {
    switch self {
    case .acoustic: return .acousticThumbnail
    case .electric: return .electricThumbnail
    case .bass: return .bassThumbnail
    case .ukelele: return .uekeleThumbnail
    }
  }
  
  var soundfontURL: URL {
    switch self {
    case .electric: Bundle.main.url(forResource: "Electric", withExtension: "sf2")!
    case .acoustic: Bundle.main.url(forResource: "Acoustic", withExtension: "sf2")!
    case .bass: Bundle.main.url(forResource: "Bass", withExtension: "sf2")!
    case .ukelele: Bundle.main.url(forResource: "Ukelele", withExtension: "sf2")!
    }
  }
}
