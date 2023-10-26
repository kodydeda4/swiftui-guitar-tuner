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
}
