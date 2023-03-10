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

public protocol RemoteLogger {
    func log(message: String, error: Error?, attributes: [String: Encodable]?, level: RemoteMonitoring.Level)
}

extension RemoteLogger {
    func log(message: String, error: Error? = nil, attributes: [String: Encodable]? = nil, level: RemoteMonitoring.Level = .debug) {
        RemoteMonitoring.remoteLogger?.log(message: message, error: error, attributes: attributes, level: level)
    }
}

public class RemoteMonitoring: NSObject {
    @objc public enum Level: Int {
        case debug
        case info
        case notice
        case warn
        case error
        case critical
    }

    var level: Level

    @objc init(level: Level) {
        self.level = level
    }

    public static var remoteLogger: RemoteLogger?

    @objc func log(_ message: String, error: Error? = nil) {
        Self.remoteLogger?.log(message: message, error: nil, attributes: nil, level: level)
    }

    @objc func log(request: NSURLRequest) {
        let info = RequestLog(request)

        do {
            let data = try JSONEncoder().encode(info)
            let jsonString = String(data: data, encoding: .utf8)
            let message = "REQUEST: \(jsonString ?? request.description)"
            Self.remoteLogger?.log(message: message, error: nil, attributes: nil, level: level)
        } catch {
            let message = "REQUEST: \(request.description)"
            Self.remoteLogger?.log(message: message, error: error, attributes: nil, level: level)
        }
    }

    @objc func log(response: HTTPURLResponse) {
        guard let info = ResponseLog(response) else { return }

        do {
            let data = try JSONEncoder().encode(info)
            let jsonString = String(data: data, encoding: .utf8)
            let message = "RESPONSE: \(jsonString ?? response.description)"
            Self.remoteLogger?.log(message: message, error: nil, attributes: nil, level: level)
        } catch {
            let message = "RESPONSE: \(response.description)"
            Self.remoteLogger?.log(message: message, error: error, attributes: nil, level: level)
        }
    }
}
