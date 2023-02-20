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

public struct WireLogger: LoggerProtocol {

  public static var provider: LoggerProtocol?

  public let tag: String

  public init(tag: String = "") {
    self.tag = tag
  }

  public func debug(
    _ message: String,
    attributes: LogAttributes? = nil
  ) {
    guard shouldLogMessage(message) else { return }
    log(level: .debug, message: message, attributes: attributes)
  }

  public func info(
    _ message: String,
    attributes: LogAttributes? = nil
  ) {
    guard shouldLogMessage(message) else { return }
    log(level: .info, message: message, attributes: attributes)
  }

  public func notice(
    _ message: String,
    attributes: LogAttributes? = nil
  ) {
    guard shouldLogMessage(message) else { return }
    log(level: .notice, message: message, attributes: attributes)
  }

  public func warn(
    _ message: String,
    attributes: LogAttributes? = nil
  ) {
    guard shouldLogMessage(message) else { return }
    log(level: .warn, message: message, attributes: attributes)
  }

  public func error(
    _ message: String,
    attributes: LogAttributes? = nil
  ) {
    guard shouldLogMessage(message) else { return }
    log(level: .error, message: message, attributes: attributes)
  }

  public func critical(
    _ message: String,
    attributes: LogAttributes? = nil
  ) {
    guard shouldLogMessage(message) else { return }
    log(level: .critical, message: message, attributes: attributes)
  }

  private func shouldLogMessage(_ message: String) -> Bool {
    return Self.provider != nil && !message.isEmpty
  }

  private func log(
    level: LogLevel,
    message: String,
    attributes: LogAttributes? = nil
  ) {
    var attributes = attributes ?? .init()

    if !tag.isEmpty {
      attributes["tag"] = tag
    }

    switch level {
    case .debug:
      Self.provider?.debug(message, attributes: attributes)

    case .info:
      Self.provider?.info(message, attributes: attributes)

    case .notice:
      Self.provider?.notice(message, attributes: attributes)

    case .warn:
      Self.provider?.warn(message, attributes: attributes)

    case .error:
      Self.provider?.error(message, attributes: attributes)

    case .critical:
      Self.provider?.critical(message, attributes: attributes)
    }
  }

  private enum LogLevel {

    case debug
    case info
    case notice
    case warn
    case error
    case critical

  }

}

public typealias LogAttributes = [String: Encodable]

public protocol LoggerProtocol {

  func debug(_ message: String, attributes: LogAttributes?)
  func info(_ message: String, attributes: LogAttributes?)
  func notice(_ message: String, attributes: LogAttributes?)
  func warn(_ message: String, attributes: LogAttributes?)
  func error(_ message: String, attributes: LogAttributes?)
  func critical(_ message: String, attributes: LogAttributes?)

}
