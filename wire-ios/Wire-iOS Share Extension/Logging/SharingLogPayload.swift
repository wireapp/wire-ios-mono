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

import WireSystem

enum SharingStatus: String, Encodable {
    case preparing
    case started
    case sending
    case done
    case conversationDegraded
    case timedOut
    case error
    case fileSharingRestricted
}

enum SharingProgress: String, Encodable {
    case progress
}

struct SharingLog: LogMessage {
    private struct Payload: Encodable {
        let status: SharingStatus
        let progress: SharingProgress?
        let errorDescription: String?

        private static let payloadEncoder: JSONEncoder = JSONEncoder()

        var payloadDescription: String {
            guard let payloadData = try? Self.payloadEncoder.encode(self),
                  let payloadString = String(data: payloadData, encoding: .utf8) else {
              return "PAYLOAD ENCODING ERROR"
            }
            return "\(payloadString)"
        }
    }

    private let payload: Payload

    init(status: SharingStatus, progress: SharingProgress? = nil, errorDescription: String? = nil) {
        self.payload = Payload(status: status, progress: progress, errorDescription: errorDescription)
    }

    var logDescription: String {
        return "SHARING: \(payload.payloadDescription)"
    }
}
