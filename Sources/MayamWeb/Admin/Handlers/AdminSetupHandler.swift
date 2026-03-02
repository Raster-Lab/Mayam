// SPDX-License-Identifier: (see LICENSE)
// Mayam — Admin Setup Wizard Handler

import Foundation
import MayamCore

// MARK: - AdminSetupHandler

/// Manages the state of the first-run setup wizard.
///
/// The wizard proceeds through five ordered steps.  Once all steps are
/// completed the ``SetupStatus/completed`` flag is set to `true`.
/// The setup may be reset to the initial state via ``reset()``.
public actor AdminSetupHandler {

    // MARK: - Stored Properties

    /// Current setup wizard state.
    private var status: SetupStatus

    // MARK: - Initialiser

    /// Creates a new setup handler in the initial (incomplete) state.
    public init() {
        self.status = SetupStatus(completed: false, setupStep: 0, totalSteps: 5)
    }

    // MARK: - Public Methods

    /// Returns the current setup wizard status.
    ///
    /// - Returns: The current ``SetupStatus``.
    public func getStatus() -> SetupStatus {
        status
    }

    /// Advances the wizard by one step.
    ///
    /// The step counter is incremented up to `totalSteps`.  When the step
    /// counter reaches `totalSteps` the `completed` flag is set to `true`.
    ///
    /// - Returns: The updated ``SetupStatus``.
    @discardableResult
    public func advanceStep() -> SetupStatus {
        let newStep = min(status.setupStep + 1, status.totalSteps)
        let isCompleted = newStep >= status.totalSteps
        status = SetupStatus(
            completed: isCompleted,
            setupStep: newStep,
            totalSteps: status.totalSteps
        )
        return status
    }

    /// Marks the setup wizard as fully complete.
    ///
    /// Sets `setupStep` to `totalSteps` and `completed` to `true`.
    ///
    /// - Returns: The completed ``SetupStatus``.
    @discardableResult
    public func complete() -> SetupStatus {
        status = SetupStatus(
            completed: true,
            setupStep: status.totalSteps,
            totalSteps: status.totalSteps
        )
        return status
    }

    /// Resets the setup wizard to the initial state.
    ///
    /// - Returns: The reset ``SetupStatus``.
    @discardableResult
    public func reset() -> SetupStatus {
        status = SetupStatus(completed: false, setupStep: 0, totalSteps: 5)
        return status
    }
}
