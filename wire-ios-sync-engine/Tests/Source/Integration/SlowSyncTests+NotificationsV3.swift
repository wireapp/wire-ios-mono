//
// Wire
// Copyright (C) 2023 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import XCTest
import WireTesting
@testable import WireSyncEngine
import WireMockTransport

class SlowSyncTests_NotificationsV3: IntegrationTest {

    override func _setUp() {
        setCurrentAPIVersion(.v3)
        super._setUp()
    }

    override func setUp() {
        super.setUp()
        createSelfUserAndConversation()
        createExtraUsersAndConversations()
    }

    // MARK: - Slow sync with error

    func test_WhenSinceIdParam404DuringQuickSyncItTriggersASlowSync() {
        internalTestSlowSyncIsPerformedDuringQuickSync(withSinceParameterId: self.mockTransportSession.invalidSinceParameter400)
    }

    func test_WhenSinceIdParam400DuringQuickSyncItTriggersASlowSync() {
        internalTestSlowSyncIsPerformedDuringQuickSync(withSinceParameterId: self.mockTransportSession.unknownSinceParameter404)
    }

    func internalTestSlowSyncIsPerformedDuringQuickSync(withSinceParameterId sinceParameter: UUID) {
        // GIVEN
        XCTAssertTrue(login())

        // add an invalid /notifications/since
        self.mockTransportSession.overrideNextSinceParameter = sinceParameter

        // WHEN
        self.performQuickSync()

        // THEN
        let result = wait(withTimeout: 1) {
            self.userSession?.applicationStatusDirectory?.syncStatus.isSlowSyncing == true
        }
        XCTAssertTrue(result, "it should perform slow sync")
    }
}
