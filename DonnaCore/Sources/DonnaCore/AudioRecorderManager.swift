// DonnaCore/Sources/DonnaCore/AudioRecorderManager.swift
import Foundation
import DonnaKit

public actor AudioRecorderManager: AudioRecordingService {
    public init() {}
    public func start() async throws -> SessionToken { .init() }
    public func stop(_ token: SessionToken) async throws {}
}