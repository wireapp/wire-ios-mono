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

import Foundation

extension LegacyPersistedDataPatch {

    /// List of patches to apply
    static let allPatchesToApply = [
        LegacyPersistedDataPatch(version: "41.0.0", block: UserClient.migrateAllSessionsClientIdentifiersV2),
        LegacyPersistedDataPatch(version: "43.0.4", block: ZMConversation.migrateAllSecureWithIgnored),
        LegacyPersistedDataPatch(version: "58.4.1", block: Team.deleteLocalTeamsAndMembers),
        LegacyPersistedDataPatch(version: "62.1.0", block: Member.migrateRemoteIdentifiers),
        LegacyPersistedDataPatch(version: "78.1.0", block: DuplicatedEntityRemoval.removeDuplicated),
        LegacyPersistedDataPatch(version: "81.2.1", block: InvalidClientsRemoval.removeInvalid),
        LegacyPersistedDataPatch(version: "103.0.2", block: InvalidGenericMessageDataRemoval.removeInvalid),
        LegacyPersistedDataPatch(version: "145.0.3", block: InvalidConversationRemoval.removeInvalid),
        LegacyPersistedDataPatch(version: "161.0.1", block: TransferStateMigration.migrateLegacyTransferState),
        LegacyPersistedDataPatch(version: "167.3.0", block: AvailabilityBehaviourChange.notifyAvailabilityBehaviourChange),
        LegacyPersistedDataPatch(version: "198.0.0", block: ZMConversation.introduceParticipantRoles),
        LegacyPersistedDataPatch(version: "220.0.4", block: InvalidConnectionRemoval.removeInvalid),
        LegacyPersistedDataPatch(version: "234.0.0", block: TransferApplockKeychain.migrateKeychainItems),
        LegacyPersistedDataPatch(version: "234.1.1", block: InvalidConnectionRemoval.removeInvalid),
        LegacyPersistedDataPatch(version: "236.0.0", block: MigrateSenderClient.migrateSenderClientID),
        LegacyPersistedDataPatch(version: "243.0.0", block: InvalidFeatureRemoval.removeInvalid),
        LegacyPersistedDataPatch(version: "273.2.0", block: InvalidDomainRemoval.removeDuplicatedEntitiesWithInvalidDomain),
        LegacyPersistedDataPatch(version: "279.0.4", block: InvalidFeatureRemoval.restoreDefaultConferenceCallingConfig),
        LegacyPersistedDataPatch(version: "285.0.0", block: ZMConversation.introduceAccessRoleV2),
        LegacyPersistedDataPatch(version: "290.0.1", block: ZMUser.refetchSelfUserDomain)
    ]

}
