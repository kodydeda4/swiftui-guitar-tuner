import SwiftUI
import ComposableArchitecture
import Tonic
import DependenciesAdditions

// MARK: - Bugs:
// 1. cancel play-all
// 2. add multiple au instruments - acoustic, electric, bass, ukelele
// 3. fix tuning for ukelele
// 4. figure out a better layout
// 5. add animations
//
// MARK: - Tutorial:
// 1. Getting Started - https://youtu.be/JT-0UDZDAsU?si=pYqavx6mxjU4cREO//
// 2. Sounds - https://youtu.be/-z8ire5WN3U?si=BUcTWYK7vAECFebV&t=470


struct AppReducer: Reducer {
  struct State: Equatable {
    var inFlightNotes = IdentifiedArrayOf<Note>()
    var isPlayAllInFlight = false
    @BindingState var instrument = SoundClient.Instrument.electric
    @BindingState var tuning = SoundClient.InstrumentTuning.eStandard
    @BindingState var isRingEnabled = false
  }
  
  enum Action: Equatable {
    case view(View)
    case setSettings(UserDefaults.Dependency.Settings)
    case play(Note)
    case stop(Note)
    case didCompletePlayAll
    case cancelPlayAll
    
    enum View: BindableAction, Equatable {
      case task
      case noteButtonTapped(Note)
      case playAllButtonTapped
      case binding(BindingAction<State>)
    }
  }
  
  @Dependency(\.sound) var sound
  @Dependency(\.continuousClock) var clock
  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.encode) var encode
  @Dependency(\.decode) var decode
  
  enum CancelID: Equatable {
    case playAll
  }
  
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
          guard !state.isPlayAllInFlight else {
            return .run { [notes = state.inFlightNotes] send in
              await send(.cancelPlayAll)
              for note in notes {
                await send(.stop(note))
              }
            }
          }
          state.isPlayAllInFlight = true
          return .run { [inFlight = state.inFlightNotes, notes = state.notes] send in
            // stop any playing notes
            for inFlightNote in inFlight {
              await send(.stop(inFlightNote))
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
          .cancellable(id: CancelID.playAll.self)

          
        case let .noteButtonTapped(note):
          guard !state.isPlayAllInFlight else {
            return .run { [notes = state.inFlightNotes] send in
              await send(.cancelPlayAll)
              for note in notes {
                await send(.stop(note))
              }
            }
          }
          return .run { [
            inFlight = state.inFlightNotes,
            isRingEnabled = state.isRingEnabled
          ] send in
            for inFlightNote in inFlight {
              await send(.stop(inFlightNote))
            }
            if !inFlight.contains(note) {
              await send(.play(note))
            }
            if !isRingEnabled {
              try await clock.sleep(for: .seconds(2))
              await send(.stop(note))
            }
          }
          
        case .binding(.set(\.$isRingEnabled, false)):
          guard !state.inFlightNotes.isEmpty else { return .none }
          return .run { [inFlightNotes = state.inFlightNotes] send in
            for note in inFlightNotes {
              try await clock.sleep(for: .seconds(1))
              await send(.stop(note))
            }
          }
          
        case .binding:
          let output = UserDefaults.Dependency.Settings.init(from: state)
          return .run { _ in
            try? userDefaults.set(encode(output), forKey: .settings)
          }
        }
        
      case let .setSettings(value):
        state.instrument = value.instrument
        state.tuning = value.tuning
        return .none
        
      case let .play(note):
        state.inFlightNotes.append(note)
        return .run { _ in await sound.play(note) }
        
      case let .stop(note):
        state.inFlightNotes.remove(id: note.id)
        return .run { _ in await sound.stop(note) }
        
      case .didCompletePlayAll:
        state.isPlayAllInFlight = false
        return .none
        
      case .cancelPlayAll:
        state.isPlayAllInFlight = false
        state.inFlightNotes = []
        return .cancel(id: CancelID.playAll.self)
        
      }
    }
  }
}

private extension AppReducer.State {
  var navigationTitle: String {
    instrument.rawValue
  }
  var notes: [Note] {
    switch instrument {
    case .bass:
      Array(tuning.notes.prefix(upTo: 4))
      
    default:
      Array(tuning.notes)
    }
  }
  func isNoteButtonDisabled(_ note: Note) -> Bool {
    isPlayAllInFlight
  }
  var isPlayAllButtonDisabled: Bool {
    isPlayAllInFlight
  }
//  var isStopButtonDisabled: Bool {
//    inFlightNotes.isEmpty
//  }
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
          Spacer().frame(height: 255)
        }
        .navigationTitle(viewStore.navigationTitle)
        .listStyle(.plain)
        .navigationOverlay {
          VStack {
            TuningButtons(store: store)
              .padding(.bottom)
            
            Button(!viewStore.isPlayAllInFlight ? "Play All" : "Stop") {
              viewStore.send(.playAllButtonTapped)
            }
            .buttonStyle(RoundedRectangleButtonStyle(
              backgroundColor: !viewStore.isPlayAllInFlight ? .green : .red
            ))
          }
        }
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
        TabView(selection: viewStore.$instrument) {
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
      Section {
        HStack {
          ForEach(SoundClient.Instrument.allCases) { instrument in
            Button {
              viewStore.send(
                .binding(.set(\.$instrument, instrument)),
                animation: .spring()
              )
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
      } header: {
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
      Section {
        ForEach(SoundClient.InstrumentTuning.allCases) { tuning in
          btn(tuning)
        }
      } header: {
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
        viewStore.send(.binding(.set(\.$tuning, tuning)))
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
      Section {
        EmptyView()
      } header: {
        VStack(alignment: .leading) {
          Toggle(isOn: viewStore.$isRingEnabled) {
            Text("Ring")
              .font(.title2)
              .bold()
              .foregroundColor(.primary)
          }
          Text("Allow the note to ring until you tell it stop.")
        }
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
                .background(viewStore.inFlightNotes.contains(note) ? Color.green : Color(.systemGroupedBackground))
            }
            .buttonStyle(.plain)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
