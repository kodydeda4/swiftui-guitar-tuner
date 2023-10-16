import Foundation
import AVKit
import AVFoundation
import Dependencies

struct SoundClient: DependencyKey {
  var play: @Sendable (Note) async -> Void
}

extension DependencyValues {
  var sound: SoundClient {
    get { self[SoundClient.self] }
    set { self[SoundClient.self] = newValue }
  }
}

// MARK: - Implementations

extension SoundClient {
  static var liveValue = Self.live
  //  static var previewValue = Self.preview
  //  static var testValue = Self.test
}



extension SoundClient {
  static var live: Self {
    let midi = MidiConductor()
    
    return Self(
      play: { note in
        await midi.play(note.midi)
      }
    )
  }
}

/// Play MIDI through a SoundFont.
private actor MidiConductor {
  var soundfont = Bundle.main.url(forResource: "Guitar", withExtension: "sf2")!
//  var soundfont =
  var volume = Float(0.5)
  var channel = UInt8(1)
  let audioEngine = AVAudioEngine()
  let unitSampler = AVAudioUnitSampler()
  
  public func play(_ note: UInt8) {
    unitSampler.startNote(
      note,
      withVelocity: 80,
      onChannel: channel
    )
  }
  
  init() {
    // AudioEngine
    audioEngine.mainMixerNode.volume = volume
    audioEngine.attach(unitSampler)
    audioEngine.connect(
      unitSampler,
      to: audioEngine.mainMixerNode,
      format: nil
    )
    
    // UnitSampler
    if let _ = try? audioEngine.start() {
      try? unitSampler.loadSoundBankInstrument(
        at: soundfont,
        program: 0,
        bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
        bankLSB: UInt8(kAUSampler_DefaultBankLSB)
      )
    }
  }
}
