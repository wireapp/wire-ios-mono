//
// Wire
// Copyright (C) 2022 Wire Swiss GmbH
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

import Foundation
import XCTest
@testable import WireDataModel

class MockCoreCryptoKeyProvider: CoreCryptoKeyProvider {

    enum MockError: Error {
        case unmockedMethodCalled
        case coreCryptoKeyError
    }

    typealias CoreCryptoKeyMock = () throws -> Data

    var coreCryptoKeyMock: CoreCryptoKeyMock?

    override func coreCryptoKey() throws -> Data {
        guard let mock = coreCryptoKeyMock else { throw MockError.unmockedMethodCalled }
        return try mock()
    }
}

class CoreCryptoFactoryTests: ZMConversationTestsBase {

    private var mockCoreCryptoKeyProvider: MockCoreCryptoKeyProvider!
    private var sut: CoreCryptoFactory!

    override func setUp() {
        super.setUp()
        mockCoreCryptoKeyProvider = MockCoreCryptoKeyProvider()
        sut = CoreCryptoFactory(coreCryptoKeyProvider: mockCoreCryptoKeyProvider)
    }

    override func tearDown() {
        mockCoreCryptoKeyProvider = nil
        super.tearDown()
    }

    // MARK: - Core crypto configuration

    func test_itReturnsCoreCryptoConfiguration() throws {
        try syncMOC.performGroupedAndWait { context in
            // GIVEN
            // create self client and self user
            self.createSelfClient()
            let selfUser = ZMUser.selfUser(in: context)
            selfUser.domain = "example.domain.com"

            // mock core crypto key
            let key = Data([1, 2, 3])
            self.mockCoreCryptoKeyProvider.coreCryptoKeyMock = {
                return key
            }

            // WHEN
            let configuration = try self.sut.configuration(
                sharedContainerURL: OtrBaseTest.sharedContainerURL,
                syncContext: context
            )

            // THEN
            XCTAssertEqual(configuration.key, key.base64EncodedString())
            XCTAssertEqual(configuration.path, self.expectedPath(selfUser))
            XCTAssertEqual(configuration.clientId, self.expectedClientID(selfUser))
        }
    }

    func test_itThrows_FailedToGetQualifiedClientID() {
        syncMOC.performAndWait {
            // GIVEN
            // we're not creating the self client

            // THEN
            assertItThrows(error: CoreCryptoFactory.ConfigurationError.failedToGetQualifiedClientId) {
                // WHEN
                _ = try sut.configuration(
                    sharedContainerURL: OtrBaseTest.sharedContainerURL,
                    syncContext: syncMOC
                )
            }
        }
    }

    func test_itThrows_FailedToGetCoreCryptoKey() {
        syncMOC.performAndWait {
            // GIVEN
            // create self client and set self user
            createSelfClient()
            let selfUser = ZMUser.selfUser(in: syncMOC)
            selfUser.domain = "example.domain.com"

            // set the core crypto key provider mock
            mockCoreCryptoKeyProvider.coreCryptoKeyMock = {
                throw MockCoreCryptoKeyProvider.MockError.coreCryptoKeyError
            }

            // THEN
            assertItThrows(error: CoreCryptoFactory.ConfigurationError.failedToGetCoreCryptoKey) {
                // WHEN
                _ = try sut.configuration(
                    sharedContainerURL: OtrBaseTest.sharedContainerURL,
                    syncContext: syncMOC
                )
            }
        }
    }

    // MARK: - Helpers

    private func expectedClientID(_ selfUser: ZMUser) -> String {
        return MLSQualifiedClientID(user: selfUser).qualifiedClientId!
    }

    private func expectedPath(_ selfUser: ZMUser) -> String {
        let accountDirectory = CoreDataStack.accountDataFolder(
            accountIdentifier: selfUser.remoteIdentifier,
            applicationContainer: OtrBaseTest.sharedContainerURL
        )
        return accountDirectory.appendingPathComponent("mls").path
    }
}