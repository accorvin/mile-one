@testable import MileOne
import Foundation

final class MockTimeProvider: TimeProviding, @unchecked Sendable {
    var currentTime: Date = Date()
    func now() -> Date { currentTime }
}
