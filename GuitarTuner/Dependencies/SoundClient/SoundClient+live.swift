import AVKit
import AVFoundation
import Foundation

extension SoundClient {
  static var live: Self {
    let conductor = SoundConductor()
    
    return Self(
      play: { note in
        await conductor.play(note.midi)
      },
      setInstrument: {
        await conductor.setInstrument($0)
      }
    )
  }
}

// MARK: - Private Implementation

extension SoundClient.Instrument {
  var soundfontURL: URL {
    switch self {
    case .electric:
      Bundle.main.url(forResource: "Electric", withExtension: "sf2")!
    case .acoustic:
      Bundle.main.url(forResource: "Acoustic", withExtension: "sf2")!
    case .bass:
      Bundle.main.url(forResource: "Bass", withExtension: "sf2")!
    case .ukelele:
      Bundle.main.url(forResource: "Ukelele", withExtension: "sf2")!
    }
  }
}

private extension SoundClient {
  /// Play MIDI through a SoundFont.
  private final actor SoundConductor {
    var instrument = Instrument.electric
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
    
    func setInstrument(_ newValue: Instrument) {
      do {
        self.instrument = newValue
        try unitSampler.loadSoundBankInstrument(
          at: newValue.soundfontURL,
          program: 0,
          bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
          bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
      } catch {
        print(error)
      }
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
          at: instrument.soundfontURL,
          program: 0,
          bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
          bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
      } catch {
        print(error)
      }
    }
  }
}
