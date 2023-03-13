//
// Wire
// Copyright (C) 2022 Wire Swiss GmbH
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
import CoreData

private let zmLog = ZMSLog(tag: "Patches")

public final class PatchApplicator<T: DataPatchInterface> {

    public let lastRunVersionKey: String

    public init(lastRunVersionKey: String) {
        self.lastRunVersionKey = lastRunVersionKey
    }

    public func applyPatches(in context: NSManagedObjectContext) {
        // Get the current version
        let currentVersion = T.allCases.count

        defer {
            context.setPersistentStoreMetadata(currentVersion, key: self.lastRunVersionKey)
            context.saveOrRollback()
        }

        // Get the previous version
        guard let previousVersion = context.persistentStoreMetadata(forKey: self.lastRunVersionKey) as? Int
        else {
            // no version was run, this is a fresh install, skipping...
            zmLog.info("no version was run, this is a fresh install, skipping...")
            return
        }

        zmLog.info("previousVersion\(previousVersion)")
        T.allCases
            .filter { $0.version > previousVersion }
            .forEach {
            $0.execute(in: context)
        }
    }
}

public protocol DataPatchInterface: CaseIterable {

    var version: Int { get }
    func execute(in context: NSManagedObjectContext)

}

// When we add the first patch, uncomment this type and add an enum
// case. The patch code should go in the execute method.

// enum DataPatch: Int, DataPatchInterface {
//
//
//
//    var version: Int {
//        return rawValue
//    }
//
//    func execute(in context: NSManagedObjectContext) {
//        switch self {
//        }
//    }
// }
