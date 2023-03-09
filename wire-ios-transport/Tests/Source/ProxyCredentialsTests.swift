// Wire
// Copyright (C) 2017 Wire Swiss GmbH
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
import WireTransport
import WireTesting
import XCTest

class ProxyCredentialsTests: ZMTBaseTest {

    func test_persist_storesInformationToTheKeychainDoesNotThrow() throws {
        // GIVEN
        let password = "12345"
        let username = "testUsername"
        let proxy = MockProxy(host: "testHost", port: 20, needsAuthentication: true)

        // WHEN
        let sut = ProxyCredentials(username: username, password: password, proxy: proxy)

        // THEN
        XCTAssertNoThrow(try sut?.persist())
    }

    func test_retrieveFrom_returnsCredentialsIfStoredOneExists() throws {
        // GIVEN
        let password = "123456"
        let username = "testUsername2"
        let proxy = MockProxy(host: "testHost2", port: 20, needsAuthentication: true)
        let storedCredentials = ProxyCredentials(username: username, password: password, proxy: proxy)
        try storedCredentials?.persist()

        // WHEN
        let sut = ProxyCredentials.retrieve(for: proxy)

        // THEN
        XCTAssertNotNil(sut)
        XCTAssertEqual(sut?.username, username)
        XCTAssertEqual(sut?.password, password)
    }

    func test_destroy_returnsTrueIfNotPresent() throws {
        // GIVEN
        let proxy = MockProxy(host: "testHost2", port: 20, needsAuthentication: true)

        // WHEN
        let result = ProxyCredentials.destroy(for: proxy)

        // THEN
        XCTAssertTrue(result)
    }

    func test_destroy_returnsTrueIfDeleted() throws {
        // GIVEN
        let password = "123456"
        let username = "testUsername2"
        let proxy = MockProxy(host: "testHost2", port: 20, needsAuthentication: true)
        let storedCredentials = ProxyCredentials(username: username, password: password, proxy: proxy)
        try storedCredentials?.persist()

        // WHEN
        let result = ProxyCredentials.destroy(for: proxy)

        // THEN
        XCTAssertTrue(result)
    }

}

// MARK: - Mock

final class MockProxy: NSObject, ProxySettingsProvider {

    var host: String
    var port: Int
    var needsAuthentication: Bool

    init(host: String, port: Int, needsAuthentication: Bool) {
        self.host = host
        self.port = port
        self.needsAuthentication = needsAuthentication
    }

    func socks5Settings(proxyUsername: String?, proxyPassword: String?) -> [AnyHashable: Any]? {
        return nil
    }
}
