import AVKit
import AVFoundation
import Foundation

extension SoundClient {
  static var live: Self {
    let conductor = SoundConductor()
    
    return Self(
      play: { note in
        await conductor.play(note.midi)
      }
    )
  }
}

// MARK: - Private Implementation

/// Play MIDI through a SoundFont.
private final actor SoundConductor {
  var soundfont = Bundle.main.url(forResource: "Guitar", withExtension: "sf2")!
  var volume = Float(0.5)
  var channel = UInt8(1)
  let audioEngine = AVAudioEngine()
  let unitSampler = AVAudioUnitSampler()
  
  func play(_ note: UInt8) {
    unitSampler.startNote(
      note,
      withVelocity: 80,
      onChannel: channel
    )
  }
  
  init() {
    do {
      // AudioEngine
      audioEngine.mainMixerNode.volume = volume
      audioEngine.attach(unitSampler)
      audioEngine.connect(unitSampler, to: audioEngine.mainMixerNode, format: nil)
      
      // UnitSampler
      try audioEngine.start()
      try unitSampler.loadSoundBankInstrument(
        at: soundfont,
        program: 0,
        bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
        bankLSB: UInt8(kAUSampler_DefaultBankLSB)
      )
    } catch {
      print(error)
    }
  }
}
