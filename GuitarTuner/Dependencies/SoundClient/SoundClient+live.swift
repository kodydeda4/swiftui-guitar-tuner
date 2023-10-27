import SwiftUI
import Foundation
import AVFoundation
import Tonic

extension SoundClient {
  static var live: Self {
    let conductor = Conductor()
    
    return Self(
      play: { conductor.play(Pitch(intValue: Int($0.midi))) },
      stop: { conductor.stop(Pitch(intValue: Int($0.midi))) },
      setInstrument: { _ in  }
    )
  }
}

// MARK: - Private Implementation

private final class Conductor {
  let engine = AVAudioEngine()
  var instrument = AVAudioUnitSampler()
  let instrumentURL = Bundle.main.url(forResource: "Sounds/Instrument1", withExtension: "aupreset")
  
  init() {
    do {
      engine.attach(instrument)
      engine.connect(instrument, to: engine.mainMixerNode, format: nil)
      if let instrumentURL {
        try? instrument.loadInstrument(at: instrumentURL)
      }
      try engine.start()
    } catch {
      print(error)
    }
  }
  
  func play(_ pitch: Pitch) {
    instrument.startNote(UInt8(pitch.intValue), withVelocity: 127, onChannel: 0)
  }
  
  func stop(_ pitch: Pitch) {
    instrument.stopNote(UInt8(pitch.intValue), onChannel: 0)
  }
}
