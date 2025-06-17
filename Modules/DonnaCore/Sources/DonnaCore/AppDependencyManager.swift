import Foundation

/// Tiny resolver good enough for this demo.
public final class AppDependencyManager {
    public static let shared = AppDependencyManager()
    private var factories: [ObjectIdentifier: () -> Any] = [:]

    private init() {}

    public func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        factories[ObjectIdentifier(type)] = factory
    }

    public func resolve<T>(_ type: T.Type = T.self) -> T {
        guard let value = factories[ObjectIdentifier(type)]?() as? T else {
            fatalError("No factory registered for \(type)")
        }
        return value
    }
}