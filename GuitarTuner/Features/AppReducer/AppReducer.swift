import SwiftUI
import ComposableArchitecture
import Tonic
import DependenciesAdditions

@Reducer
struct AppReducer {
  struct State: Equatable {
    var instrument = SoundClient.Instrument.guitar
    var tuning = SoundClient.InstrumentTuning.eStandard
    var inFlightNotes = IdentifiedArrayOf<Note>()
    var isPlayAllInFlight = false
    var isSheetPresented = false
  }
  
  enum Action {
    case play(Note)
    case stop(Note)
    case playAllCancel
    case playAllDidComplete
    case saveSettings
    case loadSettingsResult(UserDefaultsClient.Settings)
    case view(View)
    
    enum View {
      case task
      case noteButtonTapped(Note)
      case playAllStartButtonTapped
      case playAllStopButtonTapped
      case setInstrument(SoundClient.Instrument)
      case setTuning(SoundClient.InstrumentTuning)
      case setIsSheetPresented(Bool)
    }
  }
  
  @Dependency(\.sound) var sound
  @Dependency(\.continuousClock) var clock
  @Dependency(\.userDefaults) var userDefaults
  @Dependency(\.encode) var encode
  @Dependency(\.decode) var decode
  
  enum CancelID: Equatable {
    case playAll
  }
  
  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
      
    case let .play(note):
      state.inFlightNotes.append(note)
      return .run { _ in await sound.play(note) }
      
    case let .stop(note):
      state.inFlightNotes.remove(id: note.id)
      return .run { _ in await sound.stop(note) }
      
    case .playAllCancel:
      state.isPlayAllInFlight = false
      state.inFlightNotes = []
      return .cancel(id: CancelID.playAll.self)
      
    case .playAllDidComplete:
      state.isPlayAllInFlight = false
      return .none
      
    case .saveSettings:
      return .run { [state = state] _ in
        try? userDefaults.set(
          encode(UserDefaultsClient.Settings.init(from: state)),
          forKey: .settings
        )
      }
      
    case let .loadSettingsResult(value):
      state.instrument = value.instrument
      state.tuning = value.tuning
      return .run { _ in await self.sound.setInstrument(value.instrument) }
      
    case let .view(action):
      switch action {
        
      case .task:
        return .run { send in
          await withTaskGroup(of: Void.self) { group in
            group.addTask {
              for await data in userDefaults.dataValues(forKey: .settings) {
                if let value = data.flatMap({
                  try? decode(UserDefaultsClient.Settings.self, from: $0)
                }) {
                  await send(.loadSettingsResult(value))
                }
              }
            }
          }
        }
        
      case .playAllStartButtonTapped:
        guard !state.isPlayAllInFlight else { return .none }
        state.isPlayAllInFlight = true
        return .run { [inFlight = state.inFlightNotes, notes = state.notes] send in
          // stop any playing notes
          for inFlightNote in inFlight {
            await send(.stop(inFlightNote))
          }
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
        .cancellable(id: CancelID.playAll.self)
        
      case .playAllStopButtonTapped:
        return .run { [notes = state.inFlightNotes] send in
          await send(.playAllCancel)
          for note in notes {
            await send(.stop(note))
          }
        }
        
      case let .noteButtonTapped(note):
        guard !state.isPlayAllInFlight else {
          return .run { [inFlightNotes = state.inFlightNotes] send in
            await send(.playAllCancel)
            for note in inFlightNotes {
              await send(.stop(note))
            }
          }
        }
        return .run { [inFlightNotes = state.inFlightNotes] send in
          for inFlightNote in inFlightNotes {
            await send(.stop(inFlightNote))
          }
          if !inFlightNotes.contains(note) {
            await send(.play(note))
          }
          try await clock.sleep(for: .seconds(2))
          await send(.stop(note))
        }
        
      case let .setInstrument(value):
        state.instrument = value
        return .run { send in
          await self.sound.setInstrument(value)
          await send(.playAllCancel)
          await send(.saveSettings)
        }
        
      case let .setTuning(value):
        state.tuning = value
        return .send(.saveSettings)
        
      case let .setIsSheetPresented(value):
        state.isSheetPresented = value
        return .none
      }
    }
  }
}


// MARK: - SwiftUI

struct AppView: View {
  let store: StoreOf<AppReducer>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      NavigationStack {
        VStack {
          instruments
            .padding()
          
          tuning
          Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
          LinearGradient(
            colors: [Color.accentColor.opacity(0.75), .clear],
            startPoint: .top,
            endPoint: .bottom
          )
          .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationTitle(viewStore.navigationTitle)
        .sheet(
          isPresented: viewStore.binding(
            get: \.isSheetPresented,
            send: { .setIsSheetPresented($0) }
          ),
          content: { sheet }
        )
      }
      .task { await viewStore.send(.task).finish() }
    }
  }
}

// MARK: - Instruments

private extension AppView {
  private var instruments: some View {
    WithViewStore(store, observe: \.navigationTitle) { viewStore in
      VStack(spacing: 0) {
        Text(viewStore.state)
          .font(.largeTitle)
          .fontWeight(.bold)
          .fontDesign(.rounded)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical)
          .padding(.bottom)
        
        VStack(spacing: 0) {
          Color.black.frame(height: 250).opacity(0.01)
          Divider()
          
          instrumentPicker
            .padding()
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(lineWidth: 0.75)
            .foregroundColor(Color(.systemGray2))
        }
        .overlay {
          instrumentView
            .frame(height: 275)
            .offset(y: -90)
            .shadow(color: Color.black.opacity(0.15), radius: 10, y: 10)
        }
        .shadow(radius: 10, y: 10)
      }
    }
  }
  
  private var instrumentView: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      TabView(selection: viewStore.binding(get: \.instrument, send: { .setInstrument($0) })) {
        ForEach(SoundClient.Instrument.allCases) { instrument in
          Image(instrument.imageResource)
            .resizable()
            .scaledToFit()
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .center)
            .tag(instrument)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .frame(maxWidth: .infinity)
      .listRowSeparator(.hidden)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
  
  private var instrumentPicker: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      HStack {
        ForEach(SoundClient.Instrument.allCases) { instrument in
          Button {
            viewStore.send(.setInstrument(instrument), animation: .spring())
          } label: {
            VStack {
              Image(instrument.imageResource)
                .resizable()
                .scaledToFit()
                .shadow(color: Color.black.opacity(0.25), radius: 3, y: 5)
                .frame(width: 50, height: 50)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background { Color(.secondarySystemFill).opacity(0.25) }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                  RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(lineWidth: viewStore.instrument == instrument ? 2 : 0.75)
                    .foregroundColor(viewStore.instrument == instrument ? .accentColor : Color(.systemGray2))
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
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }
}
  
// MARK: - Tuning

private extension AppView {
  private var tuning: some View {
    Group {
      VStack {
        tuningHeader
        
        Divider()
        
        tuningNotes
          .frame(maxWidth: .infinity)
          .padding(.vertical)
        
        tuningPlayAll
      }
      .padding()
      .background(.regularMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(lineWidth: 0.75)
          .foregroundColor(Color(.systemGray2))
      }
      .shadow(radius: 10, y: 10)
    }
    .padding(.horizontal)
  }
  
  private var tuningHeader: some View {
    WithViewStore(store, observe: \.tuning, send: { .view($0) }) { viewStore in
      HStack {
        Text(viewStore.state.description)
          .font(.title2)
          .fontWeight(.bold)
          .fontDesign(.rounded)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.bottom, 4)
        
        Button {
          viewStore.send(.setIsSheetPresented(true))
        } label: {
          Image(systemName: "ellipsis")
            .resizable()
            .scaledToFit()
            .frame(width: 20)
        }
        .frame(width: 30, height: 30)
        .background { Color.black.opacity(0.15) }
        .clipShape(Circle())
        .buttonStyle(.plain)
      }
    }
  }
  
  private var tuningNotes: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      HStack {
        ForEach(viewStore.notes) { note in
          Button {
            viewStore.send(.noteButtonTapped(note))
          } label: {
            VStack {
              Text(note.description.prefix(1))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundColor(viewStore.inFlightNotes.contains(note) ? Color.white : .primary)
                .background {
                  viewStore.inFlightNotes.contains(note)
                  ? Color.green.opacity(0.8)
                  : Color(.secondarySystemFill).opacity(0.25)
                }
                .clipShape(Circle())
                .overlay {
                  Circle()
                    .strokeBorder(lineWidth: 0.75)
                    .foregroundColor(Color(.systemGray3))
                }
                .frame(width: 50, height: 50)
            }
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
  
  private var tuningPlayAll: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      Button {
        viewStore.send(
          viewStore.inFlightNotes.isEmpty
          ? .playAllStartButtonTapped
          : .playAllStopButtonTapped
        )
      } label: {
        Text(viewStore.inFlightNotes.isEmpty ? "Play All" : "Stop")
          .font(.headline)
          .fontWeight(.semibold)
          .fontDesign(.rounded)
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .padding()
          .background {
            ZStack {
              viewStore.inFlightNotes.isEmpty ? Color.green : Color.red
              Color.black.opacity(0.15)
            }
          }
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .strokeBorder(lineWidth: 0.75)
              .foregroundColor(viewStore.inFlightNotes.isEmpty ? Color.green : Color.red)
          }
          .shadow(radius: 10, y: 10)
      }
    }
  }
}

// MARK: - Sheet

private extension AppView {
  private var sheet: some View {
    WithViewStore(store, observe: { $0 }, send: { .view($0) }) { viewStore in
      NavigationStack {
        List {
          Section("Tuning") {
            Picker(selection: viewStore.binding(get: \.tuning, send: { .setTuning($0) }), label: EmptyView()) {
              ForEach(SoundClient.InstrumentTuning.allCases) { tuning in
                Text(tuning.description)
                  .tag(tuning)
              }
            }
            .pickerStyle(.inline)
            .labelsHidden()
          }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .toolbar {
          Button("Done") {
            viewStore.send(.setIsSheetPresented(false))
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
