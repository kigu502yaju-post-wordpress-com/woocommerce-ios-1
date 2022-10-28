// Generated using Sourcery 1.0.3 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

import Yosemite
import Networking
import Hardware

extension ProductReviewFromNoteParcel {
    /// Returns a "ready to use" type filled with fake values.
    ///
    public static func fake() -> ProductReviewFromNoteParcel {
        .init(
            note: .fake(),
            review: .fake(),
            product: .fake()
        )
    }
}
extension YosemiteJustInTimeMessage {
    /// Returns a "ready to use" type filled with fake values.
    ///
    public static func fake() -> YosemiteJustInTimeMessage {
        .init(
            siteID: .fake(),
            messageID: .fake(),
            featureClass: .fake(),
            title: .fake(),
            detail: .fake(),
            buttonTitle: .fake(),
            url: .fake()
        )
    }
}
