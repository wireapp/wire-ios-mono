// Wire
// Copyright (C) 2021 Wire Swiss GmbH
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

protocol EventData {
    static var eventType: ZMUpdateEventType { get }
}

typealias CodableEventData = EventData & Codable

extension Payload {

    struct NewConversation: EncodableAPIVersionAware {
        enum CodingKeys: String, CodingKey {
            case users
            case qualifiedUsers = "qualified_users"
            case access
            case accessRole = "access_role"
            case accessRoleV2 = "access_role_v2"
            case name
            case team
            case messageTimer = "message_timer"
            case readReceiptMode = "receipt_mode"
            case conversationRole = "conversation_role"
        }

        let users: [UUID]?
        let qualifiedUsers: [QualifiedID]?
        let access: [String]?
        let legacyAccessRole: String?
        let accessRoles: [String]?
        let name: String?
        let team: ConversationTeamInfo?
        let messageTimer: TimeInterval?
        let readReceiptMode: Int?
        let conversationRole: String?

        init(_ conversation: ZMConversation) {
            if let qualifiedUsers = conversation.localParticipantsExcludingSelf.qualifiedUserIDs {
                self.qualifiedUsers = qualifiedUsers
                self.users = nil
            } else {
                qualifiedUsers = nil
                users = conversation.localParticipantsExcludingSelf.map(\.remoteIdentifier)
            }

            name = conversation.userDefinedName
            access = conversation.accessMode?.stringValue
            legacyAccessRole = conversation.accessRole?.rawValue
            accessRoles = conversation.accessRoles.map(\.rawValue)
            conversationRole = ZMConversation.defaultMemberRoleName
            team = conversation.team?.remoteIdentifier.map({ ConversationTeamInfo(teamID: $0) })
            readReceiptMode = conversation.hasReadReceiptsEnabled ? 1 : 0
            messageTimer = nil
        }

        func encode(to encoder: Encoder, apiVersion: APIVersion) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encodeIfPresent(users, forKey: .users)
            try container.encodeIfPresent(qualifiedUsers, forKey: .qualifiedUsers)
            try container.encodeIfPresent(access, forKey: .access)
            try container.encodeIfPresent(name, forKey: .name)
            try container.encodeIfPresent(team, forKey: .team)
            try container.encodeIfPresent(messageTimer, forKey: .messageTimer)
            try container.encodeIfPresent(readReceiptMode, forKey: .readReceiptMode)
            try container.encodeIfPresent(conversationRole, forKey: .conversationRole)

            switch apiVersion {
            case .v0, .v1, .v2:
                try container.encodeIfPresent(legacyAccessRole, forKey: .accessRole)
                try container.encodeIfPresent(accessRoles, forKey: .accessRoleV2)
            case .v3:
                try container.encodeIfPresent(accessRoles, forKey: .accessRole)
            }
        }
    }

    struct Conversation: DecodableAPIVersionAware, EventData {

        enum CodingKeys: String, CodingKey {
            case qualifiedID = "qualified_id"
            case id
            case type
            case creator
            case access
            case accessRole = "access_role"
            case accessRoleV2 = "access_role_v2"
            case name
            case members
            case lastEvent = "last_event"
            case lastEventTime = "last_event_time"
            case teamID = "team"
            case messageTimer = "message_timer"
            case readReceiptMode = "receipt_mode"
        }

        static var eventType: ZMUpdateEventType {
            return .conversationCreate
        }

        let qualifiedID: QualifiedID?
        let id: UUID?
        let type: Int?
        let creator: UUID?
        let access: [String]?
        let accessRoles: [String]?
        let legacyAccessRole: String?
        let name: String?
        let members: ConversationMembers?
        let lastEvent: String?
        let lastEventTime: String?
        let teamID: UUID?
        let messageTimer: TimeInterval?
        let readReceiptMode: Int?

        init(qualifiedID: QualifiedID? = nil,
             id: UUID?  = nil,
             type: Int? = nil,
             creator: UUID? = nil,
             access: [String]? = nil,
             legacyAccessRole: String? = nil,
             accessRoles: [String]? = nil,
             name: String? = nil,
             members: ConversationMembers? = nil,
             lastEvent: String? = nil,
             lastEventTime: String? = nil,
             teamID: UUID? = nil,
             messageTimer: TimeInterval? = nil,
             readReceiptMode: Int? = nil) {

            self.qualifiedID = qualifiedID
            self.id = id
            self.type = type
            self.creator = creator
            self.access = access
            self.legacyAccessRole = legacyAccessRole
            self.accessRoles = accessRoles
            self.name = name
            self.members = members
            self.lastEvent = lastEvent
            self.lastEventTime = lastEventTime
            self.teamID = teamID
            self.messageTimer = messageTimer
            self.readReceiptMode = readReceiptMode
        }

        init(from decoder: Decoder, apiVersion: APIVersion) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            qualifiedID = try container.decodeIfPresent(QualifiedID.self, forKey: .qualifiedID)
            id = try container.decodeIfPresent(UUID.self, forKey: .id)
            type = try container.decodeIfPresent(Int.self, forKey: .type)
            creator = try container.decodeIfPresent(UUID.self, forKey: .creator)
            access = try container.decodeIfPresent([String].self, forKey: .access)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            members = try container.decodeIfPresent(ConversationMembers.self, forKey: .members)
            lastEvent = try container.decodeIfPresent(String.self, forKey: .lastEvent)
            lastEventTime = try container.decodeIfPresent(String.self, forKey: .lastEventTime)
            teamID = try container.decodeIfPresent(UUID.self, forKey: .teamID)
            messageTimer = try container.decodeIfPresent(TimeInterval.self, forKey: .messageTimer)
            readReceiptMode = try container.decodeIfPresent(Int.self, forKey: .readReceiptMode)

            switch apiVersion {
            case .v0, .v1, .v2:
                legacyAccessRole = try container.decodeIfPresent(String.self, forKey: .accessRole)
                accessRoles = try container.decodeIfPresent([String].self, forKey: .accessRoleV2)
            case .v3:

                // v3 replaces the field "access_role_v2" with "access_role".
                // However, since the format of update events does not depend on versioning,
                // we may receive conversations from the `conversation.create` update event
                // which still have both "access_role_v2" and "access_role" fields

                if !container.contains(CodingKeys.accessRoleV2) {
                    legacyAccessRole = nil
                    accessRoles = try container.decodeIfPresent([String].self, forKey: .accessRole)
                } else {
                    legacyAccessRole = try container.decodeIfPresent(String.self, forKey: .accessRole)
                    accessRoles = try container.decodeIfPresent([String].self, forKey: .accessRoleV2)
                }
            }
        }

    }

    struct ConversationList: Codable {
        enum CodingKeys: String, CodingKey {
            case conversations
            case hasMore = "has_more"
        }

        let conversations: [Conversation]
        let hasMore: Bool?
    }

    struct QualifiedConversationList: Codable {
        enum CodingKeys: String, CodingKey {
            case found = "found"
            case notFound = "not_found"
            case failed = "failed"
        }

        let found: [Conversation]
        let notFound: [QualifiedID]
        let failed: [QualifiedID]
    }

    struct PaginatedConversationIDList: Codable, Paginatable {

        enum CodingKeys: String, CodingKey {
            case conversations
            case hasMore = "has_more"
        }

        var nextStartReference: String? {
            return conversations.last?.transportString()
        }

        let conversations: [UUID]
        let hasMore: Bool
    }

    struct PaginatedQualifiedConversationIDList: Codable, Paginatable {

        enum CodingKeys: String, CodingKey {
            case conversations = "qualified_conversations"
            case pagingState = "paging_state"
            case hasMore = "has_more"
        }

        var nextStartReference: String? {
            return pagingState
        }

        let conversations: [QualifiedID]
        let pagingState: String
        let hasMore: Bool
    }

    struct Service: Codable {
        let id: UUID
        let provider: UUID
    }

    struct ConversationMember: CodableEventData {

        enum CodingKeys: String, CodingKey {
            case id
            case qualifiedID = "qualified_id"
            case target
            case qualifiedTarget = "qualified_target"
            case service
            case mutedStatus = "otr_muted_status"
            case mutedReference = "otr_muted_ref"
            case archived = "otr_archived"
            case archivedReference = "otr_archived_ref"
            case hidden = "otr_hidden"
            case hiddenReference = "otr_hidden_ref"
            case conversationRole = "conversation_role"
        }

        static var eventType: ZMUpdateEventType {
            return .conversationMemberUpdate
        }

        let id: UUID?
        let qualifiedID: QualifiedID?
        let target: UUID?
        let qualifiedTarget: QualifiedID?
        let service: Service?
        let mutedStatus: Int?
        let mutedReference: Date?
        let archived: Bool?
        let archivedReference: Date?
        let hidden: Bool?
        let hiddenReference: String?
        let conversationRole: String?

        init(id: UUID? = nil,
             qualifiedID: QualifiedID? = nil,
             target: UUID? = nil,
             qualifiedTarget: QualifiedID? = nil,
             service: Service? = nil,
             mutedStatus: Int? = nil,
             mutedReference: Date? = nil,
             archived: Bool? = nil,
             archivedReference: Date? = nil,
             hidden: Bool? = nil,
             hiddenReference: String? = nil,
             conversationRole: String? = nil) {
            self.id = id
            self.qualifiedID = qualifiedID
            self.target = target
            self.qualifiedTarget = qualifiedTarget
            self.service = service
            self.mutedStatus  = mutedStatus
            self.mutedReference = mutedReference
            self.archived = archived
            self.archivedReference = archivedReference
            self.hidden = hidden
            self.hiddenReference = hiddenReference
            self.conversationRole = conversationRole
        }
    }

    struct ConversationMembers: Codable {
        enum CodingKeys: String, CodingKey {
            case selfMember = "self"
            case others
        }

        let selfMember: ConversationMember
        let others: [ConversationMember]
    }

    struct ConversationTeamInfo: Codable {
        enum CodingKeys: String, CodingKey {
            case teamID = "teamid"
            case managed
        }

        init (teamID: UUID, managed: Bool = false) {
            self.teamID = teamID
            self.managed = managed
        }

        let teamID: UUID
        let managed: Bool?
    }

    struct UpdateConversationStatus: Codable {
        enum CodingKeys: String, CodingKey {
            case mutedStatus = "otr_muted_status"
            case mutedReference = "otr_muted_ref"
            case archived = "otr_archived"
            case archivedReference = "otr_archived_ref"
            case hidden = "otr_hidden"
            case hiddenReference = "otr_hidden_ref"
        }

        var mutedStatus: Int?
        var mutedReference: Date?
        var archived: Bool?
        var archivedReference: Date?
        var hidden: Bool?
        var hiddenReference: String?

        init(_ conversation: ZMConversation) {

            if conversation.hasLocalModifications(forKey: ZMConversationSilencedChangedTimeStampKey) {
                let reference = conversation.silencedChangedTimestamp ?? Date()
                conversation.silencedChangedTimestamp = reference

                mutedStatus = Int(conversation.mutedMessageTypes.rawValue)
                mutedReference = reference
            }

            if conversation.hasLocalModifications(forKey: ZMConversationArchivedChangedTimeStampKey) {
                let reference = conversation.archivedChangedTimestamp ?? Date()
                conversation.archivedChangedTimestamp = reference

                archived = conversation.isArchived
                archivedReference = reference
            }
        }
    }

    // MARK: - Actions

    struct ConversationAddMember: Codable {
        enum CodingKeys: String, CodingKey {
            case userIDs = "users"
            case qualifiedUserIDs = "qualified_users"
            case role = "conversation_role"
        }

        let userIDs: [UUID]?
        let qualifiedUserIDs: [QualifiedID]?
        let role: String

        init?(userIDs: [UUID]? = nil, qualifiedUserIDs: [QualifiedID]? = nil) {
            self.userIDs = userIDs
            self.qualifiedUserIDs = qualifiedUserIDs
            self.role = ZMConversation.defaultMemberRoleName
        }
    }

    struct ConversationUpdateRole: Codable {
        enum CodingKeys: String, CodingKey {
            case role = "conversation_role"
        }

        let role: String

        init?(role: String) {
            self.role = role
        }
    }

    // MARK: - Events

    struct ConversationEvent<T: CodableEventData>: Codable {

        enum CodingKeys: String, CodingKey {
            case id = "conversation"
            case qualifiedID = "qualified_conversation"
            case from
            case qualifiedFrom = "qualified_from"
            case timestamp = "time"
            case type
            case data
        }

        let id: UUID?
        let qualifiedID: QualifiedID?
        let from: UUID?
        let qualifiedFrom: QualifiedID?
        let timestamp: Date?
        let type: String?
        let data: T
    }

    struct UpdateConverationMemberLeave: CodableEventData {
        enum CodingKeys: String, CodingKey {
            case userIDs = "user_ids"
            case qualifiedUserIDs = "qualified_user_ids"
        }

        static var eventType: ZMUpdateEventType {
            return .conversationMemberLeave
        }

        let userIDs: [UUID]?
        let qualifiedUserIDs: [QualifiedID]?
    }

    struct UpdateConverationMemberJoin: CodableEventData {
        enum CodingKeys: String, CodingKey {
            case userIDs = "user_ids"
            case users
        }

        static var eventType: ZMUpdateEventType {
            return .conversationMemberJoin
        }

        let userIDs: [UUID]?
        let users: [ConversationMember]?
    }

    struct UpdateConversationConnectionRequest: CodableEventData {
        static var eventType: ZMUpdateEventType {
            return .conversationConnectRequest
        }
    }

    struct UpdateConversationDeleted: CodableEventData {
        static var eventType: ZMUpdateEventType {
            return .conversationDelete
        }
    }

    struct UpdateConversationReceiptMode: CodableEventData {
        enum CodingKeys: String, CodingKey {
            case readReceiptMode = "receipt_mode"
        }

        static var eventType: ZMUpdateEventType {
            return .conversationReceiptModeUpdate
        }

        let readReceiptMode: Int
    }

    struct UpdateConversationMessageTimer: CodableEventData {
        enum CodingKeys: String, CodingKey {
            case messageTimer = "message_timer"
        }

        static var eventType: ZMUpdateEventType {
            return .conversationMessageTimerUpdate
        }

        let messageTimer: TimeInterval?
    }

    struct UpdateConversationAccess: CodableEventData {
        enum CodingKeys: String, CodingKey {
            case access
            case accessRole = "access_role"
            case accessRoleV2 = "access_role_v2"
        }

        static var eventType: ZMUpdateEventType {
            return .conversationAccessModeUpdate
        }

        let access: [String]
        let accessRole: String?
        let accessRoleV2: [String]?

        init(accessMode: ConversationAccessMode, accessRoles: Set<ConversationAccessRoleV2>) {
            access = accessMode.stringValue
            accessRole = ConversationAccessRole.fromAccessRoleV2(accessRoles).rawValue
            accessRoleV2 = accessRoles.map(\.rawValue)
        }
    }

    struct UpdateConversationName: CodableEventData {
        var name: String

        static var eventType: ZMUpdateEventType {
            return .conversationRename
        }

        init?(_ conversation: ZMConversation) {
            guard
                conversation.hasLocalModifications(forKey: ZMConversationUserDefinedNameKey),
                let userDefinedName = conversation.userDefinedName
            else {
                return nil
            }

            name = userDefinedName
        }

        init(name: String) {
            self.name = name
        }
    }

}

// MARK: - Tests

extension Payload.NewConversation: DecodableAPIVersionAware {

    // Allows tests to decode `Payload.NewConversation` from a transport request
    init(from decoder: Decoder, apiVersion: APIVersion) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        users = try container.decodeIfPresent([UUID].self, forKey: .users)
        qualifiedUsers = try container.decodeIfPresent([QualifiedID].self, forKey: .qualifiedUsers)
        access = try container.decodeIfPresent([String].self, forKey: .access)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        team = try container.decodeIfPresent(Payload.ConversationTeamInfo.self, forKey: .team)
        messageTimer = try container.decodeIfPresent(TimeInterval.self, forKey: .messageTimer)
        readReceiptMode = try container.decodeIfPresent(Int.self, forKey: .readReceiptMode)
        conversationRole = try container.decodeIfPresent(String.self, forKey: .conversationRole)

        switch apiVersion {
        case .v0, .v1, .v2:
            legacyAccessRole = try container.decodeIfPresent(String.self, forKey: .accessRole)
            accessRoles = try container.decodeIfPresent([String].self, forKey: .accessRoleV2)
        case .v3:
            accessRoles = try container.decodeIfPresent([String].self, forKey: .accessRole)
            legacyAccessRole = nil
        }
    }

    init(users: [UUID]? = nil,
         qualifiedUsers: [QualifiedID]? = nil,
         access: [String]? = nil,
         legacyAccessRole: String? = nil,
         accessRoles: [String]? = nil,
         name: String? = nil,
         team: Payload.ConversationTeamInfo? = nil,
         messageTimer: TimeInterval? = nil,
         readReceiptMode: Int? = nil,
         conversationRole: String? = nil
    ) {
        self.users = users
        self.qualifiedUsers = qualifiedUsers
        self.access = access
        self.legacyAccessRole = legacyAccessRole
        self.accessRoles = accessRoles
        self.name = name
        self.team = team
        self.messageTimer = messageTimer
        self.readReceiptMode = readReceiptMode
        self.conversationRole = conversationRole
    }

}

extension Payload.Conversation: EncodableAPIVersionAware {

    func encode(to encoder: Encoder, apiVersion: APIVersion) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(qualifiedID, forKey: .qualifiedID)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(creator, forKey: .creator)
        try container.encodeIfPresent(access, forKey: .access)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(members, forKey: .members)
        try container.encodeIfPresent(lastEvent, forKey: .lastEvent)
        try container.encodeIfPresent(lastEventTime, forKey: .lastEventTime)
        try container.encodeIfPresent(teamID, forKey: .teamID)
        try container.encodeIfPresent(messageTimer, forKey: .messageTimer)
        try container.encodeIfPresent(readReceiptMode, forKey: .readReceiptMode)

        switch apiVersion {
        case .v0, .v1, .v2:
            try container.encodeIfPresent(legacyAccessRole, forKey: .accessRole)
            try container.encodeIfPresent(accessRoles, forKey: .accessRoleV2)
        case .v3:
            if legacyAccessRole == nil {
                try container.encodeIfPresent(accessRoles, forKey: .accessRole)
            } else {
                try container.encodeIfPresent(legacyAccessRole, forKey: .accessRole)
                try container.encodeIfPresent(accessRoles, forKey: .accessRoleV2)
            }
        }
    }

}
