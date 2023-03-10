//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
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

import WireCommonComponents
import UIKit

final class ConversationCreateOptionsCell: RightIconDetailsCell {

    // MARK: - Properties
    var expanded = false

    // MARK: - Override Properties for Accessibility
    override var accessibilityLabel: String? {
        get {
            return title
        }

        set {
            super.accessibilityLabel = newValue
        }
    }

    override var accessibilityValue: String? {
        get {
            return status
        }

        set {
            super.accessibilityValue = newValue
        }
    }

    override var accessibilityHint: String? {
        get {
            typealias CreateConversation = L10n.Accessibility.CreateConversation
            return expanded ? CreateConversation.HideSettings.hint : CreateConversation.OpenSettings.hint
        }

        set {
            super.accessibilityHint = newValue
        }
    }

    // MARK: - Overrides
    override func setUp() {
        super.setUp()
        title = L10n.Localizable.Conversation.Create.Options.title
        icon = nil
        showSeparator = false
        contentLeadingOffset = 16
        setupIcon()
        setupAccessibility()
    }

    // MARK: Methods
    /// Sets up the icon and its color.
    private func setupIcon() {
        let color = SemanticColors.Icon.foregroundPlainDownArrow
        let image = StyleKitIcon.downArrow.makeImage(
            size: .tiny,
            color: color).withRenderingMode(.alwaysTemplate)

        // flip upside down if necessary
        if let cgImage = image.cgImage, expanded {
            accessory = UIImage(
                cgImage: cgImage,
                scale: image.scale,
                orientation: .downMirrored).withRenderingMode(.alwaysTemplate)
        } else {
            accessory = image
        }
        accessoryColor = color
    }

    private func setupAccessibility() {
        accessibilityIdentifier = "cell.groupdetails.options"
        isAccessibilityElement = true
        accessibilityTraits = .button
    }
}

// MARK: - ConversationCreateOptionsCell Extension
extension ConversationCreateOptionsCell: ConversationCreationValuesConfigurable {
    func configure(with values: ConversationCreationValues) {
        let guests = values.allowGuests.localized.capitalized
        let services = values.allowServices.localized.capitalized
        let receipts = values.enableReceipts.localized.capitalized
        status = L10n.Localizable.Conversation.Create.Options.subtitle(guests, services, receipts)
    }
}

private extension Bool {
    var localized: String {
        return self ? L10n.Localizable.General.on : L10n.Localizable.General.off
    }
}
