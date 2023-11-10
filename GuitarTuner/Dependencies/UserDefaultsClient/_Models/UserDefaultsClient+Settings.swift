import Foundation

extension UserDefaultsClient {
  /// Global application settings.
  struct Settings: Equatable, Codable {
    var instrument = SoundClient.Instrument.guitar
    var tuning = SoundClient.InstrumentTuning.eStandard
  }
}
