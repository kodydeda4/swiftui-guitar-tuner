import SwiftUI
import ComposableArchitecture
import DependenciesAdditions

// sound only works when connected to an external audio source.

struct AppReducer: Reducer {
  struct State: Equatable {
    var settings = UserDefaults.Dependency.Settings()
    var inFlight: SoundClient.Note?
    var isPlayAllInFlight = false
    @BindingState var isRingEnabled = false
    @PresentationState var destination: EditSettings.State?
  }
  
  enum Action: Equatable {
    case view(View)
    case setSettings(UserDefaults.Dependency.Settings)
    case play(SoundClient.Note)
    case stop(SoundClient.Note)
    case playAllDidComplete
    case destination(PresentationAction<EditSettings.Action>)
    
    enum View: BindableAction, Equatable {
      case task
      case editSettingsButtonTapped
      case noteTapped(SoundClient.Note)
      case playAllButtonTapped
      case stopButtonTapped
      case binding(BindingAction<State>)
    }
  }
  
  @Dependency(\.sound) var sound
  @Dependency(\.continuousClock) var clock
  @Dependency(\.userDefaults) var userDefaults
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
          
        case .editSettingsButtonTapped:
          state.destination = .init(
            instrument: state.settings.instrument,
            tuning: state.settings.tuning
          )
          return .none
          
        case .playAllButtonTapped:
          guard !state.isPlayAllInFlight else { return .none }
          state.isPlayAllInFlight = true
          return .run { [notes = state.notes] send in
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
          
        case .stopButtonTapped:
          state.inFlight = nil
          return .none
          
        case let .noteTapped(note):
          return .run { [isRingEnabled = state.isRingEnabled] send in
            await send(.play(note))
            
            if !isRingEnabled {
              try await clock.sleep(for: .seconds(2))
              await send(.stop(note))
            }
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
        state.settings = value
        return .none
        
      case let .play(note):
        state.inFlight = note
        return .run { _ in await sound.play(note) }
        
      case let .stop(note):
        state.inFlight = nil
        return .run { _ in await sound.stop(note) }
        
      case .playAllDidComplete:
        state.isPlayAllInFlight = false
        return .none
        
      case .destination:
        return .none
        
      }
    }
    .ifLet(\.$destination, action: /Action.destination) {
      EditSettings()
    }
  }
}

private extension AppReducer.State {
  var navigationTitle: String {
    settings.instrument.rawValue
  }
  var notes: [SoundClient.Note] {
    switch settings.instrument {
    case .bass:
      Array(settings.tuning.notes.prefix(upTo: 4))
    default:
      Array(settings.tuning.notes)
    }
  }
  func isNoteButtonDisabled(_ note: SoundClient.Note) -> Bool {
    inFlight == note || isPlayAllInFlight
  }
  var isPlayAllButtonDisabled: Bool {
    isPlayAllInFlight
  }
  var isStopButtonDisabled: Bool {
    inFlight == nil
  }
}

// MARK: - SwiftUI

struct AppView: View {
  let store: StoreOf<AppReducer>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      NavigationStack {
        VStack(spacing: 0) {
          Image(viewStore.settings.instrument.imageLarge)
            .resizable()
            .scaledToFit()
            .padding(8)
            .clipShape(Circle())
            .frame(maxWidth: .infinity, alignment: .center)
          
          Spacer()
          Divider()
          
          VStack {
            VStack(alignment: .leading) {
              Toggle(isOn: viewStore.$isRingEnabled) {
                Text("🔁 Ring")
                  .font(.title2)
                  .fontWeight(.semibold)
              }
              Text("Allow the note to ring until you tell it stop.")
                .foregroundStyle(.secondary)
            }
            Divider()
              .padding(.vertical, 8)
            
            HStack {
              ForEach(viewStore.notes) { note in
                Button(action: { viewStore.send(.noteTapped(note)) }) {
                  Text(note.description.prefix(1))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(viewStore.inFlight == note ? Color.green : Color.white)
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(viewStore.state.isNoteButtonDisabled(note))
              }
            }
            .frame(height: 50)
            .padding(.bottom)
            
            Button("Play All") {
              viewStore.send(.playAllButtonTapped)
            }
            .buttonStyle(RoundedRectangleButtonStyle(
              backgroundColor: .green
            ))
            .disabled(viewStore.isPlayAllButtonDisabled)
            
            Button("Stop") {
              viewStore.send(.stopButtonTapped)
            }
            .buttonStyle(RoundedRectangleButtonStyle())
            .disabled(viewStore.isStopButtonDisabled)
          }
          .padding()
          .background(.regularMaterial)
        }
        .frame(maxHeight: .infinity)
        .background(Color.accentColor.gradient)
        .navigationTitle(viewStore.navigationTitle)
        .sheet(
          store: store.scope(state: \.$destination, action: AppReducer.Action.destination),
          content: EditSettingsSheet.init(store:)
        )
        .task { await viewStore.send(.task).finish() }
        .toolbar {
          Button {
            viewStore.send(.editSettingsButtonTapped)
          } label: {
            Image(systemName: "gear")
          }
        }
      }
    }
  }
}

// MARK: - SwiftUI Previews

#Preview {
  AppView(store: Store(
    initialState: AppReducer.State(
      settings: .init(
        instrument: .electric
      )
    ),
    reducer: AppReducer.init
  ))
}
