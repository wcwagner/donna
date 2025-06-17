// DonnaKit/Sources/DonnaKit/Protocols.swift
import Foundation
import ActivityKit

/// Opaque handle returned by `AudioRecordingService.start()`.
public struct SessionToken: Sendable, Hashable {
    public let id: UUID
    public init(id: UUID = .init()) { self.id = id }
}

/// Minimal protocol – more verbs later.
public protocol AudioRecordingService: Sendable {
    /// Starts a new recording and returns a token for stop/pause.
    func start() async throws -> SessionToken
    /// Stops the recording identified by `token` and returns the file URL.
    func stop(_ token: SessionToken) async throws -> URL
}