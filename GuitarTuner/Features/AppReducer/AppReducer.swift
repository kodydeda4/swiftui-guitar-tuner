import SwiftUI
import ComposableArchitecture
import Tonic
import DependenciesAdditions

// MARK: - Todo:
// 1. fix tuning for ukelele
// 2. better images
// 3. figure out a better layout
// 4. readme
// 5. appstore
//
// MARK: - Tutorial:
// 1. Getting Started - https://youtu.be/JT-0UDZDAsU?si=pYqavx6mxjU4cREO//
// 2. Sounds - https://youtu.be/-z8ire5WN3U?si=BUcTWYK7vAECFebV&t=470

struct AppReducer: Reducer {
  struct State: Equatable {
    var inFlightNotes = IdentifiedArrayOf<Note>()
    var isPlayAllInFlight = false
    
    var instrument = SoundClient.Instrument.electric
    @BindingState var tuning = SoundClient.InstrumentTuning.eStandard
    @BindingState var isLoopNoteEnabled = false
    @BindingState var isSheetPresented = false
  }
  
  enum Action: Equatable {
    case setSettings(UserDefaults.Dependency.Settings)
    case play(Note)
    case stop(Note)
    case didCompletePlayAll
    case cancelPlayAll
    case view(View)
    
    enum View: BindableAction, Equatable {
      case task
      case noteButtonTapped(Note)
      case playAllButtonTapped
      case stopButtonTapped
      case setInstrument(SoundClient.Instrument)
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
        
      case let .setSettings(value):
        state.instrument = value.instrument
        state.tuning = value.tuning
        return .run { send in
          await self.sound.setInstrument(value.instrument)
        }
        
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
          
        case .stopButtonTapped:
          return .run { [notes = state.inFlightNotes] send in
            await send(.cancelPlayAll)
            for note in notes {
              await send(.stop(note))
            }
          }
          
        case let .noteButtonTapped(note):
          guard !state.isPlayAllInFlight else {
            return .run { [inFlightNotes = state.inFlightNotes] send in
              await send(.cancelPlayAll)
              for note in inFlightNotes {
                await send(.stop(note))
              }
            }
          }
          return .run { [
            inFlightNotes = state.inFlightNotes,
            isLoopEnabled = state.isLoopNoteEnabled
          ] send in
            for inFlightNote in inFlightNotes {
              await send(.stop(inFlightNote))
            }
            if !inFlightNotes.contains(note) {
              await send(.play(note))
            }
            if !isLoopEnabled {
              try await clock.sleep(for: .seconds(2))
              await send(.stop(note))
            }
          }
          
        case let .setInstrument(value):
          state.instrument = value
          return .run { send in
            await self.sound.setInstrument(value)
            await send(.cancelPlayAll)
          }
          
        case .binding(.set(\.$isLoopNoteEnabled, false)):
          guard !state.inFlightNotes.isEmpty else { return .none }
          return .run { [inFlightNotes = state.inFlightNotes] send in
            for note in inFlightNotes {
              try await clock.sleep(for: .seconds(1))
              await send(.stop(note))
            }
          }
          
        case .binding:
          return .run { [state = state] _ in
            try? userDefaults.set(
              encode(UserDefaults.Dependency.Settings.init(from: state)),
              forKey: .settings
            )
          }
        }
      }
    }
  }
}

extension AppReducer.State {
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
        VStack {
          ZStack {
            Header(store: store)
            TuningButtons(store: store)
              .padding()
          }
          //.frame(height: 300)

          VStack {
            InstrumentsView(store: store)
              .padding(.vertical)
            HStack {
              Group {
                if !viewStore.isPlayAllInFlight {
                  Button("Play All") {
                    viewStore.send(.playAllButtonTapped)
                  }
                  .buttonStyle(RoundedRectangleButtonStyle(backgroundColor: .green))
                } else {
                  Button("Stop") {
                    viewStore.send(.stopButtonTapped)
                  }
                  .buttonStyle(RoundedRectangleButtonStyle(backgroundColor: .red))
                }
              }
              Button("⚙️") {
                viewStore.send(.binding(.set(\.$isSheetPresented, true)))
              }
              .buttonStyle(RoundedRectangleButtonStyle(backgroundColor: Color(.systemGray)))
              .frame(width: 50)
            }
          }
          .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(viewStore.navigationTitle)
        .listStyle(.plain)
        .toolbar {
          Button("Settings") {
            viewStore.send(.binding(.set(\.$isSheetPresented, true)))
          }
        }
        .sheet(isPresented: viewStore.$isSheetPresented) {
          NavigationStack {
            List {
              Section {
                Toggle("Loop Note", isOn: viewStore.$isLoopNoteEnabled)
              } footer: {
                Text("Play the note until you stop it.")
              }
              
              Section("Tuning") {
                Picker(selection: viewStore.$tuning, label: EmptyView()) {
                  ForEach(SoundClient.InstrumentTuning.allCases) { tuning in
                    Text(tuning.description)
                      .tag(tuning)
                  }
                }
                .pickerStyle(.inline)
                .labelsHidden()
              }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .toolbar {
              Button("Done") {
                viewStore.send(.binding(.set(\.$isSheetPresented, false)))
              }
            }
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
      TabView(selection: viewStore.binding(get: \.instrument, send: { .setInstrument($0) })) {
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
      .background(LinearGradient(
        colors: [.accentColor, .clear],
        startPoint: .top,
        endPoint: .bottom
      ))
      .listRowSeparator(.hidden)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

private struct InstrumentsView: View {
  let store: StoreOf<AppReducer>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
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
                    .strokeBorder(lineWidth: 2)
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
    }
  }
}

private struct TuningButtons: View {
  let store: StoreOf<AppReducer>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      HStack {
        VStack {
          ForEach(viewStore.notes) { note in
            Button {
              viewStore.send(.noteButtonTapped(note))
            } label: {
              Text(note.description.prefix(1))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                  viewStore.inFlightNotes.contains(note)
                  ? Color.green
                  : Color(.secondarySystemFill)
                )
            }
            .buttonStyle(.plain)
            .clipShape(Circle())
            .frame(width: 50, height: 50)
          }
        }
        Spacer()
      }
    }
  }
}

// MARK: - SwiftUI Previews

#Preview {
  AppView(store: Store(
    initialState: AppReducer.State(
      instrument: .electric,
      isSheetPresented: false
    ),
    reducer: AppReducer.init
  ))
}
