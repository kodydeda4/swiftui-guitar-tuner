import SwiftUI
import ComposableArchitecture
import DependenciesAdditions
import Tagged

struct EditSettings: Reducer {
  struct State: Equatable {
    @BindingState var instrument = Instrument.electric
    @BindingState var tuning = InstrumentTuning.eStandard
  }
  
  enum Action: BindableAction, Equatable {
    case doneButtonTapped
    case binding(BindingAction<State>)
  }
  
  @Dependency(\.dismiss) var dismiss
  @Dependency(\.userDefaults) var userDefaults

  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      
      case .doneButtonTapped:
        return .run { [output = state.output] _ in
          try? self.userDefaults.set(output, forKey: .settings)
          await self.dismiss()
        }
        
      default:
        return .none
      }
    }
  }
}

extension EditSettings.State {
  var output: UserDefaults.Dependency.Settings {
    .init(instrument: instrument, tuning: tuning)
  }
}




// MARK: - SwiftUI

struct EditSettingsSheet: View {
  let store: StoreOf<EditSettings>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      NavigationStack {
        List {
          Header(store: store)
          InstrumentsView(store: store)
          TuningView(store: store)
        }
        .navigationTitle("Edit Settings")
        .listStyle(.plain)
        .toolbar {
          Button("Done") {
            viewStore.send(.doneButtonTapped)
          }
        }
      }
    }
  }
}

private struct Header: View {
  let store: StoreOf<EditSettings>
  
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
  let store: StoreOf<EditSettings>
  
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
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)
    }
  }
}

private struct InstrumentsView: View {
  let store: StoreOf<EditSettings>
  
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
  EditSettingsSheet(store: Store(
    initialState: EditSettings.State(),
    reducer: EditSettings.init
  ))
}
