//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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
import WireUtilities
import WireCryptobox
@testable import WireDataModel

final class UserClientTests: ZMBaseManagedObjectTest {

    func clientWithTrustedClientCount(_ trustedCount: UInt, ignoredClientCount: UInt, missedClientCount: UInt) -> UserClient {
        let client = UserClient.insertNewObject(in: self.uiMOC)

        func userClientSetWithClientCount(_ count: UInt) -> Set<UserClient>? {
            guard count != 0 else { return nil }

            var clients = Set<UserClient>()
            for _ in 0..<count {
                clients.insert(UserClient.insertNewObject(in: uiMOC))
            }
            return clients
        }

        let trustedClient = userClientSetWithClientCount(trustedCount)
        let ignoredClient = userClientSetWithClientCount(ignoredClientCount)
        let missedClient = userClientSetWithClientCount(missedClientCount)

        if let trustedClient = trustedClient { client.trustedClients = trustedClient }
        if let ignoredClient = ignoredClient { client.ignoredClients = ignoredClient }
        client.missingClients = missedClient

        return client
    }

    func testThatItCanInitializeClient() {
        let client = UserClient.insertNewObject(in: self.uiMOC)
        XCTAssertEqual(client.type, .permanent, "Client type should be 'permanent'")
    }

    func testThatItReturnsTrackedKeys() {
        let client = UserClient.insertNewObject(in: self.uiMOC)
        let trackedKeys = client.keysTrackedForLocalModifications()
        XCTAssertTrue(trackedKeys.contains(ZMUserClientMarkedToDeleteKey), "")
        XCTAssertTrue(trackedKeys.contains(ZMUserClientNumberOfKeysRemainingKey), "")
    }

    func testThatItSyncClientsWithNoRemoteIdentifier() {
        let unsyncedClient = UserClient.insertNewObject(in: self.uiMOC)
        let syncedClient = UserClient.insertNewObject(in: self.uiMOC)
        syncedClient.remoteIdentifier = "synced"

        XCTAssertTrue(UserClient.predicateForObjectsThatNeedToBeInsertedUpstream()!.evaluate(with: unsyncedClient))
        XCTAssertFalse(UserClient.predicateForObjectsThatNeedToBeInsertedUpstream()!.evaluate(with: syncedClient))
    }

    func testThatClientCanBeMarkedForDeletion() {
        let client = UserClient.insertNewObject(in: self.uiMOC)
        client.user = ZMUser.selfUser(in: self.uiMOC)

        XCTAssertFalse(client.markedToDelete)
        client.markForDeletion()

        XCTAssertTrue(client.markedToDelete)
        XCTAssertTrue(client.hasLocalModifications(forKey: ZMUserClientMarkedToDeleteKey))
    }

    func testThatItTracksCorrectKeys() {
        let expectedKeys = Set([ZMUserClientMarkedToDeleteKey,
            ZMUserClientNumberOfKeysRemainingKey,
            ZMUserClientMissingKey,
            ZMUserClientNeedsToUpdateSignalingKeysKey,
            ZMUserClientNeedsToUpdateCapabilitiesKey,
            UserClient.needsToUploadMLSPublicKeysKey
        ])

        let client = UserClient.insertNewObject(in: self.uiMOC)
        XCTAssertEqual(client.keysTrackedForLocalModifications(), expectedKeys)
    }

    func testThatTrustingClientsRemovesThemFromIgnoredClientList() {

        let client = clientWithTrustedClientCount(0, ignoredClientCount: 2, missedClientCount: 0)

        let ignoredClient = client.ignoredClients.first!

        client.trustClients(Set(arrayLiteral: ignoredClient))

        XCTAssertFalse(client.ignoredClients.contains(ignoredClient))
        XCTAssertTrue(client.trustedClients.contains(ignoredClient))
    }

    func testThatIgnoringClientsRemovesThemFromTrustedList() {

        let client = clientWithTrustedClientCount(2, ignoredClientCount: 1, missedClientCount: 0)

        let trustedClient = client.trustedClients.first!

        client.ignoreClients(Set(arrayLiteral: trustedClient))

        XCTAssertFalse(client.trustedClients.contains(trustedClient))
        XCTAssertTrue(client.ignoredClients.contains(trustedClient))
    }

    func testThatTrustingClientsRemovesTheNeedToNotifyUser() {
        // Given
        let client = clientWithTrustedClientCount(0, ignoredClientCount: 1, missedClientCount: 0)
        let ignoredClient = client.ignoredClients.first!
        ignoredClient.needsToNotifyUser = true

        // When
        client.trustClient(ignoredClient)

        // Then
        XCTAssertFalse(ignoredClient.needsToNotifyUser)
    }

    func testThatItDeletesASession() {
        var flag = DeveloperFlag.proteusViaCoreCrypto
        flag.isOn = true

        self.syncMOC.performGroupedBlockAndWait {
            // Given
            let otherClient = UserClient.insertNewObject(in: self.syncMOC)
            otherClient.remoteIdentifier = UUID.create().transportString()
            otherClient.user = ZMUser.insertNewObject(in: self.syncMOC)
            otherClient.user?.remoteIdentifier = UUID.create()

            // Mock
            let mockProteusService = MockProteusServiceInterface()
            self.syncMOC.proteusService = mockProteusService

            mockProteusService.deleteSessionId_MockMethod = { _ in
                // No op
            }

            do {
                // When
                try otherClient.deleteSession()
            } catch {
                XCTFail("Unexpected error: \(error)")
            }

            // Then
            XCTAssertEqual(mockProteusService.deleteSessionId_Invocations, [otherClient.proteusSessionID])
        }

        XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        flag.isOn = false
    }

    func testThatItDeletesASession_Legacy() {
        self.syncMOC.performGroupedBlockAndWait {
            // Given
            let selfClient = self.createSelfClient(onMOC: self.syncMOC)

            var preKeys: [(id: UInt16, prekey: String)] = []

            self.syncMOC.zm_cryptKeyStore.encryptionContext.perform({ (sessionsDirectory) in
                preKeys = try! sessionsDirectory.generatePrekeys(0 ..< 2)
            })

            let otherClient = UserClient.insertNewObject(in: self.syncMOC)
            otherClient.remoteIdentifier = UUID.create().transportString()
            otherClient.user = ZMUser.insertNewObject(in: self.syncMOC)
            otherClient.user?.remoteIdentifier = UUID.create()

            guard let preKey = preKeys.first else {
                XCTFail("could not generate prekeys")
                return
            }

            XCTAssertTrue(selfClient.establishSessionWithClient(otherClient, usingPreKey: preKey.prekey))
            XCTAssertTrue(otherClient.hasSessionWithSelfClient)

            // when
            do {
                // When
                try otherClient.deleteSession()
            } catch {
                XCTFail("Unexpected error: \(error)")
            }

            // Then
            XCTAssertFalse(otherClient.hasSessionWithSelfClient)
        }
        XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
    }

    func testThatItDeletesASessionWhenDeletingAClient() {
        var flag = DeveloperFlag.proteusViaCoreCrypto
        flag.isOn = true

        self.syncMOC.performGroupedBlockAndWait {
            // Given
            let otherClient = UserClient.insertNewObject(in: self.syncMOC)
            otherClient.remoteIdentifier = UUID.create().transportString()
            let otherUser = ZMUser.insertNewObject(in: self.syncMOC)
            otherUser.remoteIdentifier = UUID.create()
            otherClient.user = otherUser
            let otherClientSessionID = otherClient.proteusSessionID

            // Mock
            let mockProteusService = MockProteusServiceInterface()
            self.syncMOC.proteusService = mockProteusService

            mockProteusService.deleteSessionId_MockMethod = { _ in
                // No op
            }

            // When
            otherClient.deleteClientAndEndSession()

            // Then
            XCTAssertEqual(mockProteusService.deleteSessionId_Invocations, [otherClientSessionID])
            XCTAssertTrue(otherClient.isZombieObject)
        }

        XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        flag.isOn = false
    }

    func testThatItDeletesASessionWhenDeletingAClient_Legacy() {
        self.syncMOC.performGroupedBlockAndWait {
            // given
            let selfClient = self.createSelfClient(onMOC: self.syncMOC)
            var preKeys: [(id: UInt16, prekey: String)] = []

            self.syncMOC.zm_cryptKeyStore.encryptionContext.perform({ (sessionsDirectory) in
                preKeys = try! sessionsDirectory.generatePrekeys(0 ..< 2)
            })

            let otherClient = UserClient.insertNewObject(in: self.syncMOC)
            otherClient.remoteIdentifier = UUID.create().transportString()
            let otherUser = ZMUser.insertNewObject(in: self.syncMOC)
            otherUser.remoteIdentifier = UUID.create()
            otherClient.user = otherUser

            guard let preKey = preKeys.first else {
                XCTFail("could not generate prekeys")
                return
            }

            XCTAssertTrue(selfClient.establishSessionWithClient(otherClient, usingPreKey: preKey.prekey))
            XCTAssertTrue(otherClient.hasSessionWithSelfClient)
            let clientId = otherClient.sessionIdentifier!

            // when
            otherClient.deleteClientAndEndSession()

            // then
            self.syncMOC.zm_cryptKeyStore.encryptionContext.perform {
                XCTAssertFalse($0.hasSession(for: clientId))
            }
            XCTAssertFalse(otherClient.hasSessionWithSelfClient)
            XCTAssertTrue(otherClient.isZombieObject)
        }
        XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
    }

    func testThatItUpdatesConversationSecurityLevelWhenDeletingClient() {

        self.syncMOC.performGroupedBlockAndWait {
            // given
            let selfClient = self.createSelfClient(onMOC: self.syncMOC)

            let otherClient1 = UserClient.insertNewObject(in: self.syncMOC)
            otherClient1.remoteIdentifier = UUID.create().transportString()

            let otherUser = ZMUser.insertNewObject(in: self.syncMOC)
            otherUser.remoteIdentifier = UUID.create()
            otherClient1.user = otherUser
            let connection = ZMConnection.insertNewSentConnection(to: otherUser)
            connection.status = .accepted

            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.conversationType = .group

            conversation.addParticipantsAndUpdateConversationState(
                users: Set([otherUser, ZMUser.selfUser(in: self.syncMOC)]),
                role: nil)

            selfClient.trustClient(otherClient1)

            conversation.securityLevel = ZMConversationSecurityLevel.notSecure
            XCTAssertEqual(conversation.allMessages.count, 1)

            let otherClient2 = UserClient.insertNewObject(in: self.syncMOC)
            otherClient2.remoteIdentifier = UUID.create().transportString()
            otherClient2.user = otherUser

            selfClient.ignoreClient(otherClient2)

            // when
            otherClient2.deleteClientAndEndSession()
            self.syncMOC.saveOrRollback()

            // then
            XCTAssertTrue(otherClient2.isZombieObject)
            XCTAssertEqual(conversation.securityLevel, ZMConversationSecurityLevel.secure)
            XCTAssertEqual(conversation.allMessages.count, 2)
            if let message = conversation.lastMessage as? ZMSystemMessage {
                XCTAssertEqual(message.systemMessageType, ZMSystemMessageType.conversationIsSecure)
                XCTAssertEqual(message.users, Set(arrayLiteral: otherUser))
            } else {
                XCTFail("Did not insert systemMessage")
            }
        }
        XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
    }

    func testThatWhenDeletingClientItTriggersUserFetchForPossibleMemberLeave() {
        self.syncMOC.performGroupedBlockAndWait {
            // given
            let otherClient = UserClient.insertNewObject(in: self.syncMOC)
            otherClient.remoteIdentifier = UUID.create().transportString()

            let otherUser = ZMUser.insertNewObject(in: self.syncMOC)
            otherUser.remoteIdentifier = UUID.create()
            otherClient.user = otherUser

            let team = self.createTeam(in: self.syncMOC)
            _ = self.createMembership(in: self.syncMOC, user: otherUser, team: team)

            otherUser.needsToBeUpdatedFromBackend = false

            XCTAssertTrue(otherUser.isTeamMember)
            XCTAssertFalse(otherUser.needsToBeUpdatedFromBackend)

            // when
            otherClient.deleteClientAndEndSession()

            // then
            XCTAssertTrue(otherClient.isZombieObject)
            XCTAssertTrue(otherUser.clients.isEmpty)
            XCTAssertTrue(otherUser.needsToBeUpdatedFromBackend)
        }

        XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
    }

    func testThatItRefetchesMissingFingerprintForUserWithSession() {
        // Given
        var flag = DeveloperFlag.proteusViaCoreCrypto
        flag.isOn = true

        let otherClientId = UUID.create()

        self.syncMOC.performGroupedBlockAndWait {
            let otherClient = UserClient.insertNewObject(in: self.syncMOC)
            otherClient.remoteIdentifier = otherClientId.transportString()
            let otherUser = ZMUser.insertNewObject(in: self.syncMOC)
            otherUser.remoteIdentifier = UUID.create()
            otherClient.user = otherUser

            // Mock
            let mockProteusService = MockProteusServiceInterface()
            self.syncMOC.proteusService = mockProteusService

            mockProteusService.remoteFingerprintForSession_MockMethod = { sessionID in
                return sessionID.rawValue + "remote_fingerprint"
            }

            XCTAssertNil(otherClient.fingerprint)
            otherClient.managedObjectContext?.saveOrRollback()
        }
        XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        self.syncMOC.performGroupedBlockAndWait {
            let fetchRequest = NSFetchRequest<UserClient>(entityName: UserClient.entityName())
            fetchRequest.predicate = NSPredicate(format: "%K == %@", "remoteIdentifier", otherClientId.transportString())
            fetchRequest.fetchLimit = 1
            // When
            do {
                let fetchedClient = try self.syncMOC.fetch(fetchRequest).first

                // Then
                XCTAssertNotNil(fetchedClient)
                XCTAssertNotNil(fetchedClient!.fingerprint)
            } catch let error {
                XCTFail(error.localizedDescription)
            }
        }

        flag.isOn = false
    }

    func testThatItRefetchesMissingFingerprintForUserWithSession_Legacy() {
        // Given
        let otherClientId = UUID.create()

        self.syncMOC.performGroupedBlockAndWait {
            var preKeys: [(id: UInt16, prekey: String)] = []

            self.syncMOC.zm_cryptKeyStore.encryptionContext.perform({ (sessionsDirectory) in
                preKeys = try! sessionsDirectory.generatePrekeys(0 ..< 2)
            })

            let otherClient = UserClient.insertNewObject(in: self.syncMOC)
            otherClient.remoteIdentifier = otherClientId.transportString()
            let otherUser = ZMUser.insertNewObject(in: self.syncMOC)
            otherUser.remoteIdentifier = UUID.create()
            otherClient.user = otherUser

            guard let preKey = preKeys.first else {
                XCTFail("could not generate prekeys")
                return
            }

            self.syncMOC.zm_cryptKeyStore.encryptionContext.perform({ (sessionsDirectory) in
                try! sessionsDirectory.createClientSession(otherClient.sessionIdentifier!, base64PreKeyString: preKey.prekey)
            })

            XCTAssertNil(otherClient.fingerprint)
            otherClient.managedObjectContext?.saveOrRollback()
        }
        XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        self.syncMOC.performGroupedBlockAndWait {
            let fetchRequest = NSFetchRequest<UserClient>(entityName: UserClient.entityName())
            fetchRequest.predicate = NSPredicate(format: "%K == %@", "remoteIdentifier", otherClientId.transportString())
            fetchRequest.fetchLimit = 1
            // When
            do {
                let fetchedClient = try self.syncMOC.fetch(fetchRequest).first

                // Then
                XCTAssertNotNil(fetchedClient)
                XCTAssertNotNil(fetchedClient!.fingerprint)
            } catch let error {
                XCTFail(error.localizedDescription)
            }
        }
    }

    func testThatItSetsNeedsToNotifyOtherUserAboutSessionReset_WhenResettingSession() {
        var otherClient: UserClient!

        // given
        self.syncMOC.performGroupedBlockAndWait {
            _ = self.createSelfClient(onMOC: self.syncMOC)

            otherClient = UserClient.insertNewObject(in: self.syncMOC)
            otherClient.remoteIdentifier = UUID.create().transportString()

            let otherUser = ZMUser.insertNewObject(in: self.syncMOC)
            otherUser.remoteIdentifier = UUID.create()
            otherClient.user = otherUser

            let connection = ZMConnection.insertNewSentConnection(to: otherUser)
            connection.status = .accepted
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // when
        self.syncMOC.performGroupedBlockAndWait {
            otherClient.resetSession()
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // then
        self.syncMOC.performGroupedBlockAndWait {
            XCTAssertTrue(otherClient.needsToNotifyOtherUserAboutSessionReset)
        }
    }

    func testThatItAsksForMoreWhenRunningOutOfPrekeys() {

        self.syncMOC.performGroupedBlockAndWait {
            // given
            let selfClient = self.createSelfClient(onMOC: self.syncMOC)
            selfClient.numberOfKeysRemaining = 1

            // when
            selfClient.decrementNumberOfRemainingKeys()

            // then
            XCTAssertTrue(selfClient.modifiedKeys!.contains(ZMUserClientNumberOfKeysRemainingKey))
        }
    }

    func testThatItDoesntAskForMoreWhenItStillHasPrekeys() {

        self.syncMOC.performGroupedBlockAndWait {
            // given
            let selfClient = self.createSelfClient(onMOC: self.syncMOC)
            selfClient.numberOfKeysRemaining = 2

            // when
            selfClient.decrementNumberOfRemainingKeys()

            // then
            XCTAssertNil(selfClient.modifiedKeys)
        }
    }
}

extension UserClientTests {
    func testThatItStoresFailedToEstablishSessionInformation() {
        self.syncMOC.performGroupedBlockAndWait {
            // given
            let client = UserClient.insertNewObject(in: self.syncMOC)

            // when & then
            XCTAssertFalse(client.failedToEstablishSession)

            // when
            client.failedToEstablishSession = true

            // then
            XCTAssertTrue(client.failedToEstablishSession)

            // when
            client.failedToEstablishSession = false

            // then
            XCTAssertFalse(client.failedToEstablishSession)
        }
    }
}

extension UserClientTests {

    func testThatSelfClientIsTrusted() {
        // given & when
        let selfClient = self.createSelfClient()

        // then
        XCTAssertTrue(selfClient.verified)
    }

    func testThatSelfClientIsStillVerifiedAfterIgnoring() {
        // given
        let selfClient = self.createSelfClient()

        // when
        selfClient.ignoreClient(selfClient)

        // then
        XCTAssertTrue(selfClient.verified)
    }

    func testThatUnknownClientIsNotVerified() {
        // given & when
        self.createSelfClient()

        let otherClient = UserClient.insertNewObject(in: self.uiMOC)
        otherClient.remoteIdentifier = NSString.createAlphanumerical()

        // then
        XCTAssertFalse(otherClient.verified)
    }

    func testThatItIsVerifiedWhenTrusted() {
        // given
        let selfClient = self.createSelfClient()

        let otherClient = UserClient.insertNewObject(in: self.uiMOC)
        otherClient.remoteIdentifier = NSString.createAlphanumerical()

        // when
        selfClient.trustClient(otherClient)

        // then
        XCTAssertTrue(otherClient.verified)
    }

    func testThatItIsNotVerifiedWhenIgnored() {
        // given
        let selfClient = createSelfClient()

        let otherClient = UserClient.insertNewObject(in: self.uiMOC)
        otherClient.remoteIdentifier = NSString.createAlphanumerical()

        // when
        selfClient.ignoreClient(otherClient)

        // then
        XCTAssertFalse(otherClient.verified)
    }
}

// MARK: SignalingStore

extension UserClientTests {

    func testThatItDeletesExistingSignalingKeys() {

        // given
        let selfClient = createSelfClient()
        selfClient.apsVerificationKey =  Data()
        selfClient.apsDecryptionKey = Data()

        XCTAssertNotNil(selfClient.apsVerificationKey)
        XCTAssertNotNil(selfClient.apsDecryptionKey)

        // when
        UserClient.resetSignalingKeysInContext(self.uiMOC)

        // then
        XCTAssertNil(selfClient.apsVerificationKey)
        XCTAssertNil(selfClient.apsDecryptionKey)
    }

    func testThatItSetsKeysNeedingToBeSynced() {

        // given
        let selfClient = createSelfClient()

        // when
        UserClient.resetSignalingKeysInContext(self.uiMOC)

        // then
        XCTAssertTrue(selfClient.needsToUploadSignalingKeys)
        XCTAssertTrue(selfClient.keysThatHaveLocalModifications.contains(ZMUserClientNeedsToUpdateSignalingKeysKey))
    }

}

// MARK: Capabilities

extension UserClientTests {

    func testThatItSetsKeysNeedingToBeSynced_Capabilities() {
        // given
        let selfClient = createSelfClient()

        // when
        UserClient.triggerSelfClientCapabilityUpdate(self.uiMOC)

        // then
        XCTAssertTrue(selfClient.needsToUpdateCapabilities)
        XCTAssertTrue(selfClient.keysThatHaveLocalModifications.contains(ZMUserClientNeedsToUpdateCapabilitiesKey))
    }

}

// MARK: fetchFingerprintOrPrekeys

extension UserClientTests {

    func testThatItSetsTheUserWhenInsertingANewSelfUserClient() {
        // given
        _ = createSelfClient()
        let newClientPayload: [String: AnyObject] = ["id": UUID().transportString() as AnyObject,
                                                       "type": "permanent" as AnyObject,
                                                       "time": Date().transportString() as AnyObject]
        // when
        var newClient: UserClient!
        self.performPretendingUiMocIsSyncMoc {
            newClient = UserClient.createOrUpdateSelfUserClient(newClientPayload, context: self.uiMOC)
            XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        }

        // then
        XCTAssertNotNil(newClient)
        XCTAssertNotNil(newClient.user)
        XCTAssertEqual(newClient.user, ZMUser.selfUser(in: uiMOC))
        XCTAssertNotNil(newClient.sessionIdentifier)
    }

    func testThatItSetsTheUserWhenInsertingANewSelfUserClient_NoExistingSelfClient() {
        // given
        let newClientPayload: [String: AnyObject] = ["id": UUID().transportString() as AnyObject,
                                                       "type": "permanent" as AnyObject,
                                                       "time": Date().transportString() as AnyObject]
        // when
        var newClient: UserClient!
        self.performPretendingUiMocIsSyncMoc {
            newClient = UserClient.createOrUpdateSelfUserClient(newClientPayload, context: self.uiMOC)
            XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        }

        // then
        XCTAssertNotNil(newClient)
        XCTAssertNotNil(newClient.user)
        XCTAssertEqual(newClient.user, ZMUser.selfUser(in: uiMOC))
        XCTAssertNil(newClient.sessionIdentifier)
    }

    func testThatItSetsNeedsSessionMigration_WhenInsertingANewSelfUserClientAndDomainIsNil() {
        // given
        _ = createSelfClient()
        let newClientPayload: [String: AnyObject] = ["id": UUID().transportString() as AnyObject,
                                                       "type": "permanent" as AnyObject,
                                                       "time": Date().transportString() as AnyObject]
        // when
        var newClient: UserClient!
        self.performPretendingUiMocIsSyncMoc {
            newClient = UserClient.createOrUpdateSelfUserClient(newClientPayload, context: self.uiMOC)
            XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        }

        // then
        XCTAssertTrue(newClient.needsSessionMigration)
    }

    func testThatItSetsNeedsSessionMigration_WhenInsertingANewSelfUserClientAndDomainIsSet() {
        // given
        _ = createSelfClient()
        ZMUser.selfUser(in: uiMOC).domain = "example.com"

        let newClientPayload: [String: AnyObject] = ["id": UUID().transportString() as AnyObject,
                                                       "type": "permanent" as AnyObject,
                                                       "time": Date().transportString() as AnyObject]
        // when
        var newClient: UserClient!
        self.performPretendingUiMocIsSyncMoc {
            newClient = UserClient.createOrUpdateSelfUserClient(newClientPayload, context: self.uiMOC)
            XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        }

        // then
        XCTAssertFalse(newClient.needsSessionMigration)
    }

    func testThatItDoNothingWhenHasAFingerprint() {
        // GIVEN
        let fingerprint = Data(base64Encoded: "cmVhZGluZyB0ZXN0cyBpcyBjb29s")

        let client = UserClient.insertNewObject(in: self.uiMOC)
        client.fingerprint = fingerprint

        self.uiMOC.saveOrRollback()
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.05))

        // WHEN
        client.fetchFingerprintOrPrekeys()
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.05))

        // THEN
        XCTAssertTrue(client.keysThatHaveLocalModifications.isEmpty)
        XCTAssertEqual(client.fingerprint, fingerprint)
    }

    func testThatItLoadsFingerprintForSelfClient() {

        // GIVEN
        var selfClient: UserClient!
        var newFingerprint: Data?

        self.syncMOC.performGroupedBlockAndWait {

            selfClient = self.createSelfClient(onMOC: self.syncMOC)
            selfClient.fingerprint = .none

            // TODO: [John] use flag here

            self.syncMOC.zm_cryptKeyStore.encryptionContext.perform { (sessionsDirectory) in
                newFingerprint = sessionsDirectory.localFingerprint
            }

            self.syncMOC.saveOrRollback()
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.05))

        // WHEN
        self.syncMOC.performGroupedBlockAndWait {
            selfClient.fetchFingerprintOrPrekeys()
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.05))

        // THEN
        self.syncMOC.performGroupedBlockAndWait {
            XCTAssertTrue(selfClient.keysThatHaveLocalModifications.isEmpty)
            XCTAssertEqual(selfClient.fingerprint!, newFingerprint)
        }
    }

    func testThatItLoadsFingerprintForExistingSession() {
        var flag = DeveloperFlag.proteusViaCoreCrypto
        flag.isOn = true

        var client: UserClient!

        self.syncMOC.performGroupedBlockAndWait {
            // Given
            self.createSelfClient(onMOC: self.syncMOC)
            client = UserClient.insertNewObject(in: self.syncMOC)
            let otherUser = ZMUser.insertNewObject(in: self.syncMOC)
            otherUser.remoteIdentifier = UUID.create()
            client.user = otherUser
            client.remoteIdentifier = "badf00d"

            // Mock
            let mockProteusService = MockProteusServiceInterface()
            self.syncMOC.proteusService = mockProteusService

            mockProteusService.sessionExistsId_MockMethod = { sessionID in
                return sessionID == client.proteusSessionID
            }

            mockProteusService.remoteFingerprintForSession_MockMethod = { sessionID in
                return sessionID.rawValue + "remote_fingerprint"
            }

            // When
            client.fetchFingerprintOrPrekeys()
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.05))

        // Then
        self.syncMOC.performGroupedBlockAndWait {
            XCTAssertTrue(client.keysThatHaveLocalModifications.isEmpty)
            XCTAssertNotEqual(client.fingerprint!.count, 0)
        }

        flag.isOn = false
    }

    func testThatItLoadsFingerprintForExistingSession_Legacy() {
        var client: UserClient!

        self.syncMOC.performGroupedBlockAndWait {
            // GIVEN
            var preKeys: [(id: UInt16, prekey: String)] = []

            self.syncMOC.zm_cryptKeyStore.encryptionContext.perform({ (sessionsDirectory) in
                preKeys = try! sessionsDirectory.generatePrekeys(0 ..< 2)
            })

            guard let preKey = preKeys.first else {
                XCTFail("could not generate prekeys")
                return
            }

            self.createSelfClient()
            client = UserClient.insertNewObject(in: self.syncMOC)
            let otherUser = ZMUser.insertNewObject(in: self.syncMOC)
            otherUser.remoteIdentifier = UUID.create()
            client.user = otherUser
            client.remoteIdentifier = "badf00d"

            self.syncMOC.zm_cryptKeyStore.encryptionContext.perform { (sessionsDirectory) in
                try! sessionsDirectory.createClientSession(client.sessionIdentifier!, base64PreKeyString: preKey.prekey)
            }

            // WHEN
            client.fetchFingerprintOrPrekeys()
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.05))

        // THEN
        self.syncMOC.performGroupedBlockAndWait {
            XCTAssertTrue(client.keysThatHaveLocalModifications.isEmpty)
            XCTAssertNotEqual(client.fingerprint!.count, 0)
        }
    }

    func testThatItMarksMissingWhenNoSession() {
        var client: UserClient!
        var selfClient: UserClient!

        self.syncMOC.performGroupedBlockAndWait {
            // GIVEN
            selfClient = self.createSelfClient(onMOC: self.syncMOC)
            client = UserClient.insertNewObject(in: self.syncMOC)
            let otherUser = ZMUser.insertNewObject(in: self.syncMOC)
            otherUser.remoteIdentifier = UUID.create()
            client.user = otherUser
            client.remoteIdentifier = "badf00d"

            self.syncMOC.saveOrRollback()

            // WHEN
            client.fetchFingerprintOrPrekeys()
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.05))

        // THEN
        self.syncMOC.performGroupedBlockAndWait {
            XCTAssertTrue(selfClient.hasLocalModifications(forKey: ZMUserClientMissingKey))
            XCTAssertEqual(client.fingerprint, .none)
        }
    }

    func testThatItCreatesUserClientIfNeeded() {
        self.syncMOC.performGroupedBlockAndWait {
            // GIVEN
            let otherUser = ZMUser.insertNewObject(in: self.syncMOC)
            otherUser.remoteIdentifier = UUID.create()
            // WHEN
            let client = UserClient.fetchUserClient(withRemoteId: "badf00d", forUser: otherUser, createIfNeeded: true)

            // THEN
            XCTAssertNotNil(client)
            XCTAssertEqual(client?.remoteIdentifier, "badf00d")
            XCTAssertEqual(client?.user, otherUser)
        }
    }

    func testThatItSetsNeedsToMigrateSession_WhenCreatingUserClientAndDomainIsNil() {
        self.syncMOC.performGroupedBlockAndWait {
            // GIVEN
            let otherUser = ZMUser.insertNewObject(in: self.syncMOC)
            otherUser.remoteIdentifier = UUID.create()
            // WHEN
            let client = UserClient.fetchUserClient(withRemoteId: "badf00d", forUser: otherUser, createIfNeeded: true)

            // THEN
            XCTAssertEqual(client?.needsSessionMigration, true)
        }
    }

    func testThatItSetsNeedsToMigrateSession_WhenCreatingUserClientAndDomainIsSet() {
        self.syncMOC.performGroupedBlockAndWait {
            // GIVEN
            let otherUser = ZMUser.insertNewObject(in: self.syncMOC)
            otherUser.remoteIdentifier = UUID.create()
            otherUser.domain = "example.com"
            // WHEN
            let client = UserClient.fetchUserClient(withRemoteId: "badf00d", forUser: otherUser, createIfNeeded: true)

            // THEN
            XCTAssertEqual(client?.needsSessionMigration, false)
        }
    }

    func testThatItFetchesUserClientWithoutSave() {
        self.syncMOC.performGroupedBlockAndWait {
            // GIVEN
            let otherUser = ZMUser.insertNewObject(in: self.syncMOC)
            otherUser.remoteIdentifier = UUID.create()
            // WHEN
            let client1 = UserClient.fetchUserClient(withRemoteId: "badf00d", forUser: otherUser, createIfNeeded: true)
            let client2 = UserClient.fetchUserClient(withRemoteId: "badf00d", forUser: otherUser, createIfNeeded: true)

            // THEN
            XCTAssertNotNil(client1)
            XCTAssertNotNil(client2)

            XCTAssertEqual(client1, client2)
        }
    }

    func testThatItFetchesUserClient_OtherMOC() {
        var clientSync: UserClient?
        let userUI = ZMUser.insertNewObject(in: self.uiMOC)
        userUI.remoteIdentifier = UUID.create()

        self.uiMOC.saveOrRollback()

        self.syncMOC.performGroupedBlockAndWait {
            // GIVEN
            let userSync = try! self.syncMOC.existingObject(with: userUI.objectID) as! ZMUser
            // WHEN
            clientSync = UserClient.fetchUserClient(withRemoteId: "badf00d", forUser: userSync, createIfNeeded: true)
            clientSync?.label = "test"
            // THEN
            XCTAssertNotNil(clientSync)
            self.syncMOC.saveOrRollback()
        }

        // WHEN
        let clientUI: UserClient? = UserClient.fetchUserClient(withRemoteId: "badf00d", forUser: userUI, createIfNeeded: false)

        // THEN
        XCTAssertNotNil(clientUI)
        XCTAssertEqual(clientUI?.remoteIdentifier, "badf00d")
        XCTAssertEqual(clientUI?.label, "test")
    }

    func testThatItFetchesUserClientWithSave() {
        self.syncMOC.performGroupedBlockAndWait {
            // GIVEN
            let otherUser = ZMUser.insertNewObject(in: self.syncMOC)
            otherUser.remoteIdentifier = UUID.create()
            // WHEN
            let client1 = UserClient.fetchUserClient(withRemoteId: "badf00d", forUser: otherUser, createIfNeeded: true)

            // AND THEN
            self.syncMOC.saveOrRollback()

            // WHEN
            let client2 = UserClient.fetchUserClient(withRemoteId: "badf00d", forUser: otherUser, createIfNeeded: true)

            // THEN
            XCTAssertNotNil(client1)
            XCTAssertNotNil(client2)

            XCTAssertEqual(client1, client2)
        }
    }
}

// MARK: - Update from payload

extension UserClientTests {

    func testThatItUpdatesDeviceClassFromPayload() {
        // given
        let allCases: [DeviceClass] = [.desktop, .phone, .tablet, .legalHold]
        let client = UserClient.insertNewObject(in: uiMOC)
        client.user = createUser(in: uiMOC)

        for deviceClass in allCases {
            // when
            client.update(with: ["class": deviceClass.rawValue])

            // then
            XCTAssertEqual(client.deviceClass, deviceClass)
        }
    }

    func testThatItSelfClientsAreNotUpdatedFromPayload() {
        // given
        let deviceClass = DeviceClass.desktop
        let selfClient = createSelfClient()

        // when
        selfClient.update(with: ["class": deviceClass.rawValue])

        // then
        XCTAssertNotEqual(selfClient.deviceClass, deviceClass)
    }

    func testThatItResetsNeedsToBeUpdatedFromBackend() {
        // given
        let client = UserClient.insertNewObject(in: uiMOC)
        client.user = createUser(in: uiMOC)
        client.needsToBeUpdatedFromBackend = true

        // when
        client.update(with: [:])

        // then
        XCTAssertFalse(client.needsToBeUpdatedFromBackend)
    }

}

// MARK: - Session Identifier

extension UserClientTests {

    func testThatItReturnsCorrectSessionIdentifier_WhenSessionNeedsMigration() {
        // given
        let user = createUser(in: uiMOC)

        let client = UserClient.insertNewObject(in: uiMOC)
        let clientID = UUID().uuidString
        client.remoteIdentifier = clientID
        client.user = user
        client.needsSessionMigration = true

        let userID = client.user!.remoteIdentifier.uuidString
        let expectedSessionIdentifier = EncryptionSessionIdentifier(userId: userID,
                                                                    clientId: clientID)

        // when
        let sessionIdentifier = client.sessionIdentifier

        // then
        XCTAssertEqual(sessionIdentifier, expectedSessionIdentifier)
    }

    func testThatItReturnsCorrectSessionIdentifier_WhenSessionDoesNotNeedMigration() {
        // given
        let domain = UUID().uuidString
        let user = createUser(in: uiMOC)
        user.domain = domain

        let client = UserClient.insertNewObject(in: uiMOC)
        let clientID = UUID().uuidString
        client.remoteIdentifier = clientID
        client.user = user
        client.needsSessionMigration = false

        let userID = client.user!.remoteIdentifier.uuidString
        let expectedSessionIdentifier = EncryptionSessionIdentifier(domain: domain,
                                                                    userId: userID,
                                                                    clientId: clientID)

        // when
        let sessionIdentifier = client.sessionIdentifier

        // then
        XCTAssertEqual(sessionIdentifier, expectedSessionIdentifier)
    }

    func testThatItMigratesSessionIdentifierFromV2ToV3_WhenUserDomainIsAvailable() {
        syncMOC.performGroupedBlockAndWait { [self] in
            // given
            let selfClient = createSelfClient(onMOC: syncMOC)

            let otherClient = UserClient.insertNewObject(in: syncMOC)
            otherClient.remoteIdentifier = UUID.create().transportString()
            let otherUser = ZMUser.insertNewObject(in: syncMOC)
            let otherUserID = UUID().create()
            otherUser.remoteIdentifier = otherUserID
            otherClient.user = otherUser
            otherClient.needsSessionMigration = true

            var preKeys: [(id: UInt16, prekey: String)] = []
            // TODO: [John] use flag here
            self.syncMOC.zm_cryptKeyStore.encryptionContext.perform { sessionsDirectory in
                preKeys = try! sessionsDirectory.generatePrekeys(0 ..< 2)
            }

            guard let preKey = preKeys.first else {
                XCTFail("could not generate prekeys")
                return
            }

            let userID = otherUserID.uuidString
            let clientID = otherClient.remoteIdentifier!
            let otherUserDomain = UUID().uuidString

            let v2SessionIdentifier = EncryptionSessionIdentifier(userId: userID,
                                                                  clientId: clientID)
            let v3SessionIdentifier = EncryptionSessionIdentifier(domain: otherUserDomain,
                                                                  userId: userID,
                                                                  clientId: clientID)

            XCTAssertTrue(selfClient.establishSessionWithClient(otherClient, usingPreKey: preKey.prekey))
            XCTAssertTrue(otherClient.hasSessionWithSelfClient)

            self.syncMOC.zm_cryptKeyStore.encryptionContext.perform { sessionsDirectory in
                XCTAssertTrue(sessionsDirectory.hasSession(for: v2SessionIdentifier))
                XCTAssertFalse(sessionsDirectory.hasSession(for: v3SessionIdentifier))
            }

            otherUser.domain = otherUserDomain

            self.syncMOC.zm_cryptKeyStore.encryptionContext.perform { sessionsDirectory in
                // when
                otherClient.migrateSessionIdentifierFromV2IfNeeded(sessionDirectory: sessionsDirectory)

                // then
                XCTAssertFalse(sessionsDirectory.hasSession(for: v2SessionIdentifier))
                XCTAssertTrue(sessionsDirectory.hasSession(for: v3SessionIdentifier))
            }
        }

    }

    func testThatItMigratesSessionIdentifierFromV2ToV3_FallsBackToLocalDomainIfUserHasNoDomain() {
        syncMOC.performGroupedBlockAndWait { [self] in
            // given
            let selfClient = createSelfClient(onMOC: syncMOC)

            let otherClient = UserClient.insertNewObject(in: syncMOC)
            otherClient.remoteIdentifier = UUID.create().transportString()
            let otherUser = ZMUser.insertNewObject(in: syncMOC)
            let otherUserID = UUID().create()
            otherUser.remoteIdentifier = otherUserID
            otherClient.user = otherUser
            otherClient.needsSessionMigration = true

            var preKeys: [(id: UInt16, prekey: String)] = []
            // TODO: [John] use flag here
            self.syncMOC.zm_cryptKeyStore.encryptionContext.perform { sessionsDirectory in
                preKeys = try! sessionsDirectory.generatePrekeys(0 ..< 2)
            }

            guard let preKey = preKeys.first else {
                XCTFail("could not generate prekeys")
                return
            }

            let userID = otherUserID.uuidString
            let clientID = otherClient.remoteIdentifier!
            let localDomain = "localdomain.com"
            BackendInfo.domain = localDomain

            let v2SessionIdentifier = EncryptionSessionIdentifier(userId: userID,
                                                                  clientId: clientID)
            let v3SessionIdentifier = EncryptionSessionIdentifier(domain: localDomain,
                                                                  userId: userID,
                                                                  clientId: clientID)

            XCTAssertTrue(selfClient.establishSessionWithClient(otherClient, usingPreKey: preKey.prekey))
            XCTAssertTrue(otherClient.hasSessionWithSelfClient)

            self.syncMOC.zm_cryptKeyStore.encryptionContext.perform { sessionsDirectory in
                XCTAssertTrue(sessionsDirectory.hasSession(for: v2SessionIdentifier))
                XCTAssertFalse(sessionsDirectory.hasSession(for: v3SessionIdentifier))
            }

            otherUser.domain = nil

            self.syncMOC.zm_cryptKeyStore.encryptionContext.perform { sessionsDirectory in
                // when
                otherClient.migrateSessionIdentifierFromV2IfNeeded(sessionDirectory: sessionsDirectory)

                // then
                XCTAssertFalse(sessionsDirectory.hasSession(for: v2SessionIdentifier))
                XCTAssertTrue(sessionsDirectory.hasSession(for: v3SessionIdentifier))
            }
        }

    }

}

// MARK: - MLS Public Keys

extension UserClientTests {

    func test_SettingNewMLSPublicKeys_MarksClientAsNeedingToUploadMLSPublicKeys() {
        // Given
        let client = UserClient.insertNewObject(in: self.uiMOC)
        XCTAssertEqual(client.modifiedKeys, nil)

        // When
        client.mlsPublicKeys = UserClient.MLSPublicKeys(ed25519: "foo")
        uiMOC.saveOrRollback()

        // Then
        XCTAssertEqual(client.modifiedKeys, Set([UserClient.needsToUploadMLSPublicKeysKey]))
    }

    func test_SettingSameMLSPublicKeys_DoesNot_MarkClientAsNeedingToUploadMLSPublicKeys() {
        // Given
        let client = UserClient.insertNewObject(in: self.uiMOC)
        client.mlsPublicKeys = UserClient.MLSPublicKeys(ed25519: "foo")
        uiMOC.saveOrRollback()

        client.resetLocallyModifiedKeys(Set([UserClient.needsToUploadMLSPublicKeysKey]))
        XCTAssertNil(client.modifiedKeys)

        // When
        client.mlsPublicKeys = UserClient.MLSPublicKeys(ed25519: "foo")
        uiMOC.saveOrRollback()

        // Then
        XCTAssertNil(client.modifiedKeys)
    }

}

// MARK: - Proteus

extension UserClientTests {

    func test_GivenDeveloperFlagProteusViaCoreCryptoEnabled_ItUsesCoreKrypto() {
        // GIVEN
        let context = self.syncMOC
        var mockMethodCalled = false
        let prekey = "test".utf8Data!.base64String()
        var resultOfMethod = false

        let mockProteusService = MockProteusServiceInterface()
        mockProteusService.establishSessionIdFromPrekey_MockMethod = {_, _ in
            mockMethodCalled = true
        }
        mockProteusService.remoteFingerprintForSession_MockMethod = {_ in
            return "test"
        }

        let mock = MockProteusProvider(mockProteusService: mockProteusService, mockKeyStore: self.spyForTests())
        mock.useProteusService = true

        var sut: UserClient!
        var clientB: UserClient!

        context.performGroupedBlock {
            sut = self.createSelfClient(onMOC: context)
            let userB = self.createUser(in: context)
            clientB = self.createClient(for: userB, createSessionWithSelfUser: false, onMOC: context)

            // WHEN
           resultOfMethod = sut.establishSessionWithClient(clientB, usingPreKey: prekey, proteusProviding: mock)

            // THEN
            XCTAssertTrue(mockMethodCalled)
            XCTAssertTrue(resultOfMethod)
        }
    }

    func test_GivenDeveloperFlagProteusViaCoreCryptoDisabled_ItUsesCryptoBox() {
        // GIVEN
        let context = self.syncMOC
        var resultOfMethod = false
        let prekey = "test".utf8Data!.base64String()
        let spy = self.spyForTests()
        var mockProteusServiceCalled = false

        let mockProteusService = MockProteusServiceInterface()
        mockProteusService.establishSessionIdFromPrekey_MockMethod = {_, _ in
            mockProteusServiceCalled = true
        }
        mockProteusService.remoteFingerprintForSession_MockMethod = {_ in
            return "test"
        }

        let mock = MockProteusProvider(mockProteusService: MockProteusServiceInterface(), mockKeyStore: spy)
        mock.useProteusService = false

        var sut: UserClient!
        var clientB: UserClient!

        context.performGroupedBlock {
            sut = self.createSelfClient(onMOC: context)
            let userB = self.createUser(in: context)
            clientB = self.createClient(for: userB, createSessionWithSelfUser: false, onMOC: context)
            // we need real prekeys here
            var preKeys: [(id: UInt16, prekey: String)] = []
            context.zm_cryptKeyStore.encryptionContext.perform { sessionsDirectory in
                preKeys = try! sessionsDirectory.generatePrekeys(0 ..< 2)
            }

            // WHEN
            resultOfMethod = sut.establishSessionWithClient(clientB, usingPreKey: preKeys.first!.prekey, proteusProviding: mock)

            // THEN
            XCTAssertEqual(spy.accessEncryptionContextCount, 2)
            XCTAssertTrue(resultOfMethod)
            XCTAssertFalse(mockProteusServiceCalled)
        }
    }

    func test_itLoadsLocalFingerprintForSelfClient_ProteusViaCoreCryptoFlagEnabled() {

        // GIVEN
        var proteusViaCoreCrypto = DeveloperFlag.proteusViaCoreCrypto
        proteusViaCoreCrypto.isOn = true
        var selfClient: UserClient!
        let localFingerprint: String = "test"

        self.syncMOC.performGroupedBlockAndWait {
            let mockProteusService = MockProteusServiceInterface()
            mockProteusService.localFingerprint_MockMethod = {
                return localFingerprint
            }
            self.syncMOC.proteusService = mockProteusService

            selfClient = self.createSelfClient(onMOC: self.syncMOC)
            selfClient.fingerprint = .none

            self.syncMOC.saveOrRollback()
        }
        XCTAssertTrue(self.waitForAllGroupsToBeEmpty(withTimeout: 0.05))

        // WHEN
        self.syncMOC.performGroupedBlockAndWait {
            selfClient.fetchFingerprintOrPrekeys()
        }

        // THEN
        self.syncMOC.performGroupedBlockAndWait {
            XCTAssertEqual(selfClient.fingerprint!, localFingerprint.utf8Data)
        }

        // Cleanup
        proteusViaCoreCrypto.isOn = false
    }

    func test_itDoesntLoadRemoteFingerprint_IfProteusProviderCantPerform_ProteusViaCoreCryptoFlagEnabled() {
        // GIVEN
        var proteusViaCoreCrypto = DeveloperFlag.proteusViaCoreCrypto
        proteusViaCoreCrypto.isOn = true

        let mockProteusService = MockProteusServiceInterface()
        mockProteusService.remoteFingerprintForSession_MockMethod = { _ in return "" }

        let mockProvider = MockProteusProvider(
            mockProteusService: mockProteusService,
            mockKeyStore: spyForTests(),
            useProteusService: true
        )
        mockProvider.mockCanPerform = false

        syncMOC.performAndWait {
            let user = createUser(in: syncMOC)
            let sut = createClient(for: user, createSessionWithSelfUser: false, onMOC: syncMOC)
            sut.fingerprint = .none

            // WHEN
            _ = sut.remoteFingerprint(mockProvider)

            // THEN
            XCTAssertTrue(mockProteusService.remoteFingerprintForSession_Invocations.isEmpty)
        }

        // Cleanup
        proteusViaCoreCrypto.isOn = false
    }

    func test_itLoadsRemoteFingerprintForOtherClient_ProteusViaCoreCryptoFlagEnabled() {
        // GIVEN
        var proteusViaCoreCrypto = DeveloperFlag.proteusViaCoreCrypto
        proteusViaCoreCrypto.isOn = true
        let context = self.syncMOC
        let prekey = "test".utf8Data!.base64String()
        let remoteFingerprint: String = "fingerprint"

        let mockProteusService = MockProteusServiceInterface()
        mockProteusService.establishSessionIdFromPrekey_MockMethod = {_, _ in }

        mockProteusService.remoteFingerprintForSession_MockMethod = {_ in
            return remoteFingerprint
        }

        let mock = MockProteusProvider(mockProteusService: mockProteusService, mockKeyStore: self.spyForTests())
        mock.useProteusService = true

        var sut: UserClient!
        var clientB: UserClient!

        context.performGroupedBlock {
            sut = self.createSelfClient(onMOC: context)
            let userB = self.createUser(in: context)
            clientB = self.createClient(for: userB, createSessionWithSelfUser: false, onMOC: context)
            clientB.fingerprint = .none

            // WHEN
            let _ = sut.establishSessionWithClient(clientB, usingPreKey: prekey, proteusProviding: mock)

            // THEN
            XCTAssertEqual(clientB.fingerprint!, remoteFingerprint.utf8Data)
        }

        // Cleanup
        proteusViaCoreCrypto.isOn = false
    }

    private func spyForTests() -> SpyUserClientKeyStore {
        let url = self.createTempFolder()
        return SpyUserClientKeyStore(accountDirectory: url, applicationContainer: url)
    }
}
