import Foundation
import UserDefaultsDependency

extension UserDefaultsClient {
  /// Type-safe UserDefaults key.
  enum Key: String, Identifiable, Equatable {
    var id: Self { self }
    case settings = "Settings"
  }
  
  /// Type-safe way of setting data for a key.
  func set(_ data: Data, forKey key: Key) throws {
    self.set(data, forKey: key.rawValue)
  }
  
  /// Type-safe way of getting data for a key.
  func dataValues(forKey key: Key) -> AsyncStream<Data?> {
    self.dataValues(forKey: key.rawValue)
  }
}
