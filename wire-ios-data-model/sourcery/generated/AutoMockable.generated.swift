// Generated using Sourcery 2.0.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// swiftlint:disable line_length
// swiftlint:disable variable_name

import Foundation
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif


@testable import WireDataModel





















public class MockProteusServiceInterface: ProteusServiceInterface {

    // MARK: - Life cycle

    public init() {}

    // MARK: - lastPrekeyID

    public var lastPrekeyID: UInt16 {
        get { return underlyingLastPrekeyID }
        set(value) { underlyingLastPrekeyID = value }
    }

    public var underlyingLastPrekeyID: UInt16!


    // MARK: - establishSession

    public var establishSessionIdFromPrekey_Invocations: [(id: String, fromPrekey: String)] = []
    public var establishSessionIdFromPrekey_MockError: Error?
    public var establishSessionIdFromPrekey_MockMethod: ((String, String) throws -> Void)?

    public func establishSession(id: String, fromPrekey: String) throws {
        establishSessionIdFromPrekey_Invocations.append((id: id, fromPrekey: fromPrekey))

        if let error = establishSessionIdFromPrekey_MockError {
            throw error
        }

        guard let mock = establishSessionIdFromPrekey_MockMethod else {
            fatalError("no mock for `establishSessionIdFromPrekey`")
        }

        try mock(id, fromPrekey)            
    }

    // MARK: - establishSession

    public var establishSessionIdFromMessage_Invocations: [(id: String, message: String)] = []
    public var establishSessionIdFromMessage_MockError: Error?
    public var establishSessionIdFromMessage_MockMethod: ((String, String) throws -> Data)?
    public var establishSessionIdFromMessage_MockValue: Data?

    public func establishSession(id: String, fromMessage message: String) throws -> Data {
        establishSessionIdFromMessage_Invocations.append((id: id, message: message))

        if let error = establishSessionIdFromMessage_MockError {
            throw error
        }

        if let mock = establishSessionIdFromMessage_MockMethod {
            return try mock(id, message)
        } else if let mock = establishSessionIdFromMessage_MockValue {
            return mock
        } else {
            fatalError("no mock for `establishSessionIdFromMessage`")
        }
    }

    // MARK: - deleteSession

    public var deleteSessionId_Invocations: [String] = []
    public var deleteSessionId_MockError: Error?
    public var deleteSessionId_MockMethod: ((String) throws -> Void)?

    public func deleteSession(id: String) throws {
        deleteSessionId_Invocations.append(id)

        if let error = deleteSessionId_MockError {
            throw error
        }

        guard let mock = deleteSessionId_MockMethod else {
            fatalError("no mock for `deleteSessionId`")
        }

        try mock(id)            
    }

    // MARK: - sessionExists

    public var sessionExistsId_Invocations: [String] = []
    public var sessionExistsId_MockMethod: ((String) -> Bool)?
    public var sessionExistsId_MockValue: Bool?

    public func sessionExists(id: String) -> Bool {
        sessionExistsId_Invocations.append(id)

        if let mock = sessionExistsId_MockMethod {
            return mock(id)
        } else if let mock = sessionExistsId_MockValue {
            return mock
        } else {
            fatalError("no mock for `sessionExistsId`")
        }
    }

    // MARK: - encrypt

    public var encryptDataForSession_Invocations: [(data: Data, id: String)] = []
    public var encryptDataForSession_MockError: Error?
    public var encryptDataForSession_MockMethod: ((Data, String) throws -> Data)?
    public var encryptDataForSession_MockValue: Data?

    public func encrypt(data: Data, forSession id: String) throws -> Data {
        encryptDataForSession_Invocations.append((data: data, id: id))

        if let error = encryptDataForSession_MockError {
            throw error
        }

        if let mock = encryptDataForSession_MockMethod {
            return try mock(data, id)
        } else if let mock = encryptDataForSession_MockValue {
            return mock
        } else {
            fatalError("no mock for `encryptDataForSession`")
        }
    }

    // MARK: - encryptBatched

    public var encryptBatchedDataForSessions_Invocations: [(data: Data, sessions: [String])] = []
    public var encryptBatchedDataForSessions_MockError: Error?
    public var encryptBatchedDataForSessions_MockMethod: ((Data, [String]) throws -> [String: Data])?
    public var encryptBatchedDataForSessions_MockValue: [String: Data]?

    public func encryptBatched(data: Data, forSessions sessions: [String]) throws -> [String: Data] {
        encryptBatchedDataForSessions_Invocations.append((data: data, sessions: sessions))

        if let error = encryptBatchedDataForSessions_MockError {
            throw error
        }

        if let mock = encryptBatchedDataForSessions_MockMethod {
            return try mock(data, sessions)
        } else if let mock = encryptBatchedDataForSessions_MockValue {
            return mock
        } else {
            fatalError("no mock for `encryptBatchedDataForSessions`")
        }
    }

    // MARK: - decrypt

    public var decryptDataForSession_Invocations: [(data: Data, id: String)] = []
    public var decryptDataForSession_MockError: Error?
    public var decryptDataForSession_MockMethod: ((Data, String) throws -> Data)?
    public var decryptDataForSession_MockValue: Data?

    public func decrypt(data: Data, forSession id: String) throws -> Data {
        decryptDataForSession_Invocations.append((data: data, id: id))

        if let error = decryptDataForSession_MockError {
            throw error
        }

        if let mock = decryptDataForSession_MockMethod {
            return try mock(data, id)
        } else if let mock = decryptDataForSession_MockValue {
            return mock
        } else {
            fatalError("no mock for `decryptDataForSession`")
        }
    }

    // MARK: - generatePrekey

    public var generatePrekeyId_Invocations: [UInt16] = []
    public var generatePrekeyId_MockError: Error?
    public var generatePrekeyId_MockMethod: ((UInt16) throws -> String)?
    public var generatePrekeyId_MockValue: String?

    public func generatePrekey(id: UInt16) throws -> String {
        generatePrekeyId_Invocations.append(id)

        if let error = generatePrekeyId_MockError {
            throw error
        }

        if let mock = generatePrekeyId_MockMethod {
            return try mock(id)
        } else if let mock = generatePrekeyId_MockValue {
            return mock
        } else {
            fatalError("no mock for `generatePrekeyId`")
        }
    }

    // MARK: - lastPrekey

    public var lastPrekey_Invocations: [Void] = []
    public var lastPrekey_MockError: Error?
    public var lastPrekey_MockMethod: (() throws -> String)?
    public var lastPrekey_MockValue: String?

    public func lastPrekey() throws -> String {
        lastPrekey_Invocations.append(())

        if let error = lastPrekey_MockError {
            throw error
        }

        if let mock = lastPrekey_MockMethod {
            return try mock()
        } else if let mock = lastPrekey_MockValue {
            return mock
        } else {
            fatalError("no mock for `lastPrekey`")
        }
    }

    // MARK: - generatePrekeys

    public var generatePrekeysStartCount_Invocations: [(start: UInt16, count: UInt16)] = []
    public var generatePrekeysStartCount_MockError: Error?
    public var generatePrekeysStartCount_MockMethod: ((UInt16, UInt16) throws -> [IdPrekeyTuple])?
    public var generatePrekeysStartCount_MockValue: [IdPrekeyTuple]?

    public func generatePrekeys(start: UInt16, count: UInt16) throws -> [IdPrekeyTuple] {
        generatePrekeysStartCount_Invocations.append((start: start, count: count))

        if let error = generatePrekeysStartCount_MockError {
            throw error
        }

        if let mock = generatePrekeysStartCount_MockMethod {
            return try mock(start, count)
        } else if let mock = generatePrekeysStartCount_MockValue {
            return mock
        } else {
            fatalError("no mock for `generatePrekeysStartCount`")
        }
    }

    // MARK: - fingerprint

    public var fingerprint_Invocations: [Void] = []
    public var fingerprint_MockError: Error?
    public var fingerprint_MockMethod: (() throws -> String)?
    public var fingerprint_MockValue: String?

    public func fingerprint() throws -> String {
        fingerprint_Invocations.append(())

        if let error = fingerprint_MockError {
            throw error
        }

        if let mock = fingerprint_MockMethod {
            return try mock()
        } else if let mock = fingerprint_MockValue {
            return mock
        } else {
            fatalError("no mock for `fingerprint`")
        }
    }

    // MARK: - localFingerprint

    public var localFingerprintForSession_Invocations: [String] = []
    public var localFingerprintForSession_MockError: Error?
    public var localFingerprintForSession_MockMethod: ((String) throws -> String)?
    public var localFingerprintForSession_MockValue: String?

    public func localFingerprint(forSession id: String) throws -> String {
        localFingerprintForSession_Invocations.append(id)

        if let error = localFingerprintForSession_MockError {
            throw error
        }

        if let mock = localFingerprintForSession_MockMethod {
            return try mock(id)
        } else if let mock = localFingerprintForSession_MockValue {
            return mock
        } else {
            fatalError("no mock for `localFingerprintForSession`")
        }
    }

    // MARK: - remoteFingerprint

    public var remoteFingerprintForSession_Invocations: [String] = []
    public var remoteFingerprintForSession_MockError: Error?
    public var remoteFingerprintForSession_MockMethod: ((String) throws -> String)?
    public var remoteFingerprintForSession_MockValue: String?

    public func remoteFingerprint(forSession id: String) throws -> String {
        remoteFingerprintForSession_Invocations.append(id)

        if let error = remoteFingerprintForSession_MockError {
            throw error
        }

        if let mock = remoteFingerprintForSession_MockMethod {
            return try mock(id)
        } else if let mock = remoteFingerprintForSession_MockValue {
            return mock
        } else {
            fatalError("no mock for `remoteFingerprintForSession`")
        }
    }

    // MARK: - fingerprint

    public var fingerprintFromPrekey_Invocations: [String] = []
    public var fingerprintFromPrekey_MockError: Error?
    public var fingerprintFromPrekey_MockMethod: ((String) throws -> String)?
    public var fingerprintFromPrekey_MockValue: String?

    public func fingerprint(fromPrekey prekey: String) throws -> String {
        fingerprintFromPrekey_Invocations.append(prekey)

        if let error = fingerprintFromPrekey_MockError {
            throw error
        }

        if let mock = fingerprintFromPrekey_MockMethod {
            return try mock(prekey)
        } else if let mock = fingerprintFromPrekey_MockValue {
            return mock
        } else {
            fatalError("no mock for `fingerprintFromPrekey`")
        }
    }

    // MARK: - proteusCryptoboxMigrate

    public var proteusCryptoboxMigrate_Invocations: [String] = []
    public var proteusCryptoboxMigrate_MockError: Error?
    public var proteusCryptoboxMigrate_MockMethod: ((String) throws -> Void)?

    public func proteusCryptoboxMigrate(path: String) throws {
        proteusCryptoboxMigrate_Invocations.append(path)

        if let error = proteusCryptoboxMigrate_MockError {
            throw error
        }

        guard let mock = proteusCryptoboxMigrate_MockMethod else {
            fatalError("no mock for `proteusCryptoboxMigrate`")
        }

        try mock(path)
    }

}
