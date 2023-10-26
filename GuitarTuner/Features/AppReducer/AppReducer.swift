import SwiftUI
import ComposableArchitecture
import DependenciesAdditions

// sound only works when connected to an external audio source.

struct AppReducer: Reducer {
  struct State: Equatable {
    var settings = UserDefaults.Dependency.Settings()
    var inFlight: SoundClient.Note?
    @PresentationState var destination: EditSettings.State?
  }
  
  enum Action: Equatable {
    case view(View)
    case setSettings(UserDefaults.Dependency.Settings)
    case play(SoundClient.Note)
    case stop(SoundClient.Note)
    case destination(PresentationAction<EditSettings.Action>)
    
    enum View: Equatable {
      case task
      case editSettingsButtonTapped
      case noteTapped(SoundClient.Note)
      case playAllButtonTapped
      case stopButtonTapped
    }
  }
  
  @Dependency(\.sound) var sound
  @Dependency(\.continuousClock) var clock
  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.decode) var decode
  
  var body: some ReducerOf<Self> {
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
          }
          
        case .stopButtonTapped:
          state.inFlight = nil
          return .none
          
        case let .noteTapped(note):
          return .run { send in
            await send(.play(note))
            try await clock.sleep(for: .seconds(1))
            await send(.stop(note))
          }
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
            HStack {
              ForEach(viewStore.notes) { note in
                Button(action: { viewStore.send(.noteTapped(note)) }) {
                  Text(note.description.prefix(1))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(viewStore.inFlight == note ? Color.green : Color.white)
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
