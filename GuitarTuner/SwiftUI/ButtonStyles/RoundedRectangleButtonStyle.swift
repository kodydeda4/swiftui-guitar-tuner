import SwiftUI

struct RoundedRectangleButtonStyle: ButtonStyle {
  var foregroundColor = Color.white
  var backgroundColor = Color.accentColor
  var radius = CGFloat(8)
  var onPress: (() -> Void)? = {}
  
  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .fontWeight(.semibold)
      .foregroundColor(foregroundColor)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity)
      .background {
        backgroundColor.overlay {
          Color.black.opacity(configuration.isPressed ? 0.25 : 0)
        }
      }
      .clipShape(RoundedRectangle(
        cornerRadius: radius,
        style: .continuous
      ))
      .animation(.default, value: configuration.isPressed)
      .onChange(of: configuration.isPressed) { isPressed in
        if let onPress, isPressed {
          onPress()
        }
      }
  }
}

// MARK: - SwiftUI Previews

#Preview {
  Button("Click Me") {
    //...
  }
  .buttonStyle(RoundedRectangleButtonStyle())
  .padding()
}
