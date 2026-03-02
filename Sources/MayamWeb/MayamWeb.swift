// SPDX-License-Identifier: (see LICENSE)
// Mayam — MayamWeb Module

import MayamCore

/// The MayamWeb module provides the DICOMweb and Admin REST API layer.
///
/// ## Implemented Services (Milestone 6)
/// - **WADO-RS** — RESTful DICOM object and metadata retrieval.
/// - **QIDO-RS** — RESTful study/series/instance queries.
/// - **STOW-RS** — RESTful DICOM object storage via multipart POST.
/// - **UPS-RS** — Unified Procedure Step workitem management.
/// - **WADO-URI** — Legacy single-frame retrieval for backward compatibility.
///
/// ## Admin API (Milestone 7)
/// - **AdminServer** — HTTP server for the web administration console.
/// - **AdminRouter** — Request routing for all `/admin/api/` endpoints.
/// - Authentication via HS256 JWT bearer tokens.
/// - DICOM node management, storage pool reporting, integrity checking.
/// - First-run setup wizard and server settings management.
public enum MayamWeb {
    /// The current version of the MayamWeb module.
    public static let version = "0.7.0"
}

