import SwiftUI

/// View showing a list of product categories to select from.
///
struct ProductCategorySelector: View {
    @Binding private var isPresented: Bool
    @ObservedObject private var viewModel: ProductCategorySelectorViewModel

    private let config: Configuration

    private var doneButtonTitle: String {
        let itemsCount = viewModel.listViewModel.selectedCategories.count
        if itemsCount == 0 {
            return Localization.doneButton
        } else {
            return String.pluralize(
                itemsCount,
                singular: config.doneButtonSingularFormat,
                plural: config.doneButtonPluralFormat
            )
        }
    }

    init(isPresented: Binding<Bool>,
         config: Configuration,
         viewModel: ProductCategorySelectorViewModel) {
        self.viewModel = viewModel
        self.config = config
        self._isPresented = isPresented
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ProductCategoryList(viewModel: viewModel.listViewModel)
                Button(doneButtonTitle) {
                    viewModel.submitSelection()
                    isPresented = false
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Localization.cancelButton) {
                        isPresented.toggle()
                    }
                }
            }
            .navigationTitle(config.title)
            .navigationBarTitleDisplayMode(.large)
            .navigationViewStyle(.stack)
            .wooNavigationBarStyle()
        }
    }
}

extension ProductCategorySelector {
    struct Configuration {
        let title: String
        var doneButtonSingularFormat: String
        var doneButtonPluralFormat: String
    }
}

private extension ProductCategorySelector {
    enum Localization {
        static let doneButton = NSLocalizedString("Done", comment: "Button to submit selection on Select Categories screen")
        static let cancelButton = NSLocalizedString("Cancel", comment: "Button to dismiss Select Categories screen")
    }
}

struct ProductCategorySelector_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = ProductCategorySelectorViewModel(siteID: 123) { _ in }
        let config = ProductCategorySelector.Configuration(
            title: "Select Categories",
            doneButtonSingularFormat: "",
            doneButtonPluralFormat: ""
        )
        ProductCategorySelector(isPresented: .constant(true),
                                config: config,
                                viewModel: viewModel)
    }
}
