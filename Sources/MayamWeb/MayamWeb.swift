// SPDX-License-Identifier: (see LICENSE)
// Mayam — MayamWeb Module

import MayamCore

/// The MayamWeb module provides the DICOMweb and Admin REST API layer.
///
/// ## Planned Services
/// - **WADO-RS** — RESTful DICOM object retrieval.
/// - **QIDO-RS** — RESTful study/series/instance queries.
/// - **STOW-RS** — RESTful DICOM object storage.
/// - **UPS-RS** — Unified Procedure Step management.
/// - **Admin API** — Server administration endpoints.
///
/// > Note: Full implementation is part of Milestones 6 and 7.
public enum MayamWeb {
    /// The current version of the MayamWeb module.
    public static let version = "0.1.0"
}
