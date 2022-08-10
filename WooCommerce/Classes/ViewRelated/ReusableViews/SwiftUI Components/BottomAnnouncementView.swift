import SwiftUI

struct BottomAnnouncementView: View {
    @Environment(\.presentationMode) private var presentation
    var completionHandler: (() -> Void)?

    var body: some View {
        GeometryReader { geo in
            VStack {
                Text(Localization.title)
                Text(Localization.message)
                Button(Localization.okButton) {
                    if let completionHandler = completionHandler {
                        completionHandler()
                    }
                    presentation.wrappedValue.dismiss()
                }
            }
        }
    }
}

extension BottomAnnouncementView {
    enum Localization {
        static let title = NSLocalizedString("Payments from the Menu tab", comment: "Text comment")
        static let message = NSLocalizedString("Now you can quickly access In-Person Payments and other features with ease.", comment: "Comment")
        static let okButton = NSLocalizedString("Got it!", comment: "comment")
    }
}
