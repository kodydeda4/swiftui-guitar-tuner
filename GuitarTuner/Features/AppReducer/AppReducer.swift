import SwiftUI
import ComposableArchitecture
import DependenciesAdditions

// sound only works when connected to an external audio source.

struct AppReducer: Reducer {
  struct State: Equatable {
    var settings = UserDefaults.Dependency.Settings()
    @PresentationState var destination: Destination.State?
  }
  
  enum Action: Equatable {
    case view(View)
    case setSettings(UserDefaults.Dependency.Settings)
    case destination(PresentationAction<Destination.Action>)
    
    enum View: Equatable {
      case task
      case editSettingsButtonTapped
      case play(SoundClient.Note)
    }
  }
  
  @Dependency(\.sound) var sound
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
                  if let value = data.flatMap({ try? decode(UserDefaults.Dependency.Settings.self, from: $0) }) {
                    await send(.setSettings(value))
                  }
                }
              }
            }
          }
          
        case .editSettingsButtonTapped:
          state.destination = .editSettings(.init(
            instrument: state.settings.instrument,
            tuning: state.settings.tuning
          ))
          return .none
          
        case let .play(note):
          return .run { _ in await sound.play(note) }
        }
        
      case let .setSettings(value):
        state.settings = value
        return .none
        
      case .destination:
        return .none
        
      }
    }
    .ifLet(\.$destination, action: /Action.destination) {
      Destination()
    }
  }
  
  struct Destination: Reducer {
    enum State: Equatable {
      case editSettings(EditSettings.State)
    }
    enum Action: Equatable {
      case editSettings(EditSettings.Action)
    }
    var body: some ReducerOf<Self> {
      Scope(state: /State.editSettings, action: /Action.editSettings) {
        EditSettings()
      }
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
          
          HStack {
            ForEach(viewStore.notes) { note in
              Button(action: { viewStore.send(.play(note)) }) {
                Text(note.description.prefix(1))
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
                  .background(.thinMaterial)
              }
              .buttonStyle(.plain)
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
          }
          .padding()
          .background(.regularMaterial)
          .frame(height: 75)
        }
        .frame(maxHeight: .infinity)
        .background(Color.accentColor.gradient)
        .navigationTitle(viewStore.navigationTitle)
        .sheet(
          store: store.scope(state: \.$destination, action: AppReducer.Action.destination),
          state: /AppReducer.Destination.State.editSettings,
          action: AppReducer.Destination.Action.editSettings,
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
    initialState: AppReducer.State(),
    reducer: AppReducer.init
  ))
}
