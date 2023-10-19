import SwiftUI
import ComposableArchitecture

// sound only works when connected to an external audio source.
struct AppReducer: Reducer {
  struct State: Equatable {
    var instrument = Instrument.acoustic
    var tuning = InstrumentTuning.eStandard
    @PresentationState var destination: Destination.State?
  }
  enum Action: Equatable {
    case play(Note)
    case editSettingsButtonTapped
    case destination(PresentationAction<Destination.Action>)
  }
  
  @Dependency(\.sound) var sound
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
        
      case let .play(note):
        return .run { _ in
          await sound.play(note)
        }
        
      case .editSettingsButtonTapped:
        state.destination = .editSettings(.init(
          instrument: state.instrument,
          tuning: state.tuning
        ))
        return .none
        
      case let .destination(.presented(.editSettings(.dismiss(childState)))):
        state.instrument = childState.instrument
        state.tuning = childState.tuning
        return .send(.destination(.dismiss))
        
      default:
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
    instrument.rawValue
  }
  var notes: [Note] {
    switch instrument {
      //    case .electric:
      //      Array(tuning.notes)
    case .bass:
      Array(tuning.notes.prefix(upTo: 4))
    default:
      Array(tuning.notes)
    }
  }
}

// MARK: - SwiftUI

struct AppView: View {
  let store: StoreOf<AppReducer>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      NavigationStack {
        VStack(spacing: 0) {
          Image(viewStore.instrument.image)
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
