//
// Wire
// Copyright (C) 2017 Wire Swiss GmbH
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

import WireSystem

enum BuildType: Equatable {

    case production
    case alpha
    case beta
    case development
    case `internal`
    case releaseCandidate
    case custom(bundleID: String)

    init(bundleID: String) {
        switch bundleID {
        case BuildType.production.bundleID:
            self = .production

        case BuildType.alpha.bundleID:
            self = .alpha

        case BuildType.beta.bundleID:
            self = .beta

        case BuildType.development.bundleID:
            self = .development

        case BuildType.internal.bundleID:
            self = .internal

        case BuildType.releaseCandidate.bundleID:
            self = .releaseCandidate

        default:
            self = .custom(bundleID: bundleID)
        }
    }

    var certificateName: String {
        switch self {
        case .production:
            return "com.wire"

        case .alpha, .beta, .development, .internal, .releaseCandidate:
            return bundleID

        case .custom(let bundleID):
            return bundleID
        }
    }

    var bundleID: String {
        switch self {
        case .production:
            return "com.wearezeta.zclient.ios"

        case .alpha:
            return "com.wearezeta.zclient.alpha"

        case .beta:
            return "com.wearezeta.zclient.ios.beta"

        case .development:
            return "com.wearezeta.zclient.development"

        case .internal:
            return "com.wearezeta.zclient.internal"

        case .releaseCandidate:
            return "com.wearezeta.zclient.rc"

        case .custom(let bundleID):
            return bundleID
        }
    }

}
