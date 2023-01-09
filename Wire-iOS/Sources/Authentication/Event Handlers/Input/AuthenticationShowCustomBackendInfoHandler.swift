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
import WireTransport

/**
 * Handles showing custom backend information
 */
final class AuthenticationShowCustomBackendInfoHandler: AuthenticationEventHandler {
    enum Intent {
        case showCustomBackendInfo
    }

    weak var statusProvider: AuthenticationStatusProvider?

    func handleEvent(currentStep: AuthenticationFlowStep, context: Any) -> [AuthenticationCoordinatorAction]? {
        guard (context as? Intent) == .showCustomBackendInfo else {
            return nil
        }

        let env = BackendEnvironment.shared

        let info = [
            L10n.Localizable.Landing.CustomBackend.Alert.Message.backendName,
            env.title,
            L10n.Localizable.Landing.CustomBackend.Alert.Message.backendUrl,
            env.backendURL.absoluteString
        ].joined(separator: "\n")

        return [.presentAlert(.init(title: L10n.Localizable.Landing.CustomBackend.Alert.title,
                                    message: info,
                                    actions: [.ok]))]
    }

}
