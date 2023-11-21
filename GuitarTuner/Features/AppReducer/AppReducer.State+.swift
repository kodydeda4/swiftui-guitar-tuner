import Tonic

extension AppReducer.State {
  var navigationTitle: String {
    instrument.description
  }
  
  var notes: [Note] {
    switch instrument {
    case .bass:
      Array(tuning.notes.prefix(upTo: 4))
    default:
      Array(tuning.notes)
    }
  }
}
