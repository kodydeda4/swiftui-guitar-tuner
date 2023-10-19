import Foundation
import UserDefaultsDependency

extension UserDefaults.Dependency {
  /// Type-safe key-value.
  enum Key: String, Identifiable, Equatable {
    var id: Self { self }
    case settings = "Settings"
  }
  
  func set<T>(_ value: T, forKey key: Key) throws where T: Codable {
    self.set(try JSONEncoder().encode(value), forKey: key.rawValue)
  }
  func dataValues(forKey key: Key) -> AsyncStream<Data?> {
    self.dataValues(forKey: key.rawValue)
  }
}
