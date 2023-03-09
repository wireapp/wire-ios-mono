//
// Wire
// Copyright (C) 2020 Wire Swiss GmbH
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
import WireRequestStrategy

public enum NotificationSessionError: Error {

    case accountNotAuthenticated
    case noEventID
    case invalidEventID
    case alreadyFetchedEvent
    case unknown

}

public protocol NotificationSessionDelegate: AnyObject {

    func notificationSessionDidFailWithError(error: NotificationSessionError)

    func notificationSessionDidGenerateNotification(
        _ notification: ZMLocalNotification?,
        unreadConversationCount: Int
    )

    func reportCallEvent(
        _ payload: CallEventPayload,
        currentTimestamp: TimeInterval
    )

}

/// A syncing layer for the notification processing
/// - note: this is the entry point of this framework. Users of
/// the framework should create an instance as soon as possible in
/// the lifetime of the notification extension, and hold on to that session
/// for the entire lifetime.
///
public class NotificationSession {

    /// The failure reason of a `NotificationSession` initialization
    /// - noAccount: Account doesn't exist

    public enum InitializationError: Error {
        case noAccount
    }

    // MARK: - Properties

    /// Directory of all application statuses.

    private let applicationStatusDirectory : ApplicationStatusDirectory

    /// The list to which save notifications of the UI moc are appended and persisted.

    private let saveNotificationPersistence: ContextDidSaveNotificationPersistence

    private var contextSaveObserverToken: NSObjectProtocol?
    private let transportSession: ZMTransportSession
    private let coreDataStack: CoreDataStack
    private let operationLoop: RequestGeneratingOperationLoop

    public let accountIdentifier: UUID

    private var callEvent: CallEventPayload?
    private var localNotifications = [ZMLocalNotification]()

    private var context: NSManagedObjectContext {
        return coreDataStack.syncContext
    }

    public weak var delegate: NotificationSessionDelegate?

    private let logger = WireLogger(tag: "notification-engine")

    // MARK: - Life cycle
        
    /// Initializes a new `SessionDirectory` to be used in an extension environment
    /// - parameter databaseDirectory: The `NSURL` of the shared group container
    /// - throws: `InitializationError.noAccount` in case the account does not exist
    /// - returns: The initialized session object if no error is thrown
    
    public convenience init(
        applicationGroupIdentifier: String,
        accountIdentifier: UUID,
        environment: BackendEnvironmentProvider,
        analytics: AnalyticsType?
    ) throws {
        let sharedContainerURL = FileManager.sharedContainerDirectory(for: applicationGroupIdentifier)
        let accountManager = AccountManager(sharedDirectory: sharedContainerURL)

        guard let account = accountManager.account(with: accountIdentifier) else {
            throw InitializationError.noAccount
        }

        let coreDataStack = CoreDataStack(
            account: account,
            applicationContainer: sharedContainerURL
        )

        coreDataStack.loadStores { error in
            // TODO jacob error handling
        }

        let cookieStorage = ZMPersistentCookieStorage(forServerName: environment.backendURL.host!, userIdentifier: accountIdentifier)
        let reachabilityGroup = ZMSDispatchGroup(dispatchGroup: DispatchGroup(), label: "Sharing session reachability")!
        let serverNames = [environment.backendURL, environment.backendWSURL].compactMap { $0.host }
        let reachability = ZMReachability(serverNames: serverNames, group: reachabilityGroup)

        let credentials = environment.proxy.flatMap { ProxyCredentials.retrieve(for: $0) }

        let transportSession =  ZMTransportSession(
            environment: environment,
            proxyUsername: credentials?.username,
            proxyPassword: credentials?.password,
            cookieStorage: cookieStorage,
            reachability: reachability,
            initialAccessToken: nil,
            applicationGroupIdentifier: applicationGroupIdentifier,
            applicationVersion: "1.0.0"
        )

        try self.init(
            coreDataStack: coreDataStack,
            transportSession: transportSession,
            cachesDirectory: FileManager.default.cachesURLForAccount(with: accountIdentifier, in: sharedContainerURL),
            accountContainer: CoreDataStack.accountDataFolder(accountIdentifier: accountIdentifier, applicationContainer: sharedContainerURL),
            analytics: analytics,
            accountIdentifier: accountIdentifier
        )
    }

    convenience init(
        coreDataStack: CoreDataStack,
        transportSession: ZMTransportSession,
        cachesDirectory: URL,
        accountContainer: URL,
        analytics: AnalyticsType?,
        accountIdentifier: UUID
    ) throws {
        let applicationStatusDirectory = ApplicationStatusDirectory(
            syncContext: coreDataStack.syncContext,
            transportSession: transportSession
        )

        let notificationsTracker = (analytics != nil) ? NotificationsTracker(analytics: analytics!) : nil

        let pushNotificationStrategy = PushNotificationStrategy(
            withManagedObjectContext: coreDataStack.syncContext,
            eventContext: coreDataStack.eventContext,
            applicationStatus: applicationStatusDirectory,
            pushNotificationStatus: applicationStatusDirectory.pushNotificationStatus,
            notificationsTracker: notificationsTracker
        )

        let requestGeneratorStore = RequestGeneratorStore(strategies: [pushNotificationStrategy])
        
        let operationLoop = RequestGeneratingOperationLoop(
            userContext: coreDataStack.viewContext,
            syncContext: coreDataStack.syncContext,
            callBackQueue: .main,
            requestGeneratorStore: requestGeneratorStore,
            transportSession: transportSession
        )
        
        let saveNotificationPersistence = ContextDidSaveNotificationPersistence(accountContainer: accountContainer)
        
        try self.init(
            coreDataStack: coreDataStack,
            transportSession: transportSession,
            cachesDirectory: cachesDirectory,
            saveNotificationPersistence: saveNotificationPersistence,
            applicationStatusDirectory: applicationStatusDirectory,
            operationLoop: operationLoop,
            accountIdentifier: accountIdentifier,
            pushNotificationStrategy: pushNotificationStrategy
        )
    }

    init(
        coreDataStack: CoreDataStack,
        transportSession: ZMTransportSession,
        cachesDirectory: URL,
        saveNotificationPersistence: ContextDidSaveNotificationPersistence,
        applicationStatusDirectory: ApplicationStatusDirectory,
        operationLoop: RequestGeneratingOperationLoop,
        accountIdentifier: UUID,
        pushNotificationStrategy: PushNotificationStrategy
    ) throws {
        self.coreDataStack = coreDataStack
        self.transportSession = transportSession
        self.saveNotificationPersistence = saveNotificationPersistence
        self.applicationStatusDirectory = applicationStatusDirectory
        self.operationLoop = operationLoop
        self.accountIdentifier = accountIdentifier
        pushNotificationStrategy.delegate = self
    }

    deinit {
        if let token = contextSaveObserverToken {
            NotificationCenter.default.removeObserver(token)
            contextSaveObserverToken = nil
        }

        transportSession.reachability.tearDown()
        transportSession.tearDown()
    }

    // MARK: - Methods
    
    public func processPushNotification(with payload: [AnyHashable: Any]) {
        logger.info("Received push notification with payload: \(payload)")

        coreDataStack.syncContext.performGroupedBlock {
            if self.applicationStatusDirectory.authenticationStatus.state == .unauthenticated {
                self.logger.error("Not displaying notification because app is not authenticated")
                self.delegate?.notificationSessionDidFailWithError(error: .accountNotAuthenticated)
                return
            }

            self.fetchEvents(fromPushChannelPayload: payload)
        }
    }
    
    func fetchEvents(fromPushChannelPayload payload: [AnyHashable: Any]) {
        guard let nonce = self.messageNonce(fromPushChannelData: payload) else {
            delegate?.notificationSessionDidFailWithError(error: .noEventID)
            return
        }

        applicationStatusDirectory.pushNotificationStatus.fetch(eventId: nonce) { result in
            switch result {
            case .success:
                break

            case .failure(.alreadyFetchedEvent):
                self.delegate?.notificationSessionDidFailWithError(error: .alreadyFetchedEvent)

            case .failure(.invalidEventID):
                self.delegate?.notificationSessionDidFailWithError(error: .invalidEventID)

            case .failure(.unknown):
                self.delegate?.notificationSessionDidFailWithError(error: .unknown)
            }
        }
    }

    private func messageNonce(fromPushChannelData payload: [AnyHashable: Any]) -> UUID? {
        guard
            let notificationData = payload[PushChannelKeys.data.rawValue] as? [AnyHashable: Any],
            let data = notificationData[PushChannelKeys.data.rawValue] as? [AnyHashable: Any],
            let rawUUID = data[PushChannelKeys.identifier.rawValue] as? String
        else {
            return nil
        }

        return UUID(uuidString: rawUUID)
    }
    
    private enum PushChannelKeys: String {
        case data = "data"
        case identifier = "id"
    }
}

extension NotificationSession: PushNotificationStrategyDelegate {

    func pushNotificationStrategy(_ strategy: PushNotificationStrategy, didFetchEvents events: [ZMUpdateEvent]) {
        for event in events {
            if let callEventPayload = callEventPayloadForCallKit(from: event) {
                // Only store the last call event.
                callEvent = callEventPayload
            } else if let notification = notification(from: event, in: context) {
                localNotifications.append(notification)
            }
        }
    }

    private func callEventPayloadForCallKit(from event: ZMUpdateEvent) -> CallEventPayload? {
        // The API to report VoIP pushes from the notification service extension
        // is only available from iOS 14.5.
        guard #available(iOSApplicationExtension 14.5, *) else {
            return nil
        }

        // Ensure this actually is a call event.
        guard let callContent = CallEventContent(from: event) else {
            return nil
        }

        logger.info("did receive call event: \(callContent)")

        guard let callerID = event.senderUUID else {
            logger.error("should not handle call event: senderUUID missing from event")
            return nil
        }

        guard let caller = ZMUser.fetch(
            with: callerID,
            domain: event.senderDomain,
            in: context
        ) else {
            logger.warn("should not handle call event: caller not in db")
            return nil
        }

        guard let conversationID = event.conversationUUID else {
            logger.error("should not handle call event: conversationUUID missing from event")
            return nil
        }

        guard let conversation = ZMConversation.fetch(
            with: conversationID,
            domain: event.conversationDomain,
            in: context
        ) else {
            logger.warn("should not handle call event: conversation not in db")
            return nil
        }

        guard !conversation.needsToBeUpdatedFromBackend else {
            logger.warn("should not handle call event: conversation not synced")
            return nil
        }

        if conversation.mutedMessageTypesIncludingAvailability != .none {
            logger.info("should not handle call event: conversation is muted or user is not available")
            return nil
        }

        guard VoIPPushHelper.isAVSReady else {
            logger.warn("should not handle call event: AVS is not ready")
            return nil
        }

        guard VoIPPushHelper.isCallKitAvailable else {
            logger.info("should not handle call event: CallKit is not available")
            return nil
        }

        guard VoIPPushHelper.isUserSessionLoaded(accountID: accountIdentifier) else {
            logger.warn("should not handle call event: user session is not loaded")
            return nil
        }

        let handle = "\(accountIdentifier.transportString())+\(conversationID.transportString())"
        let wasCallHandleReported = VoIPPushHelper.knownCallHandles.contains(handle)

        // Should not handle a call if the caller is a self user and it's an incoming call or call end.
        // The caller can be the same as the self user if it's a rejected call or answered elsewhere.
        if
            let selfUserID = ZMUser.selfUser(in: context).remoteIdentifier,
            let callerID = callContent.callerID,
            callerID == selfUserID,
            (callContent.isIncomingCall || callContent.isEndCall)
        {
            logger.info("should not handle call event: self call")
            return nil
        }

        if callContent.initiatesRinging, !wasCallHandleReported {
            logger.info("should initiate ringing")
            return CallEventPayload(
                accountID: accountIdentifier.uuidString,
                conversationID: conversationID.uuidString,
                shouldRing: true,
                callerName: conversation.localizedCallerName(with: caller),
                hasVideo: callContent.isVideo
            )
        } else if callContent.terminatesRinging, wasCallHandleReported {
            logger.info("should terminate ringing")
            return CallEventPayload(
                accountID: accountIdentifier.uuidString,
                conversationID: conversationID.uuidString,
                shouldRing: false,
                callerName: conversation.localizedCallerName(with: caller),
                hasVideo: callContent.isVideo
            )
        } else {
            logger.info("should not handle call event: nothing to report")
            return nil
        }
    }

    func pushNotificationStrategyDidFinishFetchingEvents(_ strategy: PushNotificationStrategy) {
        processCallEvent()
        processLocalNotifications()
    }

    private func processCallEvent() {
        if let callEvent = callEvent {
            delegate?.reportCallEvent(
                callEvent,
                currentTimestamp: context.serverTimeDelta
            )

            self.callEvent = nil
        }
    }

    private func processLocalNotifications() {
        let notification: ZMLocalNotification?

        if localNotifications.count > 1 {
            notification = ZMLocalNotification.bundledMessages(count: localNotifications.count, in: context)
        } else {
            notification = localNotifications.first
        }

        let unreadCount = Int(ZMConversation.unreadConversationCount(in: context))
        delegate?.notificationSessionDidGenerateNotification(notification, unreadConversationCount: unreadCount)
        localNotifications.removeAll()
    }

}

// MARK: - Converting events to localNotifications

extension NotificationSession {

    private func notification(from event: ZMUpdateEvent, in context: NSManagedObjectContext) -> ZMLocalNotification? {
        var note: ZMLocalNotification?

        guard let conversationID = event.conversationUUID else {
            return nil
        }

        let conversation = ZMConversation.fetch(with: conversationID, domain: event.conversationDomain, in: context)

        if let callEventContent = CallEventContent(from: event) {
            let currentTimestamp = Date().addingTimeInterval(context.serverTimeDelta)

            /// The caller should not be the same as the user receiving the call event and
            /// the age of the event is less than 30 seconds
            guard
                let callState = callEventContent.callState,
                let callerID = callEventContent.callerID,
                let caller = ZMUser.fetch(with: callerID, domain: event.senderDomain, in: context),
                caller != ZMUser.selfUser(in: context),
                !isEventTimedOut(currentTimestamp: currentTimestamp, eventTimestamp: event.timestamp)
            else {
                return nil
            }

            note = ZMLocalNotification.init(callState: callState, conversation: conversation, caller: caller, moc: context)

        } else {
            note = ZMLocalNotification.init(event: event, conversation: conversation, managedObjectContext: context)
        }

        note?.increaseEstimatedUnreadCount(on: conversation)
        return note
    }

    private func isEventTimedOut(currentTimestamp: Date, eventTimestamp: Date?) -> Bool {
        guard let eventTimestamp = eventTimestamp else {
            return true
        }

        return Int(currentTimestamp.timeIntervalSince(eventTimestamp)) > 30
    }

}

public struct CallEventPayload {

    public let accountID: String
    public let conversationID: String
    public let shouldRing: Bool
    public let callerName: String
    public let hasVideo: Bool

    public init(
        accountID: String,
        conversationID: String,
        shouldRing: Bool,
        callerName: String,
        hasVideo: Bool
    ) {
        self.accountID = accountID
        self.conversationID = conversationID
        self.shouldRing = shouldRing
        self.callerName = callerName
        self.hasVideo = hasVideo
    }

}

