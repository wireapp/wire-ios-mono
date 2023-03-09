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
import CryptoKit

// Mapping of @c NSData helper methods to Swift 3 @c Data. See original methods for description.
public extension Data {

    init?(hexString: String) {
        guard let decodedData = hexString.zmHexDecodedData() else {
            return nil
        }
        self = decodedData
    }

    func zmMD5Digest() -> Data {
        var md5Hash = Insecure.MD5()

        // We may have a lot of data to hash, so compute in chunks of 512 bytes.
        for range in (startIndex..<endIndex).chunked(by: 512) {
            md5Hash.update(data: self[range])
        }

        let digest = md5Hash.finalize()
        return Data(digest)
    }

    func zmHMACSHA256Digest(key: Data) -> Data {
        return (self as NSData).zmHMACSHA256Digest(withKey: key)
    }

    func zmHexEncodedString() -> String {
        let hexDigits = Array("0123456789abcdef".utf16)
        var characters: [unichar] = []
        characters.reserveCapacity(count * 2)

        self.forEach { byte in
            characters.append(hexDigits[Int(byte / 16)])
            characters.append(hexDigits[Int(byte % 16)])
        }

        return String(utf16CodeUnits: characters, count: characters.count)
    }

    static func zmRandomSHA256Key() -> Data {
        return NSData.zmRandomSHA256Key()
    }

    func zmSHA256Digest() -> Data {
        return (self as NSData).zmSHA256Digest()
    }

    func base64String() -> String {
        return (self as NSData).base64String()
    }

    func zmEncryptPrefixingIV(key: Data) -> Data {
        return (self as NSData).zmEncryptPrefixingIV(withKey: key)
    }

    func zmDecryptPrefixedIV(key: Data) -> Data {
        return (self as NSData).zmDecryptPrefixedIV(withKey: key)
    }

    func zmEncryptPrefixingPlainTextIV(key: Data) -> Data {
        return (self as NSData).zmEncryptPrefixingPlainTextIV(withKey: key)
    }

    func zmDecryptPrefixedPlainTextIV(key: Data) -> Data? {
        return (self as NSData).zmDecryptPrefixedPlainTextIV(withKey: key)
    }

    static func secureRandomData(length: UInt) -> Data {
        return NSData.secureRandomData(ofLength: length)
    }

    static func randomEncryptionKey() -> Data {
        return NSData.randomEncryptionKey()
    }

}

private extension Range where Index == Int {

    func chunked(by chunkSize: Int) -> [Self] {
        guard chunkSize > 0 else { return [] }

        let numberOfWholeChunks = endIndex / chunkSize
        let numberOfChunks = endIndex.isMultiple(of: chunkSize) ? numberOfWholeChunks : numberOfWholeChunks + 1

        return (0..<numberOfChunks).map { chunkIndex in
            let start = chunkIndex * chunkSize
            let end = Swift.min(start + chunkSize, endIndex)
            return start..<end
        }
    }

}
