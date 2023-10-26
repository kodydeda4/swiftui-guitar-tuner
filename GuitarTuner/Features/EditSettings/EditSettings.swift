import SwiftUI
import ComposableArchitecture
import DependenciesAdditions
import Tagged

struct EditSettings: Reducer {
  struct State: Equatable {
    var instrument = SoundClient.Instrument.electric
    var tuning = SoundClient.InstrumentTuning.eStandard
  }
  enum Action: Equatable {
    case setInstrument(SoundClient.Instrument)
    case setTuning(SoundClient.InstrumentTuning)
    case doneButtonTapped
  }
  
  @Dependency(\.dismiss) var dismiss
  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.sound) var sound
  @Dependency(\.encode) var encode
  
  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
      
    case let .setInstrument(value):
      state.instrument = value
      return .run { _ in
        await self.sound.setInstrument(value)
      }
      
    case let .setTuning(value):
      state.tuning = value
      return .none
      
    case .doneButtonTapped:
      let output = UserDefaults.Dependency.Settings.init(from: state)
      return .run { _ in
        try? userDefaults.set(encode(output), forKey: .settings)
        await self.dismiss()
      }
    }
  }
}

private extension UserDefaults.Dependency.Settings {
  init(from state: EditSettings.State) {
    self = Self(
      instrument: state.instrument,
      tuning: state.tuning
    )
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
          ToolbarItem(placement: .primaryAction) {
            Button("Done") {
              viewStore.send(.doneButtonTapped)
            }
          }
        }
        .navigationOverlay {
          Button("Done") {
            viewStore.send(.doneButtonTapped)
          }
          .buttonStyle(RoundedRectangleButtonStyle())
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
        TabView(selection: viewStore.binding(
          get: \.instrument,
          send: { .setInstrument($0) }
        )) {
          ForEach(SoundClient.Instrument.allCases) { instrument in
            Image(instrument.imageLarge)
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
        ForEach(SoundClient.InstrumentTuning.allCases) { tuning in
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
  
  private func btn(_ tuning: SoundClient.InstrumentTuning) -> some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      let isSelected = viewStore.tuning == tuning
      Button {
        viewStore.send(.setTuning(tuning))
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
        .background { Color.pink.opacity(0.000001) }
      }
    }
  }
}

private struct InstrumentsView: View {
  let store: StoreOf<EditSettings>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      Section {
        HStack {
          ForEach(SoundClient.Instrument.allCases) { instrument in
            Button {
              viewStore.send(.setInstrument(instrument), animation: .spring())
            } label: {
              VStack {
                Image(instrument.imageSmall)
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
  Text("Hello World").sheet(isPresented: .constant(true)) {
    EditSettingsSheet(store: Store(
      initialState: EditSettings.State(),
      reducer: EditSettings.init
    ))
  }
}
