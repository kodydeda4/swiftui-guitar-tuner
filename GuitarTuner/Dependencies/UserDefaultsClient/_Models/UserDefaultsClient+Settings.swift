import Foundation

extension UserDefaultsClient {
  /// Global application settings.
  struct Settings: Equatable, Codable {
    var instrument = SoundClient.Instrument.guitar
    var tuning = SoundClient.InstrumentTuning.eStandard
  }
}

extension UserDefaultsClient.Settings {
  init(from state: AppReducer.State) {
    self = Self(
      instrument: state.instrument,
      tuning: state.tuning
    )
  }
}
