// SPDX-License-Identifier: (see LICENSE)
// Mayam — Documentation & Packaging Validation Tests

import XCTest
import Foundation

final class DocumentationTests: XCTestCase {

    // MARK: - Helper

    /// Returns the repository root by walking up from the test bundle.
    private func repoRoot() throws -> URL {
        // The working directory during `swift test` is the package root.
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        // Verify this looks like the repo root by checking for Package.swift.
        let packageSwift = cwd.appendingPathComponent("Package.swift")
        guard FileManager.default.fileExists(atPath: packageSwift.path) else {
            throw XCTSkip("Unable to locate repository root — Package.swift not found at \(cwd.path)")
        }
        return cwd
    }

    /// Asserts that a file exists at the given relative path under the repo root
    /// and optionally checks that it contains specific substrings.
    private func assertFileExists(
        relativePath: String,
        containingAll substrings: [String] = [],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let root = try repoRoot()
        let filePath = root.appendingPathComponent(relativePath).path
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: filePath),
            "Expected file at \(relativePath) does not exist",
            file: file,
            line: line
        )
        if !substrings.isEmpty {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            for substring in substrings {
                XCTAssertTrue(
                    content.contains(substring),
                    "\(relativePath) should contain \"\(substring)\"",
                    file: file,
                    line: line
                )
            }
        }
    }

    // MARK: - Documentation File Existence Tests

    func test_conformanceStatement_exists_andContainsRequiredSections() throws {
        try assertFileExists(
            relativePath: "docs/CONFORMANCE_STATEMENT.md",
            containingAll: [
                "Conformance Statement",
                "MAYAM",
                "Transfer Syntax",
                "Storage SOP",
                "1.2.840.10008.1.2",
                "IHE"
            ]
        )
    }

    func test_administratorGuide_exists_andContainsRequiredSections() throws {
        try assertFileExists(
            relativePath: "docs/ADMINISTRATOR_GUIDE.md",
            containingAll: [
                "Administrator Guide",
                "Installation",
                "Configuration",
                "LDAP",
                "Backup",
                "Troubleshooting"
            ]
        )
    }

    func test_deploymentGuide_exists_andContainsRequiredSections() throws {
        try assertFileExists(
            relativePath: "docs/DEPLOYMENT_GUIDE.md",
            containingAll: [
                "Deployment Guide",
                "Docker",
                "Docker Compose",
                "macOS",
                "Linux",
                "systemd"
            ]
        )
    }

    func test_releaseNotes_exists_andContainsVersion() throws {
        try assertFileExists(
            relativePath: "RELEASE_NOTES.md",
            containingAll: [
                "v1.0.0",
                "Release Notes",
                "DICOM",
                "DICOMweb"
            ]
        )
    }

    func test_projectWebsite_exists_andContainsStructure() throws {
        try assertFileExists(
            relativePath: "docs/website/index.html",
            containingAll: [
                "<!DOCTYPE html>",
                "Mayam",
                "PACS",
                "Raster Lab"
            ]
        )
    }

    // MARK: - API Reference Tests

    func test_adminAPISpec_exists_andIsValidOpenAPI() throws {
        try assertFileExists(
            relativePath: "docs/api/admin-api.yaml",
            containingAll: [
                "openapi:",
                "/auth/login",
                "/nodes",
                "/users",
                "Bearer"
            ]
        )
    }

    func test_dicomwebAPISpec_exists_andIsValidOpenAPI() throws {
        try assertFileExists(
            relativePath: "docs/api/dicomweb-api.yaml",
            containingAll: [
                "openapi:",
                "/studies",
                "QIDO-RS",
                "WADO-RS",
                "STOW-RS",
                "/health"
            ]
        )
    }

    func test_apiReadme_exists() throws {
        try assertFileExists(
            relativePath: "docs/api/README.md",
            containingAll: ["OpenAPI"]
        )
    }

    // MARK: - Packaging File Existence Tests

    func test_macOSInstallerScript_exists_andIsShellScript() throws {
        try assertFileExists(
            relativePath: "packaging/macos/build_installer.sh",
            containingAll: [
                "#!/usr/bin/env bash",
                "pkgbuild",
                ".dmg"
            ]
        )
    }

    func test_macOSDistributionXML_exists() throws {
        try assertFileExists(
            relativePath: "packaging/macos/Distribution.xml",
            containingAll: [
                "com.raster-lab.mayam",
                "Mayam"
            ]
        )
    }

    func test_macOSPostinstall_exists() throws {
        try assertFileExists(
            relativePath: "packaging/macos/scripts/postinstall",
            containingAll: ["mayam"]
        )
    }

    func test_homebrewFormula_exists_andHasRequiredFields() throws {
        try assertFileExists(
            relativePath: "packaging/homebrew/mayam.rb",
            containingAll: [
                "class Mayam",
                "desc",
                "homepage",
                "swift"
            ]
        )
    }

    func test_debianBuildScript_exists() throws {
        try assertFileExists(
            relativePath: "packaging/linux/build_deb.sh",
            containingAll: [
                "#!/usr/bin/env bash",
                "dpkg-deb"
            ]
        )
    }

    func test_rpmSpec_exists_andHasRequiredFields() throws {
        try assertFileExists(
            relativePath: "packaging/linux/rpm/mayam.spec",
            containingAll: [
                "Name:",
                "Version:",
                "swift build"
            ]
        )
    }

    // MARK: - Milestone Completion Tests

    func test_milestoneMD_marksM15AsComplete() throws {
        try assertFileExists(
            relativePath: "milestones.md",
            containingAll: [
                "Milestone 15 — Documentation, Packaging & Release ✅ Complete"
            ]
        )
    }

    func test_readme_containsDocumentationSection() throws {
        try assertFileExists(
            relativePath: "README.md",
            containingAll: [
                "## Documentation",
                "CONFORMANCE_STATEMENT.md",
                "ADMINISTRATOR_GUIDE.md",
                "DEPLOYMENT_GUIDE.md",
                "admin-api.yaml",
                "dicomweb-api.yaml"
            ]
        )
    }
}
