@testable import WooCommerce
import Combine
import Photos
import XCTest
import Yosemite

final class ProductImageUploaderTests: XCTestCase {
    private let siteID: Int64 = 134
    private let productID: Int64 = 606
    private var errorsSubscription: AnyCancellable?

    func test_hasUnsavedChangesOnImages_becomes_false_after_uploading_and_saving() throws {
        // Given
        let imageUploader = ProductImageUploader()
        let actionHandler = imageUploader.actionHandler(siteID: siteID, productID: productID, isLocalID: false, originalStatuses: [])
        let asset = PHAsset()

        XCTAssertFalse(imageUploader.hasUnsavedChangesOnImages(siteID: siteID, productID: productID, isLocalID: false, originalImages: []))

        // When
        actionHandler.uploadMediaAssetToSiteMediaLibrary(asset: asset)
        let statuses = waitFor { promise in
            actionHandler.addUpdateObserver(self) { statuses in
                promise(statuses)
            }
        }
        XCTAssertTrue(statuses.productImageStatuses.hasPendingUpload)
        XCTAssertTrue(imageUploader.hasUnsavedChangesOnImages(siteID: siteID, productID: productID, isLocalID: false, originalImages: []))
        imageUploader.saveProductImagesWhenNoneIsPendingUploadAnymore(siteID: siteID, productID: productID, isLocalID: false) { _ in }

        // Then
        XCTAssertFalse(imageUploader.hasUnsavedChangesOnImages(siteID: siteID, productID: productID, isLocalID: false, originalImages: []))
    }

    func test_hasUnsavedChangesOnImages_stays_false_after_uploading_and_saving_successfully() throws {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let imageUploader = ProductImageUploader(stores: stores)
        let actionHandler = imageUploader.actionHandler(siteID: siteID, productID: productID, isLocalID: false, originalStatuses: [])
        let asset = PHAsset()

        let uploadedMedia = Media.fake().copy(mediaID: 645)
        stores.whenReceivingAction(ofType: MediaAction.self) { action in
            if case let .uploadMedia(_, _, _, onCompletion) = action {
                onCompletion(.success(uploadedMedia))
            }
        }
        stores.whenReceivingAction(ofType: ProductAction.self) { action in
            if case let .updateProductImages(_, _, images, onCompletion) = action {
                onCompletion(.success(.fake().copy(images: images)))
            }
        }

        XCTAssertFalse(imageUploader.hasUnsavedChangesOnImages(siteID: siteID, productID: productID, isLocalID: false, originalImages: []))

        // When
        actionHandler.uploadMediaAssetToSiteMediaLibrary(asset: asset)
        let statuses = waitFor { promise in
            actionHandler.addUpdateObserver(self) { statuses in
                promise(statuses)
            }
        }
        XCTAssertTrue(statuses.productImageStatuses.hasPendingUpload)
        XCTAssertTrue(imageUploader.hasUnsavedChangesOnImages(siteID: siteID, productID: productID, isLocalID: false, originalImages: []))
        let resultOfSavedImages = waitFor { promise in
            imageUploader.saveProductImagesWhenNoneIsPendingUploadAnymore(siteID: self.siteID, productID: self.productID, isLocalID: false) { result in
                promise(result)
            }
        }

        // Then
        XCTAssertFalse(imageUploader.hasUnsavedChangesOnImages(siteID: siteID,
                                                               productID: productID,
                                                               isLocalID: false,
                                                               originalImages: [.fake().copy(imageID: 645)]))
        XCTAssertTrue(resultOfSavedImages.isSuccess)
        let images = try XCTUnwrap(resultOfSavedImages.get())
        XCTAssertEqual(images.map { $0.imageID }, [uploadedMedia.mediaID])
    }

    func test_when_saving_product_twice_the_latest_images_are_saved() throws {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let imageUploader = ProductImageUploader(stores: stores)
        let actionHandler = imageUploader.actionHandler(siteID: siteID, productID: productID, isLocalID: false, originalStatuses: [])
        let asset = PHAsset()

        stores.whenReceivingAction(ofType: ProductAction.self) { action in
            if case let .updateProductImages(_, _, images, onCompletion) = action {
                onCompletion(.success(.fake().copy(images: images)))
            }
        }

        XCTAssertFalse(imageUploader.hasUnsavedChangesOnImages(siteID: siteID, productID: productID, isLocalID: false, originalImages: []))

        // When
        // Uploads an image and waits for the image upload completion closure to be called later.
        let imageUploadCompletion: ((Result<Media, Error>) -> Void) = waitFor { promise in
            stores.whenReceivingAction(ofType: MediaAction.self) { action in
                if case let .uploadMedia(_, _, _, onCompletion) = action {
                    promise(onCompletion)
                }
            }
            actionHandler.uploadMediaAssetToSiteMediaLibrary(asset: asset)
        }

        XCTAssertTrue(imageUploader.hasUnsavedChangesOnImages(siteID: siteID, productID: productID, isLocalID: false, originalImages: []))

        // The first save.
        imageUploader.saveProductImagesWhenNoneIsPendingUploadAnymore(siteID: self.siteID, productID: self.productID, isLocalID: false) { result in
            XCTFail("The product save callback should not be triggered after another save request.")
        }

        // Adds a remote image.
        actionHandler.addSiteMediaLibraryImagesToProduct(mediaItems: [.fake().copy(mediaID: 606)])
        waitFor { promise in
            actionHandler.addUpdateObserver(self) { statuses in
                promise(())
            }
        }

        let resultOfSavedImages: Result<[ProductImage], Error> = waitFor { promise in
            // The second save.
            imageUploader.saveProductImagesWhenNoneIsPendingUploadAnymore(siteID: self.siteID, productID: self.productID, isLocalID: false) { result in
                promise(result)
            }
            // Triggers success from image upload.
            imageUploadCompletion(.success(.fake().copy(mediaID: 645)))
        }

        // Then
        XCTAssertFalse(imageUploader.hasUnsavedChangesOnImages(siteID: siteID,
                                                               productID: productID,
                                                               isLocalID: false,
                                                               originalImages: [.fake().copy(imageID: 606), .fake().copy(imageID: 645)]))
        XCTAssertTrue(resultOfSavedImages.isSuccess)
        let images = try XCTUnwrap(resultOfSavedImages.get())
        XCTAssertEqual(images.map { $0.imageID }, [606, 645])
    }

    func test_replaceLocalID_replaces_productID_properly() {
        // Given
        let imageUploader = ProductImageUploader()
        let localProductID: Int64 = 0
        let remoteProductID = productID
        let originalStatuses: [ProductImageStatus] = [.remote(image: ProductImage.fake()),
                                                      .uploading(asset: PHAsset()),
                                                      .uploading(asset: PHAsset())]
        _ = imageUploader.actionHandler(siteID: siteID,
                                        productID: localProductID,
                                        isLocalID: true,
                                        originalStatuses: originalStatuses)

        // Before replacing product ID

        // Pass empty statuses to get the `actionHandler`, and validate that `actionHandler` with `originalStatuses` is returned.
        XCTAssertEqual(originalStatuses, imageUploader.actionHandler(siteID: siteID,
                                                                     productID: localProductID,
                                                                     isLocalID: true,
                                                                     originalStatuses: []).productImageStatuses)

        // When
        imageUploader.replaceLocalID(siteID: siteID, localProductID: localProductID, remoteProductID: remoteProductID)

        // After replacing local product ID with remote product ID

        // Pass empty statuses and `remoteProductID` to get the `actionHandler`, and validate that `actionHandler` with `originalStatuses` is returned.
        XCTAssertEqual(originalStatuses, imageUploader.actionHandler(siteID: siteID,
                                                                     productID: remoteProductID,
                                                                     isLocalID: false,
                                                                     originalStatuses: []).productImageStatuses)
    }

    func test_calling_replaceLocalID_with_nonExistent_localProductID_does_nothing() {
        // Given
        let imageUploader = ProductImageUploader()
        let localProductID: Int64 = 0
        let nonExistentProductID: Int64 = 999
        let remoteProductID = productID
        let originalStatuses: [ProductImageStatus] = [.remote(image: ProductImage.fake()),
                                                      .uploading(asset: PHAsset()),
                                                      .uploading(asset: PHAsset())]
        _ = imageUploader.actionHandler(siteID: siteID,
                                        productID: localProductID,
                                        isLocalID: true,
                                        originalStatuses: originalStatuses)

        // When
        imageUploader.replaceLocalID(siteID: siteID, localProductID: nonExistentProductID, remoteProductID: remoteProductID)

        // Then
        // Ensure that trying to replace a non-existent product ID does nothing.
        XCTAssertEqual(originalStatuses, imageUploader.actionHandler(siteID: siteID,
                                                                     productID: localProductID,
                                                                     isLocalID: true,
                                                                     originalStatuses: []).productImageStatuses)
    }

    // MARK: - Status Updates

    func test_update_is_emitted_when_image_upload_fails() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let imageUploader = ProductImageUploader(stores: stores)
        let actionHandler = imageUploader.actionHandler(siteID: siteID,
                                                        productID: productID,
                                                        isLocalID: true,
                                                        originalStatuses: [])
        let error = NSError(domain: "", code: 6)
        stores.whenReceivingAction(ofType: MediaAction.self) { action in
            if case let .uploadMedia(_, _, _, onCompletion) = action {
                onCompletion(.failure(error))
            }
        }

        // When
        var updates: [ProductImageUploadError] = []
        let _: Void = waitFor { promise in
            self.errorsSubscription = imageUploader.errors.sink { update in
                updates.append(update)
                promise(())
            }
            actionHandler.uploadMediaAssetToSiteMediaLibrary(asset: PHAsset())
        }

        // Then
        assertEqual([.init(siteID: siteID, productID: productID, productImageStatuses: [], error: error)], updates)
    }

    func test_updates_are_not_emitted_when_image_upload_succeeds() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let imageUploader = ProductImageUploader(stores: stores)
        let actionHandler = imageUploader.actionHandler(siteID: siteID,
                                                        productID: productID,
                                                        isLocalID: true,
                                                        originalStatuses: [])
        stores.whenReceivingAction(ofType: MediaAction.self) { action in
            if case let .uploadMedia(_, _, _, onCompletion) = action {
                onCompletion(.success(.fake()))
            }
        }

        // When
        var updates: [ProductImageUploadError] = []
        errorsSubscription = imageUploader.errors.sink { update in
            updates.append(update)
            XCTFail("Image upload update should be emitted: \(update)")
        }
        actionHandler.uploadMediaAssetToSiteMediaLibrary(asset: PHAsset())

        // Then
        XCTAssertTrue(updates.isEmpty)
    }

    // MARK: - `stopEmittingErrors`

    func test_update_is_emitted_after_stopEmittingErrors_with_a_different_product_when_image_upload_fails() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let imageUploader = ProductImageUploader(stores: stores)
        let actionHandler = imageUploader.actionHandler(siteID: siteID,
                                                        productID: productID,
                                                        isLocalID: true,
                                                        originalStatuses: [])
        let error = NSError(domain: "", code: 6)
        stores.whenReceivingAction(ofType: MediaAction.self) { action in
            if case let .uploadMedia(_, _, _, onCompletion) = action {
                onCompletion(.failure(error))
            }
        }

        // When
        imageUploader.stopEmittingErrors(siteID: siteID, productID: 9999, isLocalID: true)

        var updates: [ProductImageUploadError] = []
        let _: Void = waitFor { promise in
            self.errorsSubscription = imageUploader.errors.sink { update in
                updates.append(update)
                promise(())
            }
            actionHandler.uploadMediaAssetToSiteMediaLibrary(asset: PHAsset())
        }

        // Then
        assertEqual([.init(siteID: siteID, productID: productID, productImageStatuses: [], error: error)], updates)
    }

    func test_update_is_not_emitted_after_stopEmittingErrors_when_image_upload_fails() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let imageUploader = ProductImageUploader(stores: stores)
        let actionHandler = imageUploader.actionHandler(siteID: siteID,
                                                        productID: productID,
                                                        isLocalID: true,
                                                        originalStatuses: [])
        let error = NSError(domain: "", code: 6)
        stores.whenReceivingAction(ofType: MediaAction.self) { action in
            if case let .uploadMedia(_, _, _, onCompletion) = action {
                onCompletion(.failure(error))
            }
        }

        // When
        imageUploader.stopEmittingErrors(siteID: siteID, productID: productID, isLocalID: true)

        var updates: [ProductImageUploadError] = []
        errorsSubscription = imageUploader.errors.sink { update in
            updates.append(update)
            XCTFail("Image upload update should be emitted: \(update)")
        }
        actionHandler.uploadMediaAssetToSiteMediaLibrary(asset: PHAsset())

        // Then
        XCTAssertTrue(updates.isEmpty)
    }

    func test_calling_replaceLocalID_updates_excluded_product_from_status_updates() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let imageUploader = ProductImageUploader(stores: stores)
        let localProductID: Int64 = 0
        let nonExistentProductID: Int64 = 999
        let remoteProductID = productID
        let actionHandler = imageUploader.actionHandler(siteID: siteID,
                                                        productID: localProductID,
                                                        isLocalID: true,
                                                        originalStatuses: [])

        // When
        imageUploader.stopEmittingErrors(siteID: siteID, productID: localProductID, isLocalID: true)
        imageUploader.replaceLocalID(siteID: siteID, localProductID: nonExistentProductID, remoteProductID: remoteProductID)

        var updates: [ProductImageUploadError] = []
        _ = imageUploader.errors.sink { update in
            updates.append(update)
        }

        stores.whenReceivingAction(ofType: MediaAction.self) { action in
            if case let .uploadMedia(_, _, _, onCompletion) = action {
                onCompletion(.failure(MediaActionError.unknown))
            }
        }
        actionHandler.uploadMediaAssetToSiteMediaLibrary(asset: PHAsset())

        // Then
        // Ensure that trying to replace a non-existent product ID does nothing.
        XCTAssertTrue(updates.isEmpty)
    }

    // MARK: - `startEmittingErrors`

    func test_update_is_emitted_after_stop_and_startEmittingErrors_when_image_upload_fails() {
        // Given
        let stores = MockStoresManager(sessionManager: .testingInstance)
        let imageUploader = ProductImageUploader(stores: stores)
        let actionHandler = imageUploader.actionHandler(siteID: siteID,
                                                        productID: productID,
                                                        isLocalID: true,
                                                        originalStatuses: [])
        let error = NSError(domain: "", code: 6)
        stores.whenReceivingAction(ofType: MediaAction.self) { action in
            if case let .uploadMedia(_, _, _, onCompletion) = action {
                onCompletion(.failure(error))
            }
        }

        // When
        imageUploader.stopEmittingErrors(siteID: siteID, productID: productID, isLocalID: true)
        imageUploader.startEmittingErrors(siteID: siteID, productID: productID, isLocalID: true)

        var updates: [ProductImageUploadError] = []
        let _: Void = waitFor { promise in
            self.errorsSubscription = imageUploader.errors.sink { update in
                updates.append(update)
                promise(())
            }
            actionHandler.uploadMediaAssetToSiteMediaLibrary(asset: PHAsset())
        }

        // Then
        assertEqual([.init(siteID: siteID, productID: productID, productImageStatuses: [], error: error)], updates)
    }
}

extension ProductImageUploadError: Equatable {
    public static func == (lhs: ProductImageUploadError, rhs: ProductImageUploadError) -> Bool {
        return lhs.siteID == rhs.siteID &&
        lhs.productID == rhs.productID &&
        lhs.productImageStatuses == rhs.productImageStatuses &&
        (lhs.error as NSError) == (rhs.error as NSError)
    }
}
