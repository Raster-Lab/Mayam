// SPDX-License-Identifier: (see LICENSE)
// Mayam — Graceful Shutdown Handler

import Foundation

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

// MARK: - Global Signal State

/// Global storage for shutdown signal state, accessible from C signal handlers.
private let _globalShutdownFlag = ManagedAtomic(false)
private nonisolated(unsafe) var _globalContinuation: AsyncStream<Void>.Continuation?

/// C-compatible signal handler function.
private func _handleShutdownSignal(_: Int32) {
    if !_globalShutdownFlag.value {
        _globalShutdownFlag.setValue(true)
        _globalContinuation?.yield()
        _globalContinuation?.finish()
    }
}

// MARK: - GracefulShutdown

/// Manages graceful server shutdown with signal handling and in-flight
/// association draining.
///
/// `GracefulShutdown` installs handlers for POSIX signals (`SIGTERM`, `SIGINT`)
/// and provides an async stream that subsystems can await to begin their
/// shutdown sequences.
///
/// ## Usage
///
/// ```swift
/// let shutdown = GracefulShutdown()
/// shutdown.installSignalHandlers()
///
/// // In the server run loop:
/// for await _ in shutdown.shutdownSignals() {
///     await server.shutdown()
/// }
/// ```
///
/// Reference: Milestone 13 — Graceful shutdown with in-flight association draining
public final class GracefulShutdown: Sendable {

    // MARK: - Stored Properties

    /// Async stream that yields when a shutdown signal is received.
    private let stream: AsyncStream<Void>

    /// Continuation for programmatic triggers.
    private let continuation: AsyncStream<Void>.Continuation

    /// Per-instance shutdown flag.
    private let _isShuttingDown: ManagedAtomic<Bool>

    // MARK: - Initialiser

    /// Creates a new graceful shutdown handler.
    public init() {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        self.stream = stream
        self.continuation = continuation
        self._isShuttingDown = ManagedAtomic(false)
        _globalContinuation = continuation
    }

    // MARK: - Public Methods

    /// Installs POSIX signal handlers for `SIGTERM` and `SIGINT`.
    ///
    /// When either signal is received, the shutdown stream yields and the
    /// server begins its graceful shutdown sequence.
    public func installSignalHandlers() {
        signal(SIGTERM, _handleShutdownSignal)
        signal(SIGINT, _handleShutdownSignal)
    }

    /// Returns an async stream that yields once when a shutdown signal is received.
    ///
    /// - Returns: An ``AsyncStream`` that yields `Void` on shutdown.
    public func shutdownSignals() -> AsyncStream<Void> {
        stream
    }

    /// Whether the shutdown sequence has been triggered.
    public var isShuttingDown: Bool {
        _isShuttingDown.value
    }

    /// Programmatically triggers shutdown (useful for testing).
    public func trigger() {
        if !_isShuttingDown.value {
            _isShuttingDown.setValue(true)
            continuation.yield()
            continuation.finish()
        }
    }
}

// MARK: - ManagedAtomic

/// A minimal thread-safe value wrapper using `os_unfair_lock` on Darwin
/// and `pthread_mutex_t` on Linux.
///
/// - Note: Used internally by ``GracefulShutdown`` for signal-safe flag checks.
final class ManagedAtomic<Value: Sendable>: @unchecked Sendable {

    #if canImport(Darwin)
    private var _lock = os_unfair_lock()
    #else
    private var _lock = pthread_mutex_t()
    #endif
    private var _value: Value

    init(_ value: Value) {
        self._value = value
        #if !canImport(Darwin)
        pthread_mutex_init(&_lock, nil)
        #endif
    }

    deinit {
        #if !canImport(Darwin)
        pthread_mutex_destroy(&_lock)
        #endif
    }

    var value: Value {
        lock()
        defer { unlock() }
        return _value
    }

    func setValue(_ newValue: Value) {
        lock()
        _value = newValue
        unlock()
    }

    private func lock() {
        #if canImport(Darwin)
        os_unfair_lock_lock(&_lock)
        #else
        pthread_mutex_lock(&_lock)
        #endif
    }

    private func unlock() {
        #if canImport(Darwin)
        os_unfair_lock_unlock(&_lock)
        #else
        pthread_mutex_unlock(&_lock)
        #endif
    }
}
