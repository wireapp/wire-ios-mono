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

public final class ProxyCredentials: NSObject {
    public var username: String
    public var password: String
    public var proxy: ProxySettingsProvider

    init(proxy: ProxySettingsProvider, username: String, password: String) {
        self.username = username
        self.password = password
        self.proxy = proxy
    }

    @objc(initWithUsername:password:forProxy:)
    public convenience init?(username: String?, password: String?, proxy: ProxySettingsProvider) {
        guard let username = username, let password = password else {
            return nil
        }
        self.init(proxy: proxy, username: username, password: password)
    }

    public func persist() throws {
        guard
            let usernameData = username.data(using: .utf8),
            let passwordData = password.data(using: .utf8)
        else { return }

        try? Keychain.deleteItem(.usernameItem(for: proxy))
        try? Keychain.deleteItem(.passwordItem(for: proxy))

        try Keychain.storeItem(.usernameItem(for: proxy), value: usernameData)
        try Keychain.storeItem(.passwordItem(for: proxy), value: passwordData)
    }

    public static func retrieve(for proxy: ProxySettingsProvider) -> ProxyCredentials? {
        do {
            let usernameData = try Keychain.fetchItem(.usernameItem(for: proxy))
            let passwordData = try Keychain.fetchItem(.passwordItem(for: proxy))

            let username = String(data: usernameData, encoding: .utf8)
            let password = String(data: passwordData, encoding: .utf8)
            return ProxyCredentials(username: username,
                                    password: password,
                                    proxy: proxy)
        } catch {
            return nil
        }
    }

    public static func destroy(for proxy: ProxySettingsProvider) -> Bool {
        do {
            try Keychain.deleteItem(.usernameItem(for: proxy))
            try Keychain.deleteItem(.passwordItem(for: proxy))
        } catch {
            Logging.backendEnvironment.error(error.localizedDescription)
            return false
        }
        return true
    }
}

struct GenericPasswordKeychainItem: KeychainItem {

    // MARK: - Properties

    private let itemIdentifier: String

    // MARK: - Life cycle

    init(itemIdentifier: String) {
        self.itemIdentifier = itemIdentifier
    }

    // MARK: - Methods

    var queryForGettingValue: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: itemIdentifier,
            kSecReturnData: true
        ]
    }

    func queryForSetting(value: Data) -> [CFString: Any] {
        return [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: itemIdentifier,
            kSecValueData: value
        ]
    }
}

private extension KeychainItem where Self == GenericPasswordKeychainItem {
    static func usernameItem(for proxy: ProxySettingsProvider) -> GenericPasswordKeychainItem {
        GenericPasswordKeychainItem(itemIdentifier: "proxy-\(proxy.host):\(proxy.port)-username")
    }

    static func passwordItem(for proxy: ProxySettingsProvider) -> GenericPasswordKeychainItem {
        GenericPasswordKeychainItem(itemIdentifier: "proxy-\(proxy.host):\(proxy.port)-password")
    }
}
