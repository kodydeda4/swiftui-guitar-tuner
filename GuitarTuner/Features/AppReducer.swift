import SwiftUI
import ComposableArchitecture

struct AppReducer: Reducer {
  struct State: Equatable {
    @BindingState var instrument = Instrument.acoustic
    @BindingState var tuning: InstrumentTuning? = .eStandard
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
    guard let tuning else { return [] }
    return switch instrument {
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
        List(selection: viewStore.$tuning) {
          Header(store: store)
          InstrumentsView(store: store)
          TuningView(store: store)
        }
        .navigationTitle(viewStore.navigationTitle)
        .listStyle(.plain)
        .toolbar {
          EditButton()
        }
//        .navigationOverlay {
//          HStack {
//            ForEach(viewStore.notes) { note in
//              Button(action: { viewStore.send(.play(note)) }) {
//                GroupBox {
//                  Text(note.description.prefix(1))
//                    .frame(maxWidth: .infinity)
//                }
//              }
//            }
//          }
//        }
      }
    }
  }
}

private struct Header: View {
  let store: StoreOf<AppReducer>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      Section {
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
      }
      .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
      .background(Color.accentColor.gradient)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .padding(.horizontal)
      .listRowSeparator(.hidden)
    }
  }
}

private struct TuningView: View {
  let store: StoreOf<AppReducer>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      Section {
        ForEach(InstrumentTuning.allCases) { tuning in
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
  
  private func btn(_ tuning: InstrumentTuning) -> some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      Button {
        viewStore.send(.binding(.set(\.$tuning, viewStore.tuning != tuning ? tuning : nil)))
      } label: {
        HStack {
          Image(systemName: viewStore.tuning == .some(tuning) ? "checkmark.circle.fill" : "circle")
            .foregroundColor(viewStore.tuning == .some(tuning) ? .accentColor : .secondary)
            .background {
              Color.white.opacity(viewStore.tuning == .some(tuning) ? 1 : 0)
            }
            .clipShape(Circle())
            .overlay {
              Circle()
                .strokeBorder()
                .foregroundColor(.accentColor)
                .opacity(viewStore.tuning == .some(tuning) ? 1 : 0)
            }
          
          Text(tuning.description)
        }
      }
      .buttonStyle(.plain)
    }
  }
}

private struct InstrumentsView: View {
  let store: StoreOf<AppReducer>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      Section {
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

// MARK: - SwiftUI Previews

#Preview {
  AppView(store: Store(
    initialState: AppReducer.State(),
    reducer: AppReducer.init
  ))
}
