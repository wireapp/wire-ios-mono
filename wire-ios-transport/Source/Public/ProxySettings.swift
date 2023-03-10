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

final class ProxySettings: NSObject, ProxySettingsProvider, Codable {

    let host: String
    let port: Int
    let needsAuthentication: Bool

    init(host: String,
         port: Int,
         needsAuthentication: Bool = false) {
        self.host = host
        self.port = port
        self.needsAuthentication = needsAuthentication

        super.init()
    }

    func socks5Settings(proxyUsername: String?, proxyPassword: String?) -> [AnyHashable: Any]? {
        var proxyDictionary: [AnyHashable: Any] = [
            "SOCKSEnable": 1,
            "SOCKSProxy": host,
            "SOCKSPort": port,
            kCFProxyTypeKey: kCFProxyTypeSOCKS,
            kCFStreamPropertySOCKSVersion: kCFStreamSocketSOCKSVersion5
        ]

        if let username = proxyUsername, let password = proxyPassword, needsAuthentication {
            proxyDictionary[kCFStreamPropertySOCKSUser] = username
            proxyDictionary[kCFStreamPropertySOCKSPassword] = password
        }
        return proxyDictionary
    }
}
