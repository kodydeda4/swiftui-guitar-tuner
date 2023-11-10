import Foundation
import AVFoundation
import Tonic

extension SoundClient {
  static var live: Self {
    let conductor = Conductor()
    
    return Self(
      play: { conductor.play($0) },
      stop: { conductor.stop($0) },
      setInstrument: { conductor.setInstrument($0) }
    )
  }
}

// MARK: - Private Implementation

private final class Conductor {
  let engine = AVAudioEngine()
  var sampler = AVAudioUnitSampler()
  var instrument = SoundClient.Instrument.guitar
  
  init() {
    do {
      engine.mainMixerNode.volume = 1
      engine.attach(sampler)
      engine.connect(sampler, to: engine.mainMixerNode, format: nil)
      try? sampler.loadSoundBankInstrument(
        at: instrument.soundfontURL,
        program: 0,
        bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
        bankLSB: UInt8(kAUSampler_DefaultBankLSB)
      )
      try engine.start()
    } catch {
      print(error)
    }
  }
  
  func play(_ note: Note) {
    sampler.startNote(UInt8(note.pitch.intValue), withVelocity: 127, onChannel: 0)
  }
  
  func stop(_ note: Note) {
    sampler.stopNote(UInt8(note.pitch.intValue), onChannel: 0)
  }
  
  func setInstrument(_ newValue: SoundClient.Instrument) {
    self.instrument = newValue
    try? sampler.loadSoundBankInstrument(
      at: newValue.soundfontURL,
      program: 0,
      bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
      bankLSB: UInt8(kAUSampler_DefaultBankLSB)
    )
  }
}
