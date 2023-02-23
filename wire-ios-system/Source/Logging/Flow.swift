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

/// A `Flow` is a structured log class that reports the progress
/// of a particular flow of code, marking the start, middle, and end
/// of the flow.
///
/// It reports the flow events via a `WireLogger` instance using a specified tag.

open class Flow {

  // MARK: - Properties

  /// The name used to identify the flow in logs.

  public let name: String

  private let logger: WireLogger

  // MARK: - Life cycle

  /// Create a new flow.
  ///
  /// - Parameters:
  ///   - tag: The log tag, can be used to group several different flows.
  ///   - name: The name of the flow, used to group several events of a single flow.

  public init(
    tag: String,
    name: String
  ) {
    self.name = name
    logger = WireLogger(tag: tag)
  }

  // MARK: - Methods

  /// Report the start of the flow.

  public func start() {
    logger.info(FlowLog(name: name, event: .start))
  }

  /// Report a checkpoint in the flow.
  ///
  /// - Parameters:
  ///   - description: A short single line string describing a point of interest.

  public func checkpoint(description: String) {
    logger.info(FlowLog(name: name, event: .checkpoint(description: description)))
  }

  /// Report a successful end to the flow.

  public func succeed() {
    logger.info(FlowLog(name: name, event: .completion(.success(()))))
  }

  /// Report a failed end to the flow.
  ///
  /// - Parameters:
  ///   - error: The failure reason.

  public func fail(_ error: Error) {
    logger.error(FlowLog(name: name, event: .completion(.failure(error))))
  }

  /// Report a failed end to the flow.
  ///
  /// - Parameters:
  ///   - reason: The failure reason.

  public func fail(_ reason: String) {
    logger.error(FlowLog(name: name, event: .completion(.failure(GenericError(reason: reason)))))
  }

  struct GenericError: Error {

    let reason: String

  }

}

struct FlowLog: LogConvertible, Encodable {

  let name: String
  let event: Event

  var logDescription: String {
    guard
      let data = try? JSONEncoder().encode(self),
      let string = String(data: data, encoding: .utf8)
    else {
      return "FLOW: \(name) ENCODING ERROR"
    }

    return "FLOW: \(string)"
  }

}

extension FlowLog {

  enum Event: Encodable {

    case start
    case checkpoint(description: String)
    case completion(Result<Void, Error>)

    func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()

      switch self {
      case .start:
        try container.encode("start")

      case .checkpoint(let description):
        try container.encode("checkpoint - \(description)")

      case .completion(.success):
        try container.encode("success")

      case .completion(.failure(let error)):
        try container.encode("failure - \(String(describing: error))")
      }
    }

  }

}
