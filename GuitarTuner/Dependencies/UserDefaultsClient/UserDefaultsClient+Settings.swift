import Foundation

extension UserDefaults.Dependency {
  /// Global application settings.
  struct Settings: Equatable, Codable {
    var instrument = SoundClient.Instrument.acoustic
    var tuning = SoundClient.InstrumentTuning.eStandard
  }
}
