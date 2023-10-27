import Foundation
import AVFoundation
import Tonic

extension SoundClient {
  static var live: Self {
    let conductor = Conductor()
    
    return Self(
      play: { conductor.play($0) },
      stop: { conductor.stop($0) },
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
  
  func play(_ note: Note) {
    instrument.startNote(UInt8(note.intValue), withVelocity: 127, onChannel: 0)
  }
  
  func stop(_ note: Note) {
    instrument.stopNote(UInt8(note.intValue), onChannel: 0)
  }
}
