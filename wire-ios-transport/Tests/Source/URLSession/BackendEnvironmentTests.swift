//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
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
@testable import WireTransport

class BackendEnvironmentTests: XCTestCase {

    var backendBundle: Bundle!
    var defaultsProd: UserDefaults!
    var defaultsCustom: UserDefaults!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        let mainBundle = Bundle(for: type(of: self))
        guard let backendBundlePath = mainBundle.path(forResource: "Backend", ofType: "bundle") else { XCTFail("Could not find Backend.bundle"); return }
        guard let backendBundle = Bundle(path: backendBundlePath) else { XCTFail("Could not load Backend.bundle"); return }

        self.backendBundle = backendBundle
        defaultsProd = UserDefaults(suiteName: name)
        defaultsCustom = UserDefaults(suiteName: "custom")
        EnvironmentType.production.save(in: defaultsProd)
        EnvironmentType.custom(url: URL(string: "https://custom.backend.com")!).save(in: defaultsCustom)

        continueAfterFailure = true
    }

    override func tearDown() {
        backendBundle = nil
        super.tearDown()
    }

    func createBackendEnvironment() -> BackendEnvironment {
        let configURL = URL(string: "example.com/config.json")!
        let baseURL = URL(string: "some.host.com")!
        let title = "Example"
        let endpoints = BackendEndpoints(
            backendURL: baseURL.appendingPathComponent("backend"),
            backendWSURL: baseURL.appendingPathComponent("backendWS"),
            blackListURL: baseURL.appendingPathComponent("blacklist"),
            teamsURL: baseURL.appendingPathComponent("teams"),
            accountsURL: baseURL.appendingPathComponent("accounts"),
            websiteURL: baseURL,
            countlyURL: baseURL.appendingPathComponent("dummyCountlyURL"))
        let proxySettings = ProxySettings(host: "127.0.0.1", port: 1080, needsAuthentication: true)
        let trust = ServerCertificateTrust(trustData: [])
        let environmentType = EnvironmentType.custom(url: configURL)
        let backendEnvironment = BackendEnvironment(
            title: title,
            environmentType: environmentType,
            endpoints: endpoints,
            proxySettings: proxySettings,
            certificateTrust: trust)

        return backendEnvironment
    }

    func testThatWeCanLoadBackendEndpoints() {

        guard let environment = BackendEnvironment(
            userDefaults: defaultsProd,
            configurationBundle: backendBundle
        ) else {
            XCTFail("Could not read environment data from Backend.bundle"); return
        }

        XCTAssertEqual(environment.backendURL, URL(string: "https://prod-nginz-https.wire.com")!)
        XCTAssertEqual(environment.backendWSURL, URL(string: "https://prod-nginz-ssl.wire.com")!)
        XCTAssertEqual(environment.blackListURL, URL(string: "https://clientblacklist.wire.com/prod")!)
        XCTAssertEqual(environment.websiteURL, URL(string: "https://wire.com")!)
        XCTAssertEqual(environment.teamsURL, URL(string: "https://teams.wire.com")!)
        XCTAssertEqual(environment.accountsURL, URL(string: "https://accounts.wire.com")!)

    }

    func testThatWeCanLoadCustomBackendEndpointsWithProxy() {

        guard
            let path: String = backendBundle
                .path(forResource: "custom", ofType: "json")
        else {
            XCTFail("Could not find configuration for custom")
            return
        }

        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: path))
        else {
            XCTFail("Could not read \(path)")
            return
        }

        guard let environment = BackendEnvironment(
            environmentType: EnvironmentType(userDefaults: defaultsCustom),
            data: data
        ) else {
            XCTFail("Could not read environment data from Backend.bundle")
            return

        }

        XCTAssertEqual(environment.backendURL, URL(string: "https://custom.backend.com")!)
        XCTAssertEqual(environment.backendWSURL, URL(string: "https://custom.backend.com")!)
        XCTAssertEqual(environment.blackListURL, URL(string: "https://clientblacklist.custom.backend.com/prod")!)
        XCTAssertEqual(environment.websiteURL, URL(string: "https://custom.backend.com")!)
        XCTAssertEqual(environment.teamsURL, URL(string: "https://teams.custom.backend.com")!)
        XCTAssertEqual(environment.accountsURL, URL(string: "https://accounts.custom.backend.com")!)

        XCTAssertEqual(environment.proxySettings?.needsAuthentication, .some(false))
        XCTAssertEqual(environment.proxySettings?.host, "192.168.0.152")
        XCTAssertEqual(environment.proxySettings?.port, 1080)
    }

    func testThatWeCanLoadBackendTrust() {
        guard let environment = BackendEnvironment(userDefaults: defaultsProd, configurationBundle: backendBundle) else { XCTFail("Could not read environment data from Backend.bundle"); return }

        guard let trust = environment.certificateTrust as? ServerCertificateTrust else {
            XCTFail(); return
        }

        XCTAssertEqual(trust.trustData.count, 1, "Should have one key")
        guard let data = trust.trustData.first else { XCTFail( ); return }

        let hosts = Set(data.hosts.map(\.value))
        XCTAssertEqual(hosts.count, 5)
        XCTAssertEqual(hosts, Set(["prod-nginz-https.wire.com", "prod-nginz-ssl.wire.com", "prod-assets.wire.com", "www.wire.com", "wire.com"]))
    }

    func testThatWeCanWorkWithoutLoadingTrust() {
        EnvironmentType.staging.save(in: defaultsProd)

        guard let environment = BackendEnvironment(
            userDefaults: defaultsProd,
            configurationBundle: backendBundle
        ) else {
            XCTFail("Could not read environment data from Backend.bundle")
            return
        }

        guard let trust = environment.certificateTrust as? ServerCertificateTrust else {
            XCTFail(); return
        }

        XCTAssertEqual(trust.trustData.count, 0, "We should not have any keys")
    }

    func testThatWeCanSaveCustomBackendInfoToUserDefaults() {
        // given
        let backendEnvironment = createBackendEnvironment()

        // when
        backendEnvironment.save(in: defaultsProd)

        // then
        let loaded = BackendEnvironment(userDefaults: defaultsProd, configurationBundle: backendBundle)

        XCTAssertEqual(loaded?.endpoints.backendURL, backendEnvironment.endpoints.backendURL)
        XCTAssertEqual(loaded?.endpoints.backendWSURL, backendEnvironment.endpoints.backendWSURL)
        XCTAssertEqual(loaded?.endpoints.blackListURL, backendEnvironment.endpoints.blackListURL)
        XCTAssertEqual(loaded?.endpoints.teamsURL, backendEnvironment.endpoints.teamsURL)
        XCTAssertEqual(loaded?.endpoints.accountsURL, backendEnvironment.endpoints.accountsURL)
        XCTAssertEqual(loaded?.endpoints.websiteURL, backendEnvironment.endpoints.websiteURL)
        XCTAssertEqual(loaded?.title, backendEnvironment.title)
        XCTAssertEqual(loaded?.proxySettings?.host, backendEnvironment.proxySettings?.host)
        XCTAssertEqual(loaded?.proxySettings?.port, backendEnvironment.proxySettings?.port)
        XCTAssertEqual(loaded?.proxySettings?.needsAuthentication, backendEnvironment.proxySettings?.needsAuthentication)

    }

    func testThatWeCanMigrateCustomBackendInfoToAnotherUserDefaults() {
        // given
        let migrationUserDefaults = UserDefaults(suiteName: "migration")!
        let backendEnvironment = createBackendEnvironment()
        backendEnvironment.save(in: defaultsProd)

        // when
        BackendEnvironment.migrate(from: defaultsProd, to: migrationUserDefaults)

        // then
        XCTAssertNil(defaultsProd.value(forKey: BackendEnvironment.defaultsKey))
        XCTAssertNil(defaultsProd.value(forKey: EnvironmentType.defaultsKey))

        let migrated = BackendEnvironment(userDefaults: migrationUserDefaults, configurationBundle: backendBundle)

        XCTAssertEqual(migrated?.endpoints.backendURL, backendEnvironment.endpoints.backendURL)
        XCTAssertEqual(migrated?.endpoints.backendWSURL, backendEnvironment.endpoints.backendWSURL)
        XCTAssertEqual(migrated?.endpoints.blackListURL, backendEnvironment.endpoints.blackListURL)
        XCTAssertEqual(migrated?.endpoints.teamsURL, backendEnvironment.endpoints.teamsURL)
        XCTAssertEqual(migrated?.endpoints.accountsURL, backendEnvironment.endpoints.accountsURL)
        XCTAssertEqual(migrated?.endpoints.websiteURL, backendEnvironment.endpoints.websiteURL)
        XCTAssertEqual(migrated?.title, backendEnvironment.title)
    }

}
