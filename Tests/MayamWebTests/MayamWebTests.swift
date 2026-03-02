// SPDX-License-Identifier: (see LICENSE)
// Mayam — MayamWeb Tests

import XCTest
@testable import MayamWeb

final class MayamWebTests: XCTestCase {

    func test_mayamWeb_version_isSet() {
        XCTAssertEqual(MayamWeb.version, "0.7.0")
    }
}
