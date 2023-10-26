import SwiftUI
import ComposableArchitecture
import DependenciesAdditions

// MARK: - Bugs:
// 1. sound only works when connected to an external audio source.
// 2. cancel play-all
// 3. "acoustic" and "electric" soundfonts are horrible
// 4. try this for playing midi?: https://developer.apple.com/documentation/avfaudio/avmidiplayer

struct AppReducer: Reducer {
  struct State: Equatable {
    var instrument = SoundClient.Instrument.electric
    var tuning = SoundClient.InstrumentTuning.eStandard
    var inFlight: SoundClient.Note?
    var isPlayAllInFlight = false
    @BindingState var isRingEnabled = false
  }
  
  enum Action: Equatable {
    case view(View)
    case setSettings(UserDefaults.Dependency.Settings)
    case play(SoundClient.Note)
    case stop(SoundClient.Note)
    case didCompletePlayAll
    
    enum View: BindableAction, Equatable {
      case task
      case setInstrument(SoundClient.Instrument)
      case setTuning(SoundClient.InstrumentTuning)
      
      case noteButtonTapped(SoundClient.Note)
      case playAllButtonTapped
      case stopButtonTapped
      case binding(BindingAction<State>)
    }
  }
  
  @Dependency(\.sound) var sound
  @Dependency(\.continuousClock) var clock
  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.encode) var encode
  @Dependency(\.decode) var decode
  
  var body: some ReducerOf<Self> {
    BindingReducer(action: /Action.view)
    Reduce { state, action in
      switch action {
        
      case let .view(action):
        switch action {
          
        case .task:
          return .run { send in
            await withTaskGroup(of: Void.self) { group in
              group.addTask {
                for await data in userDefaults.dataValues(forKey: .settings) {
                  if let value = data.flatMap({
                    try? decode(UserDefaults.Dependency.Settings.self, from: $0)
                  }) {
                    await send(.setSettings(value))
                  }
                }
              }
            }
          }
          
        case .playAllButtonTapped:
          guard !state.isPlayAllInFlight else { return .none }
          state.isPlayAllInFlight = true
          return .run { [inFlight = state.inFlight, notes = state.notes] send in
            // stop any playing notes
            if let inFlight {
              await send(.stop(inFlight))
            }
            // play all the notes at a normal speed
            for note in notes {
              await send(.play(note))
              try await clock.sleep(for: .seconds(1))
              await send(.stop(note))
            }
            // play all the notes again faster except the last one
            for note in notes.dropLast() {
              await send(.play(note))
              try await clock.sleep(for: .seconds(0.1))
              await send(.stop(note))
            }
            // play the last note and let it ring
            if let last = notes.last {
              await send(.play(last))
              try await clock.sleep(for: .seconds(1))
              await send(.stop(last))
            }
            await send(.didCompletePlayAll)
          }
          
        case .stopButtonTapped:
          state.inFlight = nil
          return .none
          
        case let .noteButtonTapped(note):
          return .run { [
            inFlight = state.inFlight,
            isRingEnabled = state.isRingEnabled
          ] send in
            if let inFlight {
              await send(.stop(inFlight))
            }
            if note != inFlight {
              await send(.play(note))
            }
            if !isRingEnabled {
              try await clock.sleep(for: .seconds(2))
              await send(.stop(note))
            }
          }
          
        case let .setInstrument(value):
          state.instrument = value
          let output = UserDefaults.Dependency.Settings.init(from: state)
          return .run { _ in
            await self.sound.setInstrument(value)
            try? userDefaults.set(encode(output), forKey: .settings)
          }
          
        case let .setTuning(value):
          state.tuning = value
          let output = UserDefaults.Dependency.Settings.init(from: state)
          return .run { _ in
            try? userDefaults.set(encode(output), forKey: .settings)
          }
          
        case .binding(.set(\.$isRingEnabled, false)):
          guard let inFlight = state.inFlight else { return .none }
          return .run { send in
            try await clock.sleep(for: .seconds(1))
            await send(.stop(inFlight))
          }
          
        case .binding:
          return .none
        }
        
      case let .setSettings(value):
        state.instrument = value.instrument
        state.tuning = value.tuning
        return .none
        
      case let .play(note):
        state.inFlight = note
        return .run { _ in await sound.play(note) }
        
      case let .stop(note):
        state.inFlight = nil
        return .run { _ in await sound.stop(note) }
        
      case .didCompletePlayAll:
        state.isPlayAllInFlight = false
        return .none
        
      }
    }
  }
}

private extension AppReducer.State {
  var navigationTitle: String {
    instrument.rawValue
  }
  var notes: [SoundClient.Note] {
    switch instrument {
    case .bass:
      Array(tuning.notes.prefix(upTo: 4))
    default:
      Array(tuning.notes)
    }
  }
  func isNoteButtonDisabled(_ note: SoundClient.Note) -> Bool {
    //inFlight == note || isPlayAllInFlight
    isPlayAllInFlight
  }
  var isPlayAllButtonDisabled: Bool {
    isPlayAllInFlight
  }
  var isStopButtonDisabled: Bool {
    inFlight == nil
  }
}

private extension UserDefaults.Dependency.Settings {
  init(from state: AppReducer.State) {
    self = Self(
      instrument: state.instrument,
      tuning: state.tuning
    )
  }
}

// MARK: - SwiftUI

struct AppView: View {
  let store: StoreOf<AppReducer>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      NavigationStack {
        List {
          Header(store: store)
          InstrumentsView(store: store)
          TuningView(store: store)
          RingToggle(store: store)
          TuningButtons(store: store)
          
          Button("Play All") {
            viewStore.send(.playAllButtonTapped)
          }
          .buttonStyle(RoundedRectangleButtonStyle(backgroundColor: .green))
          .disabled(viewStore.isPlayAllButtonDisabled)
          
          Button("Stop") {
            viewStore.send(.stopButtonTapped)
          }
          .buttonStyle(RoundedRectangleButtonStyle())
          .disabled(viewStore.isStopButtonDisabled)
        }
        .navigationTitle(viewStore.navigationTitle)
        .listStyle(.plain)
      }
      .task { await viewStore.send(.task).finish() }
    }
  }
}

private struct Header: View {
  let store: StoreOf<AppReducer>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      Section {
        TabView(selection: viewStore.binding(
          get: \.instrument,
          send: { .setInstrument($0) }
        )) {
          ForEach(SoundClient.Instrument.allCases) { instrument in
            Image(instrument.imageLarge)
              .resizable()
              .scaledToFit()
              .padding(8)
              .clipShape(Circle())
              .frame(maxWidth: .infinity, alignment: .center)
              .tag(instrument)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxWidth: .infinity)
        .frame(height: 200)
      }
      .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
      .background(Color.accentColor.gradient)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .padding(.horizontal)
      .listRowSeparator(.hidden)
    }
  }
}

private struct InstrumentsView: View {
  let store: StoreOf<AppReducer>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      DisclosureGroup {
        HStack {
          ForEach(SoundClient.Instrument.allCases) { instrument in
            Button {
              viewStore.send(.setInstrument(instrument), animation: .spring())
            } label: {
              VStack {
                Image(instrument.imageSmall)
                  .resizable()
                  .scaledToFit()
                  .frame(width: 75, height: 75)
                  .frame(maxWidth: .infinity)
                  .background(.thinMaterial)
                  .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                  .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                      .strokeBorder(lineWidth: 3)
                      .foregroundColor(.accentColor)
                      .opacity(viewStore.instrument == instrument ? 1 : 0)
                  }
                
                Text(instrument.description)
                  .font(.caption)
                  .foregroundColor(viewStore.instrument == instrument ? .primary : .secondary)
                  .fontWeight(.semibold)
              }
              .frame(maxWidth: .infinity)
              .tag(instrument.id)
            }
            .buttonStyle(.plain)
          }
        }
        .frame(maxWidth: .infinity)
      } label: {
        Text("Instrument")
          .font(.title2)
          .bold()
          .foregroundStyle(.primary)
      }
      .listRowSeparator(.hidden, edges: .bottom)
    }
  }
}

private struct TuningView: View {
  let store: StoreOf<AppReducer>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      DisclosureGroup {
        ForEach(SoundClient.InstrumentTuning.allCases) { tuning in
          btn(tuning)
        }
      } label: {
        Text("Tuning")
          .font(.title2)
          .bold()
          .foregroundStyle(.primary)
      }
    }
  }
  
  private func btn(_ tuning: SoundClient.InstrumentTuning) -> some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      let isSelected = viewStore.tuning == tuning
      Button {
        viewStore.send(.setTuning(tuning))
      } label: {
        HStack {
          Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .background { Color.white.opacity(isSelected ? 1 : 0) }
            .clipShape(Circle())
            .overlay {
              Circle()
                .strokeBorder()
                .foregroundColor(.accentColor)
                .opacity(isSelected ? 1 : 0)
            }
          
          Text(tuning.description)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { Color.pink.opacity(0.000001) }
      }
    }
  }
}

private struct RingToggle: View {
  let store: StoreOf<AppReducer>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      VStack(alignment: .leading) {
        Toggle(isOn: viewStore.$isRingEnabled) {
          Text("🔁 Ring")
            .font(.title2)
            .fontWeight(.semibold)
        }
        Text("Allow the note to ring until you tell it stop.")
          .foregroundStyle(.secondary)
      }
    }
  }
}

private struct TuningButtons: View {
  let store: StoreOf<AppReducer>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      VStack {
        HStack {
          ForEach(viewStore.notes) { note in
            Button {
              viewStore.send(.noteButtonTapped(note))
            } label: {
              Text(note.description.prefix(1))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(viewStore.inFlight == note ? Color.green : Color(.systemGroupedBackground))
            }
            .buttonStyle(.plain)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(viewStore.state.isNoteButtonDisabled(note))
          }
        }
      }
      .frame(height: 50)
    }
  }
}

// MARK: - SwiftUI Previews

#Preview {
  AppView(store: Store(
    initialState: AppReducer.State(instrument: .electric),
    reducer: AppReducer.init
  ))
}
