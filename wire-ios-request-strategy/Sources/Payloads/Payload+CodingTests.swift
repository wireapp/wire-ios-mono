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

import Foundation
import XCTest

@testable import WireRequestStrategy

private struct CodableAPIVersionAwareObject: CodableAPIVersionAware {

    enum CodingKeys: CodingKey { }

    typealias InitCall = (Decoder, APIVersion)

    var initCalls = [InitCall]()

    init(from decoder: Decoder, apiVersion: APIVersion) throws {
        initCalls.append((decoder, apiVersion))
    }

    // `encode(to:apiVersion:)` is non-mutable so we need to set up a mock
    typealias MockEncode = (Encoder, APIVersion) -> Void
    var mockEncode: MockEncode?

    func encode(to encoder: Encoder, apiVersion: APIVersion) throws {
        mockEncode?(encoder, apiVersion)
    }

    init() { }
}

private struct CodableObject: Codable {
    enum CodingKeys: CodingKey { }

    var initCalls = [Decoder]()

    init(from decoder: Decoder) throws {
        initCalls.append(decoder)
    }

    // `encode(to encoder: Encoder)` is non-mutable so we need to set up a mock
    typealias MockEncode = (Encoder) -> Void
    var mockEncode: MockEncode?

    func encode(to encoder: Encoder) throws {
        mockEncode?(encoder)
    }

    init() { }
}

class Payload_CodingTests: XCTestCase {

    var data: Data!

    override func setUp() {
        super.setUp()
        data = try! JSONSerialization.data(withJSONObject: ["foo": "bar"], options: [])
        BackendInfo.apiVersion = nil
    }

    override func tearDown() {
        BackendInfo.apiVersion = .v3
        data = nil
        super.tearDown()
    }

    // MARK: - Codable: API version

    func test_itSetsAPIVersionOnEncoder() throws {
        // Given
        var object = CodableObject()

        var encoder: Encoder?
        object.mockEncode = {
            encoder = $0
        }

        // When
        _ = object.payloadData(apiVersion: .v3)

        // Then
        XCTAssertEqual(encoder?.apiVersion, .v3)
    }

    func test_itSetsAPIVersionOnDecoder() {
        // When
        let object = CodableObject(data, apiVersion: .v3)

        // Then
        XCTAssertEqual(object?.initCalls.count, 1)
        XCTAssertEqual(object?.initCalls.first?.apiVersion, .v3)
    }

    // MARK: - CodableAPIVersionAware

    func test_EncodingThrows_MissingAPIVersion() {
        // Given
        let encoder = JSONEncoder()
        let object = CodableAPIVersionAwareObject()

        // When / Then
        XCTAssertThrowsError(try encoder.encode(object)) {
            XCTAssertEqual($0 as? APIVersionAwareCodingError, .missingAPIVersion)
        }
    }

    func test_DecodingThrows_MissingAPIVersion() {
        // Given
        let decoder = JSONDecoder()

        // When / Then
        XCTAssertThrowsError(
            try decoder.decode(CodableAPIVersionAwareObject.self, from: data)
        ) {
            XCTAssertEqual($0 as? APIVersionAwareCodingError, .missingAPIVersion)
        }
    }

    func test_itEncodesWithAPIVersion() {
        // Given
        var object = CodableAPIVersionAwareObject()

        var apiVersion: APIVersion?
        object.mockEncode = { _, version in
            apiVersion = version
        }

        // When
        _ = object.payloadData(apiVersion: .v3)

        // Then
        XCTAssertEqual(apiVersion, .v3)
    }

    func test_itDecodesWithAPIVersion() {
        // When
        let object = CodableAPIVersionAwareObject(data, apiVersion: .v3)

        // Then
        XCTAssertEqual(object?.initCalls.count, 1)
        XCTAssertEqual(object?.initCalls.first?.1, .v3)
    }

}
