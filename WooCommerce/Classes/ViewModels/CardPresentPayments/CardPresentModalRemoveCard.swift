import UIKit

final class CardPresentModalRemoveCard: CardPresentPaymentsModalViewModel {
    private let name: String
    private let amount: String

    var topTitle: String {
        name
    }

    var topSubtitle: String {
        amount
    }

    let image: UIImage = .cardPresentImage

    let areButtonsVisible: Bool = false

    let primaryButtonTitle: String = ""

    let secondaryButtonTitle: String = ""

    let isAuxiliaryButtonHidden: Bool = true

    let auxiliaryButtonTitle: String = ""

    let bottomTitle: String = Localization.removeCard

    let bottomSubtitle: String = ""

    init(name: String, amount: String) {
        self.name = name
        self.amount = amount
    }

    func didTapPrimaryButton(in viewController: UIViewController?) {
        //
    }

    func didTapSecondaryButton(in viewController: UIViewController?) {
        //
    }

    func didTapAuxiliaryButton(in viewController: UIViewController?) {
        //
    }
}

private extension CardPresentModalRemoveCard {
    enum Localization {
        static let removeCard = NSLocalizedString(
            "Please remove card",
            comment: "Label asking users to remove card. Presented to users when a payment is in the process of being collected"
        )
    }
}
