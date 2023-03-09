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

import UIKit
import WireCommonComponents

final class CheckmarkCell: RightIconDetailsCell {

    // MARK: - Properties
    typealias BackgroundColors = SemanticColors.View

    var showCheckmark: Bool = false {
        didSet {
            updateCheckmark()

            titleBolded = showCheckmark
        }
    }

    // MARK: - Override methods
    override var disabled: Bool {
        didSet {
            updateCheckmark()
        }
    }

    override func setUp() {
        super.setUp()
        icon = nil
        status = nil

        isAccessibilityElement = true
        shouldGroupAccessibilityChildren = true
        accessibilityTraits = .button
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle else { return }
        updateCheckmark()
    }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted
            ? BackgroundColors.backgroundUserCellHightLighted
            : BackgroundColors.backgroundUserCell
        }
    }

    // MARK: - Setup Checkmark
    /// Updates the color of the checkmark based on the state of the cell
    private func updateCheckmark() {

        guard showCheckmark else {
            accessory = nil
            return
        }

        let color: UIColor

        if disabled {
            color = SemanticColors.Icon.foregroundPlaceholder
        } else {
            color = SemanticColors.Icon.foregroundPlainCheckMark
        }

        accessory = StyleKitIcon.checkmark.makeImage(size: .tiny,
                                                     color: color).withRenderingMode(.alwaysTemplate)
        accessoryColor = color
    }

    // MARK: - accessibility
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
            return showCheckmark ? L10n.Accessibility.ConversationDetails.MessageTimeoutState.description : nil
        }

        set {
            super.accessibilityValue = newValue
        }
    }
}
