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
@testable import WireDataModel

class ZMMessageTests_ExpirationReasonCode: BaseZMClientMessageTests {

    func testThatExpirationReasonCodeIsNotNil_DeliveryStateIsFailedToSend() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.remoteIdentifier = UUID.create()
        let message: ZMMessage = try! conversation.appendText(content: "Hallo") as! ZMMessage
        message.serverTimestamp = Date.init(timeIntervalSinceNow: -20)

        // when
        message.expire()

        // then
        XCTAssertEqual(message.deliveryState, ZMDeliveryState.failedToSend)
        XCTAssertTrue(message.isExpired)
        XCTAssertEqual(message.expirationReasonCode, 0)
    }

    func testThatExpirationReasonCodeIsNil_DeliveryStateIsSent() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.remoteIdentifier = UUID.create()
        let message: ZMClientMessage = try! conversation.appendText(content: "Hallo") as! ZMClientMessage
        message.serverTimestamp = Date.init(timeIntervalSinceNow: -50)

        // when
        message.expire()
        XCTAssertEqual(message.deliveryState, ZMDeliveryState.failedToSend)
        XCTAssertTrue(message.isExpired)
        XCTAssertEqual(message.expirationReasonCode, 0)

        message.markAsSent()

        // then
        XCTAssertEqual(message.deliveryState, ZMDeliveryState.sent)
        XCTAssertFalse(message.isExpired)
        XCTAssertNil(message.expirationReasonCode)
    }

    func testExpirationReasonsParsing() {
        // given
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.remoteIdentifier = UUID.create()
        let message: ZMMessage = try! conversation.appendText(content: "Hallo") as! ZMMessage
        message.serverTimestamp = Date.init(timeIntervalSinceNow: -20)

        // when
        message.expirationReasonCode = nil

        // then
        XCTAssertFalse(message.isExpired)
        XCTAssertEqual(message.failedToSendReason, .unknown)

        // when
        message.expire()
        message.expirationReasonCode = 0

        // then
        XCTAssertTrue(message.isExpired)
        XCTAssertEqual(message.failedToSendReason, .unknown)

        // when
        message.expire()
        message.expirationReasonCode = 1

        // then
        XCTAssertTrue(message.isExpired)
        XCTAssertEqual(message.failedToSendReason, .federationRemoteError)
    }

}

