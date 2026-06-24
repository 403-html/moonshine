//
//  WhiskyWineInstallerTests.swift
//  WhiskyKitTests
//
//  This file is part of Whisky.
//
//  Whisky is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Whisky is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Whisky.
//  If not, see https://www.gnu.org/licenses/.
//

import XCTest
import SemanticVersion
@testable import WhiskyKit

final class WhiskyWineInstallerTests: XCTestCase {
    /// Moonshine pins Gcenx Wine Staging 11.2, so the upstream update check must be
    /// disabled — otherwise it would uninstall the pinned Wine and re-run setup against
    /// the wrong (CrossOver-based) feed.
    func testUpstreamUpdateCheckIsDisabled() async {
        let (shouldUpdate, version) = await WhiskyWineInstaller.shouldUpdateWhiskyWine()
        XCTAssertFalse(shouldUpdate, "Upstream Wine auto-update must stay disabled for the Gcenx-pinned fork")
        XCTAssertEqual(version, SemanticVersion(0, 0, 0))
    }
}
