import SwiftUI

extension View {
  /// Allows you to create bottom-anchored navigation content.
  func navigationOverlay<Content:View>(content: @escaping () -> Content) -> some View {
    overlay {
      VStack(spacing: 0) {
        Spacer()
        
        Rectangle()
          .fill(
            LinearGradient(
              colors: [.black, .clear],
              startPoint: .bottom,
              endPoint: .top
            )
          )
          .frame(height: 30)
          .opacity(0.035)
        
        Divider().opacity(0.5)
        
        VStack {
          content()
            .padding()
        }
        .background {
          Color(.systemBackground)
            .ignoresSafeArea()
        }
      }
    }
  }
}

// MARK: - SwiftUI Previews

#Preview {
  Text("Hello World").sheet(isPresented: .constant(true)) {
    NavigationView {
      VStack {
        Text("Hello World")
          .font(.title2)
          .fontWeight(.semibold)
          .foregroundColor(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .navigationTitle("Preview")
      .navigationOverlay {
        Button("Click me") {
          //...
        }
        .buttonStyle(RoundedRectangleButtonStyle())
      }
    }
  }
}
