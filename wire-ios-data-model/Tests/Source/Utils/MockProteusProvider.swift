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
import WireDataModel

class MockProteusProvider: ProteusProviding {

    let mockProteusService: MockProteusServiceInterface
    let mockKeyStore: SpyUserClientKeyStore
    var useProteusService: Bool

    init(
        mockProteusService: MockProteusServiceInterface,
        mockKeyStore: SpyUserClientKeyStore,
        useProteusService: Bool = false
    ) {
        self.mockProteusService = mockProteusService
        self.mockKeyStore = mockKeyStore
        self.useProteusService = useProteusService
    }

    func perform<T>(
        withProteusService proteusServiceBlock: (ProteusServiceInterface) throws -> T,
        withKeyStore keyStoreBlock: (UserClientKeysStore) throws -> T)
    rethrows -> T {
        if useProteusService {
            return try proteusServiceBlock(mockProteusService)
        } else {
            return try keyStoreBlock(mockKeyStore)
        }
    }

    var mockCanPerform = true
    var canPerform: Bool {
        return mockCanPerform
    }
}
