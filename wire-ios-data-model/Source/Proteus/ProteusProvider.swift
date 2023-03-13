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
import WireUtilities

public typealias KeyStorePerformBlock<T> = ((UserClientKeysStore) throws -> T)
public typealias ProteusServicePerformBlock<T> = ((ProteusServiceInterface) throws -> T)

public protocol ProteusProviding {

    func perform<T>(
        withProteusService proteusServiceBlock: ProteusServicePerformBlock<T>,
        withKeyStore keyStoreBlock: KeyStorePerformBlock<T>
    ) rethrows -> T

    var canPerform: Bool { get }
}

public class ProteusProvider: ProteusProviding {

    private let context: NSManagedObjectContext
    private let proteusViaCoreCrypto: Bool

    public init(
        context: NSManagedObjectContext,
        proteusViaCoreCrypto: Bool = DeveloperFlag.proteusViaCoreCrypto.isOn
    ) {
        self.context = context
        self.proteusViaCoreCrypto = proteusViaCoreCrypto
    }

    public func perform<T>(
        withProteusService proteusServiceBlock: ProteusServicePerformBlock<T>,
        withKeyStore keyStoreBlock: KeyStorePerformBlock<T>
    ) rethrows -> T {

        precondition(context.zm_isSyncContext, "ProteusProvider should only be used on the sync context")

        if let proteusService = context.proteusService {

            precondition(proteusViaCoreCrypto, "core crypto should only be used when the flag is on")
            return try proteusServiceBlock(proteusService)

        } else if let keyStore = context.zm_cryptKeyStore {

            // remove comment once implementation of proteus via core crypto is done
            // precondition(!proteusViaCoreCrypto, "cryptobox should only be used when the flag is off")
            return try keyStoreBlock(keyStore)

        } else {
            WireLogger.coreCrypto.error("can't access any proteus cryptography service")
            fatal("can't access any proteus cryptography service")
        }
    }

    public var canPerform: Bool {
        let canUseProteusService = proteusViaCoreCrypto && context.proteusService != nil
        let canUseKeyStore = !proteusViaCoreCrypto && context.zm_cryptKeyStore != nil

        return canUseProteusService || canUseKeyStore
    }

}
