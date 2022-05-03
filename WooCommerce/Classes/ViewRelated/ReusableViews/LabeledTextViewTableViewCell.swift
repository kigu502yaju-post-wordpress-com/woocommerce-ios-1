import UIKit
import Yosemite
/// A table view cell that contains a label and a text view.
///
final class LabeledTextViewTableViewCell: UITableViewCell {
    struct ViewModel {
        var text: String? = nil
        var productStatus: ProductStatus
        var placeholder: String? = nil
        var textViewMinimumHeight: CGFloat? = nil
        var isScrollEnabled: Bool = true
        var keyboardType: UIKeyboardType = .default
        var onNameChange: ((_ text: String) -> Void)? = nil
        var onTextDidBeginEditing: (() -> Void)? = nil
        var style: Style = .headline

    }
    @IBOutlet weak var productLabelHolder: UIView!
    @IBOutlet weak var productStatusLabel: UILabel!
    @IBOutlet var productTextField: EnhancedTextView!

    override func awakeFromNib() {
        super.awakeFromNib()
        configureLabelStyle()
        configureBackground()
    }

    func configure(with viewModel: ViewModel) {
        productTextField.text = viewModel.text
        productTextField.placeholder = viewModel.placeholder
        productTextField.isScrollEnabled = viewModel.isScrollEnabled
        productTextField.onTextChange = viewModel.onNameChange
        productTextField.onTextDidBeginEditing = viewModel.onTextDidBeginEditing
        productTextField.keyboardType = viewModel.keyboardType
        configureProductStatusLabel(productStatus: viewModel.productStatus)
        applyStyle(style: viewModel.style)
    }
}

private extension LabeledTextViewTableViewCell {

    func configureBackground() {
        backgroundColor = .systemColor(.secondarySystemGroupedBackground)
        productTextField.backgroundColor = .systemColor(.secondarySystemGroupedBackground)
    }

    func configureLabelStyle() {
        productStatusLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        productStatusLabel.textAlignment = .center
        productStatusLabel.textColor = BadgeStyle.Colors.textColor
        productLabelHolder.backgroundColor = BadgeStyle.Colors.defaultBg
        productLabelHolder.layer.cornerRadius = BadgeStyle.cornerRadius
    }

    func configureProductStatusLabel(productStatus: ProductStatus) {
        productStatusLabel.text = productStatus.description
        productLabelHolder.backgroundColor = productStatus == .pending ? BadgeStyle.Colors.pendingBg : BadgeStyle.Colors.defaultBg
        productLabelHolder.isHidden = productStatus == .published
    }

    enum BadgeStyle {
        static let cornerRadius: CGFloat = 4

        enum Colors {
            static let textColor: UIColor = .black
            static let defaultBg: UIColor = .gray(.shade5)
            static let pendingBg: UIColor = .withColorStudio(.orange, shade: .shade10)
        }
    }
}

// Styles
extension LabeledTextViewTableViewCell {

    enum Style {
        case body
        case headline
    }

    func applyStyle(style: Style) {
        switch style {
        case .body:
            productTextField.adjustsFontForContentSizeCategory = true
            productTextField.font = .body
            productTextField.textColor = .text
        case .headline:
            productTextField.adjustsFontForContentSizeCategory = true
            productTextField.font = .headline
            productTextField.textColor = .text
        }
    }
}
