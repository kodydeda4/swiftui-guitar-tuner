import SwiftUI
import ComposableArchitecture
import Tonic
import DependenciesAdditions

// MARK: - Todo:
// 1. replace ukelele with distorted guitar
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
    var instrument = SoundClient.Instrument.electric
    var tuning = SoundClient.InstrumentTuning.eStandard
    var isSheetPresented = false
    var inFlightNotes = IdentifiedArrayOf<Note>()
    var isPlayAllInFlight = false
  }
  
  enum Action: Equatable {
    case play(Note)
    case stop(Note)
    case playAllCancel
    case playAllDidComplete
    case setSettings(UserDefaultsClient.Settings)
    case save
    case view(View)
    
    enum View: Equatable {
      case task
      case noteButtonTapped(Note)
      case playAllButtonTapped
      case stopButtonTapped
      case setInstrument(SoundClient.Instrument)
      case setTuning(SoundClient.InstrumentTuning)
      case setIsSheetPresented(Bool)
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
  
  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
      
    case let .setSettings(value):
      state.instrument = value.instrument
      state.tuning = value.tuning
      return .run { _ in await self.sound.setInstrument(value.instrument) }
      
    case let .play(note):
      state.inFlightNotes.append(note)
      return .run { _ in await sound.play(note) }
      
    case let .stop(note):
      state.inFlightNotes.remove(id: note.id)
      return .run { _ in await sound.stop(note) }
      
    case .playAllCancel:
      state.isPlayAllInFlight = false
      state.inFlightNotes = []
      return .cancel(id: CancelID.playAll.self)
      
    case .playAllDidComplete:
      state.isPlayAllInFlight = false
      return .none
      
    case .save:
      return .run { [state = state] _ in
        try? userDefaults.set(
          encode(UserDefaultsClient.Settings.init(from: state)),
          forKey: .settings
        )
      }
      
    case let .view(action):
      switch action {
        
      case .task:
        return .run { send in
          await withTaskGroup(of: Void.self) { group in
            group.addTask {
              for await data in userDefaults.dataValues(forKey: .settings) {
                if let value = data.flatMap({
                  try? decode(UserDefaultsClient.Settings.self, from: $0)
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
          await send(.playAllDidComplete)
        }
        .cancellable(id: CancelID.playAll.self)
        
      case .stopButtonTapped:
        return .run { [notes = state.inFlightNotes] send in
          await send(.playAllCancel)
          for note in notes {
            await send(.stop(note))
          }
        }
        
      case let .noteButtonTapped(note):
        guard !state.isPlayAllInFlight else {
          return .run { [inFlightNotes = state.inFlightNotes] send in
            await send(.playAllCancel)
            for note in inFlightNotes {
              await send(.stop(note))
            }
          }
        }
        return .run { [inFlightNotes = state.inFlightNotes] send in
          for inFlightNote in inFlightNotes {
            await send(.stop(inFlightNote))
          }
          if !inFlightNotes.contains(note) {
            await send(.play(note))
          }
          try await clock.sleep(for: .seconds(2))
          await send(.stop(note))
        }
        
      case let .setInstrument(value):
        state.instrument = value
        return .run { send in
          await self.sound.setInstrument(value)
          await send(.playAllCancel)
          await send(.save)
        }
        
      case let .setTuning(value):
        state.tuning = value
        return .send(.save)
        
      case let .setIsSheetPresented(value):
        state.isSheetPresented = value
        return .none
      }
    }
  }
}

private extension AppReducer.State {
  var navigationTitle: String {
    instrument.description
  }
  
  var notes: [Note] {
    switch instrument {
    case .bass:
      Array(tuning.notes.prefix(upTo: 4))
    default:
      Array(tuning.notes)
    }
  }
}

private extension UserDefaultsClient.Settings {
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
          header
          
          VStack {
            instruments
              .padding(.vertical)
            tuningButtons
              .padding(.bottom)
            footer
          }
          .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(viewStore.navigationTitle)
        .listStyle(.plain)
        .toolbar {
          Button("Settings") {
            viewStore.send(.setIsSheetPresented(false))
          }
        }
        .sheet(
          isPresented: viewStore.binding(get: \.isSheetPresented, send: { .setIsSheetPresented($0) }),
          content: { sheet }
        )
      }
      .task { await viewStore.send(.task).finish() }
    }
  }
}

private extension AppView {
  private var header: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      TabView(selection: viewStore.binding(get: \.instrument, send: { .setInstrument($0) })) {
        ForEach(SoundClient.Instrument.allCases) { instrument in
          Image(instrument.imageLarge)
            .resizable()
            .scaledToFit()
            .padding(8)
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
  
  private var instruments: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      HStack {
        ForEach(SoundClient.Instrument.allCases) { instrument in
          Button {
            viewStore.send(.setInstrument(instrument), animation: .spring())
          } label: {
            VStack {
              Image(instrument.imageThumbnail)
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
  
  private var tuningButtons: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      HStack {
        ForEach(viewStore.notes) { note in
          Button {
            viewStore.send(.noteButtonTapped(note))
          } label: {
            VStack {
              Text(note.description.prefix(1))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundColor(viewStore.inFlightNotes.contains(note) ? Color.white : .primary)
                .background(viewStore.inFlightNotes.contains(note) ? Color.accentColor : Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                  RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(lineWidth: 2)
                    .foregroundColor(.accentColor)
                    .opacity(viewStore.inFlightNotes.contains(note) ? 1 : 0)
                }
                .frame(width: 50, height: 50)
            }
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(.plain)
          
        }
      }
    }
  }
  
  private var footer: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      HStack {
        Group {
          if !viewStore.isPlayAllInFlight {
            Button("Play All") {
              viewStore.send(.playAllButtonTapped)
            }
            .buttonStyle(RoundedRectangleButtonStyle(backgroundColor: .green))
            .frame(height: 50)
          } else {
            Button("Stop") {
              viewStore.send(.stopButtonTapped)
            }
            .buttonStyle(RoundedRectangleButtonStyle(backgroundColor: .red))
            .frame(height: 50)
          }
        }
        Button {
          viewStore.send(.setIsSheetPresented(true))
        } label: {
          Image(systemName: "gear")
            .resizable()
            .scaledToFit()
        }
        .buttonStyle(RoundedRectangleButtonStyle(backgroundColor: Color(.systemGray)))
        .frame(width: 50, height: 50)
      }
    }
  }
  
  private var sheet: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      NavigationStack {
        List {
          Section("Tuning") {
            Picker(selection: viewStore.binding(get: \.tuning, send: { .setTuning($0) }), label: EmptyView()) {
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
            viewStore.send(.setIsSheetPresented(false))
          }
        }
      }
    }
  }
}

// MARK: - SwiftUI Previews

#Preview {
  AppView(store: Store(
    initialState: AppReducer.State(),
    reducer: AppReducer.init
  ))
}
