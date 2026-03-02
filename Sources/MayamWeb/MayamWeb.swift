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
/// > Note: The Admin API is part of Milestone 7.
public enum MayamWeb {
    /// The current version of the MayamWeb module.
    public static let version = "0.6.0"
}

