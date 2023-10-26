import AVKit
import AVFoundation
import Foundation

extension SoundClient {
  static var live: Self {
    let conductor = SoundConductor(instrument: .electric)
    
    return Self(
      play: { await conductor.play($0.midi) },
      stop: { await conductor.stop($0.midi) },
      setInstrument: { await conductor.setInstrument($0) }
    )
  }
}

// MARK: - Private Implementation

private extension SoundClient {
  /// Play MIDI through a SoundFont.
  private final actor SoundConductor {
    let volume = Float(0.5)
    let channel = UInt8(1)
    let velocity = UInt8(80)
    let audioEngine = AVAudioEngine()
    let unitSampler = AVAudioUnitSampler()
    
    func play(_ note: UInt8) {
      unitSampler.startNote(note, withVelocity: velocity, onChannel: channel)
    }
    
    func stop(_ note: UInt8) {
      unitSampler.stopNote(note, onChannel: channel)
    }
    
    func setInstrument(_ newValue: Instrument) {
      try! unitSampler.loadSoundBankInstrument(
        at: newValue.soundfontURL,
        program: 0,
        bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
        bankLSB: UInt8(kAUSampler_DefaultBankLSB)
      )
    }
    
    init(instrument: Instrument) {
      // AudioEngine
      audioEngine.mainMixerNode.volume = volume
      audioEngine.attach(unitSampler)
      audioEngine.connect(unitSampler, to: audioEngine.mainMixerNode, format: nil)
      try! audioEngine.start()
      
      // UnitSampler
      try! unitSampler.loadSoundBankInstrument(
        at: instrument.soundfontURL,
        program: 0,
        bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
        bankLSB: UInt8(kAUSampler_DefaultBankLSB)
      )
    }
  }
}
