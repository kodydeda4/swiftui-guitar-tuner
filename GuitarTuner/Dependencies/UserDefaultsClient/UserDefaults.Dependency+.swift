import Foundation
import UserDefaultsDependency

extension UserDefaults.Dependency {
  enum Key: String, Identifiable, Equatable {
    var id: Self { self }
    case settings = "Settings"
  }
  
  func set(_ data: Data, forKey key: Key) throws {
    self.set(data, forKey: key.rawValue)
  }
  
  func dataValues(forKey key: Key) -> AsyncStream<Data?> {
    self.dataValues(forKey: key.rawValue)
  }
}
