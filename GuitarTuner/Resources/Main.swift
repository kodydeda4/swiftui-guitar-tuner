import SwiftUI
import ComposableArchitecture
import AVFoundation

@main
struct Main: App {
  init() {
#if os(iOS)
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback,options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP])
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print(error)
    }
#endif
  }
  var body: some Scene {
    WindowGroup {
      AppView(store: Store(
        initialState: AppReducer.State(),
        reducer: AppReducer.init
      ))      
    }
  }
}
