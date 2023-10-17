import SwiftUI
import ComposableArchitecture

struct AppReducer: Reducer {
  struct State: Equatable {
    @BindingState var instrument = Instrument.acoustic
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
        VStack {
          TabView(selection: viewStore.$instrument) {
            ForEach(Instrument.allCases) { instrument in
              Image(instrument.image)
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
          .padding()
          .background(Color(.systemGray6).gradient)
          
          VStack(alignment: .leading) {
            Text("Instrument")
              .font(.title2)
              .fontWeight(.semibold)
              .frame(maxWidth: .infinity, alignment: .leading)
            
            InstrumentsView(store: store)
          }
          .padding(8)
          
          
          Section {
            Picker("Tuning", selection: viewStore.$tuning) {
              ForEach(InstrumentTuning.allCases) {
                Text($0.rawValue).tag($0)
              }
            }
          } header: {
            Text("Tuning")
              .font(.title2)
              .fontWeight(.semibold)
              .frame(maxWidth: .infinity, alignment: .leading)
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
          
          Spacer()
        }
        .listStyle(.inset)
        .navigationTitle(viewStore.navigationTitle)
      }
    }
  }
}

private struct InstrumentsView: View {
  let store: StoreOf<AppReducer>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      HStack {
        ForEach(Instrument.allCases) { instrument in
          Button {
            viewStore.send(.binding(.set(\.$instrument, instrument)), animation: .spring())
          } label: {
            VStack {
              Image(instrument.thumnailImage)
                .resizable()
                .scaledToFit()
                .frame(width: 75, height: 75)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                  RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(lineWidth: 3)
                    .foregroundColor(.accentColor)
                    .opacity(viewStore.instrument == instrument ? 1 : 0)
                }
              
              Text(instrument.description)
                .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .tag(instrument.id)
          }
          .buttonStyle(.plain)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .frame(maxWidth: .infinity)
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
