import Foundation
public struct SessionToken: Sendable { public let id = UUID() }
public protocol AudioRecordingService: Sendable {
  func start() async throws -> SessionToken
  func stop(_ token: SessionToken) async throws
}
