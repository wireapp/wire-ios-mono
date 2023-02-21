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

import Foundation

/// A type that provides support for messaging via the Proteus
/// end-to-end-encryption protocol.

public protocol ProteusServiceInterface {

    func establishSession(id: ProteusSessionID, fromPrekey: String) throws
    func deleteSession(id: ProteusSessionID) throws
    func sessionExists(id: ProteusSessionID) -> Bool
    func encrypt(data: Data, forSession id: ProteusSessionID) throws -> Data
    func encryptBatched(data: Data, forSessions sessions: [ProteusSessionID]) throws -> [String: Data]

    func decrypt(
        data: Data,
        forSession id: ProteusSessionID
    ) throws -> (didCreateSession: Bool, decryptedData: Data)

    func generatePrekey(id: UInt16) throws -> String
    func lastPrekey() throws -> String
    var lastPrekeyID: UInt16 { get }
    func generatePrekeys(start: UInt16, count: UInt16) throws -> [IdPrekeyTuple]
    func fingerprint() throws -> String
    func localFingerprint(forSession id: ProteusSessionID) throws -> String
    func remoteFingerprint(forSession id: ProteusSessionID) throws -> String
    func fingerprint(fromPrekey prekey: String) throws -> String

}

public typealias IdPrekeyTuple = (id: UInt16, prekey: String)