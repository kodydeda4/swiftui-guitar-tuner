import SwiftUI
import ComposableArchitecture

struct AppReducer: Reducer {
  struct State: Equatable {
    @BindingState var instrument = Instrument.acoustic
    @BindingState var tuning = InstrumentTuning.eStandard
    @BindingState var isSheetPresented = false
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
        .sheet(isPresented: viewStore.$isSheetPresented) {
          SettingsSheet(store: store)
        }
        .toolbar {
          Button {
            viewStore.send(.binding(.set(\.$isSheetPresented, true)))
          } label: {
            Image(systemName: "gear")
          }
        }
      }
    }
  }
}

private struct SettingsSheet: View {
  let store: StoreOf<AppReducer>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      NavigationStack {
        List {
          Header(store: store)
          InstrumentsView(store: store)
          TuningView(store: store)
          Spacer().frame(height: 120)
        }
        .navigationTitle("Edit Settings")
        .listStyle(.plain)
        .toolbar {
          Button("Done") {
            viewStore.send(.binding(.set(\.$isSheetPresented, false)))
          }
        }
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
