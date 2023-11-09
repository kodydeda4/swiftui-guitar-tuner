import Tonic

extension Note: Identifiable {
  public var id: Int8 { pitch.midiNoteNumber }
}
