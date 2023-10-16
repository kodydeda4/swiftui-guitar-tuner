import SwiftUI
import ComposableArchitecture

struct AppReducer: Reducer {
  struct State: Equatable {
    @BindingState var instrument = Instrument.guitar
    @BindingState var tuning = InstrumentTuning.eStandard
  }
  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case play(Note)
  }
  
  @Dependency(\.sound) var sound
  
  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
        
      case .binding:
        return .none
        
      case let .play(note):
        return .run { _ in
          await sound.play(note)
        }
      }
    }
  }
}

private extension AppReducer.State {
  var notes: [Note] {
    instrument == .bass
    ? Array(tuning.notes.prefix(upTo: 4))
    : tuning.notes
  }
}

// MARK: - SwiftUI

struct AppView: View {
  let store: StoreOf<AppReducer>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      NavigationStack {
        Form {
          Section {
            Image(viewStore.instrument.rawValue)
              .resizable()
              .scaledToFit()
              .frame(width: 175)
              .padding()
              .background(GroupBox { Color.clear })
              .clipShape(Circle())
              .frame(maxWidth: .infinity, alignment: .center)
              .listRowBackground(Color.clear)
              .padding(.top)
          }
          Section {
            Picker("Instrument", selection: viewStore.$instrument) {
              ForEach(Instrument.allCases) {
                Text($0.rawValue).tag($0)
              }
            }
            Picker("Tuning", selection: viewStore.$tuning) {
              ForEach(InstrumentTuning.allCases) {
                Text($0.rawValue).tag($0)
              }
            }
          }
          Section {
            HStack {
              ForEach(viewStore.notes) { note in
                Button(action: { viewStore.send(.play(note)) }) {
                  GroupBox {
                    Text(note.description.prefix(1))
                      .frame(maxWidth: .infinity)
                  }
                }
              }
            }
          }
          .buttonStyle(.plain)
          .listRowBackground(Color.clear)
        }
        .listStyle(.inset)
        .navigationTitle("\(viewStore.instrument.rawValue) Tuner")
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
