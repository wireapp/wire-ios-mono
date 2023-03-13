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

public enum SecurityClassification {
    case none
    case classified
    case notClassified
}

extension ZMUserSession {

    public func classification(with users: [UserType]) -> SecurityClassification {
        guard isSelfClassified else { return .none }

        let isClassified = users.allSatisfy {
            classification(with: $0) == .classified
        }

        return isClassified ? .classified : .notClassified
    }

    private func classification(with user: UserType) -> SecurityClassification {
        guard isSelfClassified else { return .none }

        guard let otherDomain = domain(for: user) else { return .notClassified }

        return classifiedDomainsFeature.config.domains.contains(otherDomain) ? .classified : .notClassified
    }

    private var isSelfClassified: Bool {
        classifiedDomainsFeature.status == .enabled && selfUser.domain != nil
    }

    // If other user does not have a domain the conversation will be marked as unclassified
    // We've had a different behaviour on Android & Web on column-1
    // We could not save domain to the database as of now, because of how other features depend on it
    // If federation is disabled we know that the user is from local backend, so we can fallback to local domain and check if it is classified
    private func domain(for user: UserType) -> String? {
        guard BackendInfo.isFederationEnabled else {
            return user.domain ?? BackendInfo.domain
        }
        return user.domain
    }
}
