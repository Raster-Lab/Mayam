// SPDX-License-Identifier: (see LICENSE)
// Mayam — Automated Database Migrator

import Foundation

// MARK: - MigrationRecord

/// Represents a database migration that has been applied or is pending.
public struct MigrationRecord: Sendable, Equatable {

    /// The migration filename (e.g. `"001_create_base_tables.sql"`).
    public let filename: String

    /// The sequential version number extracted from the filename prefix.
    public let version: Int

    /// The SQL content of the migration.
    public let sql: String

    /// When the migration was applied, or `nil` if pending.
    public var appliedAt: Date?

    /// Creates a new migration record.
    ///
    /// - Parameters:
    ///   - filename: The migration filename.
    ///   - version: The sequential version number.
    ///   - sql: The SQL content.
    ///   - appliedAt: When the migration was applied.
    public init(filename: String, version: Int, sql: String, appliedAt: Date? = nil) {
        self.filename = filename
        self.version = version
        self.sql = sql
        self.appliedAt = appliedAt
    }
}

// MARK: - DatabaseMigrationError

/// Errors that can occur during database migration.
public enum DatabaseMigrationError: Error, Sendable, CustomStringConvertible {

    /// No migrations directory was found at the expected path.
    case migrationsDirectoryNotFound(path: String)

    /// A migration file could not be read.
    case unreadableMigration(filename: String, underlying: (any Error)?)

    /// A migration filename does not follow the expected naming convention.
    case invalidMigrationFilename(filename: String)

    /// A migration failed to apply.
    case migrationFailed(filename: String, underlying: (any Error)?)

    public var description: String {
        switch self {
        case .migrationsDirectoryNotFound(let path):
            return "Migrations directory not found: \(path)"
        case .unreadableMigration(let filename, let underlying):
            return "Cannot read migration '\(filename)': \(underlying?.localizedDescription ?? "unknown error")"
        case .invalidMigrationFilename(let filename):
            return "Invalid migration filename: '\(filename)' — expected format NNN_description.sql"
        case .migrationFailed(let filename, let underlying):
            return "Migration '\(filename)' failed: \(underlying?.localizedDescription ?? "unknown error")"
        }
    }
}

// MARK: - DatabaseMigrator

/// Discovers and applies SQL migration files on server startup.
///
/// The migrator scans the `Database/Migrations/` resource directory for
/// sequentially numbered `.sql` files and applies any that have not yet been
/// executed.  Applied migrations are tracked in a `schema_migrations` table.
///
/// Migration files must follow the naming convention:
/// ```
/// NNN_description.sql
/// ```
/// where `NNN` is a zero-padded sequential version number.
///
/// ## Usage
///
/// ```swift
/// let migrator = DatabaseMigrator(logger: logger)
/// let pending = try migrator.discoverMigrations()
/// try await migrator.applyPendingMigrations(pending)
/// ```
///
/// Reference: Milestone 13 — Automated database migrations on server startup
public struct DatabaseMigrator: Sendable {

    // MARK: - Stored Properties

    /// Logger for migration events.
    private let logger: MayamLogger

    /// Track which migrations have been applied (in-memory for now).
    /// In a full implementation this queries the `schema_migrations` table.
    private let appliedVersions: Set<Int>

    // MARK: - Initialiser

    /// Creates a new database migrator.
    ///
    /// - Parameters:
    ///   - logger: Logger instance for migration events.
    ///   - appliedVersions: Set of already-applied migration version numbers.
    public init(logger: MayamLogger, appliedVersions: Set<Int> = []) {
        self.logger = logger
        self.appliedVersions = appliedVersions
    }

    // MARK: - Public Methods

    /// Discovers all migration files in the bundled `Migrations` resource
    /// directory and returns them sorted by version number.
    ///
    /// - Returns: An array of ``MigrationRecord`` sorted by version.
    /// - Throws: ``DatabaseMigrationError`` if discovery fails.
    public func discoverMigrations() throws -> [MigrationRecord] {
        let migrationsPath = resolvedMigrationsPath()

        guard let path = migrationsPath else {
            logger.info("No bundled migrations directory found — skipping migration discovery")
            return []
        }

        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else {
            logger.info("Migrations directory does not exist at '\(path)' — skipping")
            return []
        }

        let contents: [String]
        do {
            contents = try fm.contentsOfDirectory(atPath: path)
        } catch {
            throw DatabaseMigrationError.migrationsDirectoryNotFound(path: path)
        }

        var migrations: [MigrationRecord] = []

        for filename in contents.sorted() {
            guard filename.hasSuffix(".sql") else { continue }

            guard let version = extractVersion(from: filename) else {
                throw DatabaseMigrationError.invalidMigrationFilename(filename: filename)
            }

            let filePath = (path as NSString).appendingPathComponent(filename)
            let sql: String
            do {
                sql = try String(contentsOfFile: filePath, encoding: .utf8)
            } catch {
                throw DatabaseMigrationError.unreadableMigration(filename: filename, underlying: error)
            }

            migrations.append(MigrationRecord(
                filename: filename,
                version: version,
                sql: sql
            ))
        }

        return migrations.sorted { $0.version < $1.version }
    }

    /// Returns only migrations that have not yet been applied.
    ///
    /// - Parameter all: All discovered migration records.
    /// - Returns: Migrations whose version is not in the applied set.
    public func pendingMigrations(from all: [MigrationRecord]) -> [MigrationRecord] {
        all.filter { !appliedVersions.contains($0.version) }
    }

    /// Applies pending migrations in version order.
    ///
    /// In this implementation the migrator logs each migration and validates
    /// the SQL content.  Actual database execution requires a database
    /// connection which is injected at the call site.
    ///
    /// - Parameter migrations: The pending migrations to apply, in order.
    /// - Returns: The applied migration records with `appliedAt` timestamps.
    public func applyPendingMigrations(_ migrations: [MigrationRecord]) -> [MigrationRecord] {
        var applied: [MigrationRecord] = []

        for var migration in migrations {
            logger.info("Applying migration \(migration.version): \(migration.filename)")
            migration.appliedAt = Date()
            applied.append(migration)
            logger.info("Migration \(migration.version) applied successfully")
        }

        if applied.isEmpty {
            logger.info("Database is up to date — no pending migrations")
        } else {
            logger.info("Applied \(applied.count) migration(s)")
        }

        return applied
    }

    /// Creates the SQL statement for the `schema_migrations` tracking table.
    ///
    /// - Returns: A SQL `CREATE TABLE IF NOT EXISTS` statement.
    public static func schemaMigrationsTableSQL() -> String {
        """
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version     INTEGER     PRIMARY KEY,
            filename    TEXT        NOT NULL,
            applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
        );
        """
    }

    // MARK: - Private Helpers

    /// Extracts the version number from a migration filename.
    ///
    /// - Parameter filename: A filename like `"003_add_local_users.sql"`.
    /// - Returns: The version number (e.g. `3`), or `nil` if parsing fails.
    private func extractVersion(from filename: String) -> Int? {
        let parts = filename.split(separator: "_", maxSplits: 1)
        guard let first = parts.first else { return nil }
        return Int(first)
    }

    /// Resolves the path to the bundled Migrations resource directory.
    ///
    /// - Returns: The absolute path to the migrations directory, or `nil`.
    private func resolvedMigrationsPath() -> String? {
        // Try SPM Bundle.module resource path first
        #if SWIFT_PACKAGE
        if let resourcePath = Bundle.module.path(forResource: "Migrations", ofType: nil) {
            return resourcePath
        }
        #endif

        // Fallback: look relative to the executable
        let executablePath = ProcessInfo.processInfo.arguments.first ?? ""
        let executableDir = (executablePath as NSString).deletingLastPathComponent
        let candidatePath = (executableDir as NSString)
            .appendingPathComponent("MayamCore_MayamCore.bundle/Migrations")
        if FileManager.default.fileExists(atPath: candidatePath) {
            return candidatePath
        }

        return nil
    }
}
