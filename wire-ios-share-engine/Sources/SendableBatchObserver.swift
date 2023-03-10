//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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
import WireSystem

public final class SendableBatchObserver {

    public let sendables: [Sendable]

    public var sentHandler: (() -> Void)?
    public var progressHandler: ((Float) -> Void)?
    private var observerToken: Any?
    let logger = WireLogger(tag: "share extension")

    public init(sendables: [Sendable]) {
        self.sendables = sendables
        self.observerToken = NotificationCenter.default.addObserver(forName: contextWasMergedNotification,
                                                                    object: nil,
                                                                    queue: nil) { [weak self] _ in
            print("SHARING: Observer token")
            DispatchQueue.main.async {
                self?.onDeliveryChanged()
            }
        }
    }

    deinit {
        if let observer = self.observerToken {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public var allSendablesSent: Bool {
        return !sendables.contains { !$0.isSent }
    }

    public func onDeliveryChanged() {
        print("SHARING: On Delivery Changed")
        if allSendablesSent {
            print("SHARING: All Sendables are sent")
            DispatchQueue.main.async { [weak self] in
                self?.sentHandler?()
            }
        }

        updateProgress()
    }

    private func updateProgress() {
        var totalProgress: Float = 0
        print("SHARING: Updating progress")
        sendables.forEach { message in
            if message.isSent {
                totalProgress += 1.0 / Float(sendables.count)
            } else {
                let messageProgress = (message.deliveryProgress ?? 0)
                totalProgress += messageProgress / Float(sendables.count)
            }
        }
        print("SHARING: Progress calculated \(totalProgress)")

        DispatchQueue.main.async { [weak self] in
            self?.progressHandler?(totalProgress)
        }
    }

}
