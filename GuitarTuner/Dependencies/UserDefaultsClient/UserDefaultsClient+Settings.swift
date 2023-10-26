import Foundation

extension UserDefaults.Dependency {
  /// Global application settings.
  struct Settings: Equatable, Codable {
    var instrument = AudioClient.Instrument.acoustic
    var tuning = AudioClient.InstrumentTuning.eStandard
  }
}
