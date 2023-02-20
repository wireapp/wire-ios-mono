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
@testable import WireRequestStrategy
import XCTest

class Payload_ConversationTests: MessagingTestBase {

    private typealias AccessRole = ConversationAccessRoleV2

    func test_Conversation_DecodesLegacyAccessRoles_APIVersionV2() throws {
        try test_Conversation_DecodesLegacyAccessRoles(apiVersion: .v2)
    }

    func test_Conversation_DecodesLegacyAccessRoles_APIVersionV3() throws {
        try test_Conversation_DecodesLegacyAccessRoles(apiVersion: .v3)
    }

    private func test_Conversation_DecodesLegacyAccessRoles(apiVersion: APIVersion) throws {
        // GIVEN
        let accessRoles = [
            AccessRole.teamMember,
            AccessRole.guest
        ].map(\.rawValue)

        let legacyAccessRole = ConversationAccessRole.team.rawValue

        let payload: [String: Any] = [
            "access_role": legacyAccessRole,
            "access_role_v2": accessRoles
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [])

        // WHEN
        let conversation = Payload.Conversation(data, apiVersion: apiVersion)

        // THEN
        XCTAssertEqual(conversation?.accessRoles, accessRoles)
        XCTAssertEqual(conversation?.legacyAccessRole, legacyAccessRole)
    }

    func test_Conversation_DecodesAccessRoles_APIVersionV3() throws {
        // GIVEN
        let accessRoles = [
            AccessRole.teamMember,
            AccessRole.guest
        ].map(\.rawValue)

        let payload = [
            "access_role": accessRoles
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [])

        // WHEN
        let conversation = Payload.Conversation(data, apiVersion: .v3)

        // THEN
        XCTAssertEqual(conversation?.accessRoles, accessRoles)
        XCTAssertEqual(conversation?.legacyAccessRole, nil)
    }

    func test_NewConversation_EncodesLegacyAccessRoles_APIVersionV2() throws {
        // GIVEN
        let accessRoles = [
            AccessRole.teamMember,
            AccessRole.guest
        ].map(\.rawValue)

        let legacyAccessRole = ConversationAccessRole.team.rawValue

        let newConversation = Payload.NewConversation(
            legacyAccessRole: legacyAccessRole,
            accessRoles: accessRoles
        )

        // WHEN
        let payloadData = try XCTUnwrap(newConversation.payloadData(apiVersion: .v2))

        let payload = try JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any]
        let payloadLegacyAccessRole = payload?["access_role"] as? String
        let payloadAccessRoles = payload?["access_role_v2"] as? [String]

        // THEN
        XCTAssertEqual(payloadLegacyAccessRole, legacyAccessRole)
        XCTAssertEqual(payloadAccessRoles, accessRoles)
    }

    func test_NewConversation_EncodesAccessRoles_APIVersionV3() throws {
        // GIVEN
        let accessRoles = [
            AccessRole.teamMember,
            AccessRole.guest
        ].map(\.rawValue)

        let newConversation = Payload.NewConversation(accessRoles: accessRoles)

        // WHEN
        let payloadData = try XCTUnwrap(newConversation.payloadData(apiVersion: .v3))

        let payload = try JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any]
        let payloadAccessRoles = payload?["access_role"] as? [String]

        // THEN
        XCTAssertEqual(payloadAccessRoles, accessRoles)
    }

}
