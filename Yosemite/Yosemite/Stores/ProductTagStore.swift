import Foundation
import Networking
import Storage

// MARK: - ProductTagStore
//
public final class ProductTagStore: Store {

    private lazy var sharedDerivedStorage: StorageType = {
        return storageManager.newDerivedStorage()
    }()

    /// Registers for supported Actions.
    ///
    override public func registerSupportedActions(in dispatcher: Dispatcher) {
        dispatcher.register(processor: self, for: ProductCategoryAction.self)
    }

    /// Receives and executes Actions.
    ///
    override public func onAction(_ action: Action) {
        guard let action = action as? ProductTagAction else {
            assertionFailure("ProductTagStore received an unsupported action")
            return
        }

        switch action {
        case let .synchronizeAllProductTags(siteID, fromPageNumber, onCompletion):
            synchronizeAllProductTags(siteID: siteID, fromPageNumber: fromPageNumber, onCompletion: onCompletion)
        case let .addProductTags(siteID, tags, onCompletion):
            addProductTags(siteID: siteID, tags: tags, onCompletion: onCompletion)
        case let .deleteProductTags(siteID, ids, onCompletion):
            deleteProductTags(siteID: siteID, ids: ids, onCompletion: onCompletion)
        }
    }
}

// MARK: - Services
//
private extension ProductTagStore {

    /// Synchronizes all product tags associated with a given Site ID, starting at a specific page number.
    ///
    func synchronizeAllProductTags(siteID: Int64, fromPageNumber: Int, onCompletion: @escaping (ProductTagActionError?) -> Void) {
        // Start fetching the provided initial page
        synchronizeProductTags(siteID: siteID, pageNumber: fromPageNumber, pageSize: Constants.defaultMaxPageSize) { [weak self] (productTags, error) in
            guard let self = self  else {
                return
            }

            // If there is an error, end the recursion and call `onCompletion` with an `error`
            if let error = error {
                let synchronizationError = ProductTagActionError.tagsSynchronization(pageNumber: fromPageNumber, rawError: error)
                onCompletion(synchronizationError)
                return
            }

            // If tags is nil, end the recursion and call `onCompletion`
            if productTags == nil {
                onCompletion(nil)
                return
            }

            // If tags is empty, end the recursion and call `onCompletion`
            if let productTags = productTags, productTags.isEmpty {
                onCompletion(nil)
                return
            }

            // Request the next page recursively
            self.synchronizeAllProductTags(siteID: siteID, fromPageNumber: fromPageNumber + 1, onCompletion: onCompletion)
        }
    }

    /// Synchronizes product tags associated with a given Site ID.
    ///
    func synchronizeProductTags(siteID: Int64, pageNumber: Int, pageSize: Int, onCompletion: @escaping ([ProductTag]?, Error?) -> Void) {
        let remote = ProductTagsRemote(network: network)

        remote.loadAllProductTags(for: siteID, pageNumber: pageNumber, pageSize: pageSize) { [weak self] (productTags, error) in

            guard let productTags = productTags else {
                onCompletion(nil, error)
                return
            }

            if pageNumber == Default.firstPageNumber {
                self?.deleteUnusedStoredProductTags(siteID: siteID)
            }

            self?.upsertStoredProductTagsInBackground(productTags, siteID: siteID) {
                onCompletion(productTags, nil)
            }
        }
    }

    /// Create new product tags associated with a given Site ID.
    ///
    func addProductTags(siteID: Int64, tags: [String], onCompletion: @escaping (Result<[ProductTag], Error>) -> Void) {
        let remote = ProductTagsRemote(network: network)

        remote.createProductTags(for: siteID, names: tags) { [weak self] (result) in
            switch result {
            case .success(let productTags):
                self?.upsertStoredProductTagsInBackground(productTags, siteID: siteID) {
                    onCompletion(.success(productTags))
                }
            case .failure(let error):
                onCompletion(.failure(error))
            }
        }
    }

    /// Delete product tags associated with a given Site ID.
    ///
    func deleteProductTags(siteID: Int64, ids: [Int64], onCompletion: @escaping (Result<[ProductTag], Error>) -> Void) {
        let remote = ProductTagsRemote(network: network)

        remote.deleteProductTags(for: siteID, ids: ids) { [weak self] (result) in
            switch result {
            case .success(let productTags):
                self?.deleteStoredProductTags(siteID: siteID, ids: ids)
                onCompletion(.success(productTags))
            case .failure(let error):
                onCompletion(.failure(error))
            }
        }
    }
}

// MARK: - Storage: ProductTag
//
private extension ProductTagStore {
    /// Updates (OR Inserts) the specified ReadOnly ProductTag Entities *in a background thread*.
    /// onCompletion will be called on the main thread!
    ///
    func upsertStoredProductTagsInBackground(_ readOnlyProductTags: [Networking.ProductTag],
                                                   siteID: Int64,
                                                   onCompletion: @escaping () -> Void) {
        let derivedStorage = sharedDerivedStorage
        derivedStorage.perform { [weak self] in
            self?.upsertStoredProductTags(readOnlyProductTags, in: derivedStorage, siteID: siteID)
        }

        storageManager.saveDerivedType(derivedStorage: derivedStorage) {
            DispatchQueue.main.async(execute: onCompletion)
        }
    }

    /// Deletes any Storage.ProductTag  that is not associated to a product on the specified `siteID`
    ///
    func deleteUnusedStoredProductTags(siteID: Int64) {
        let storage = storageManager.viewStorage
        storage.deleteUnusedProductTags(siteID: siteID)
        storage.saveIfNeeded()
    }

    /// Deletes any Storage.ProductTag with the specified `siteID` and `productID`
    ///
    func deleteStoredProductTags(siteID: Int64, ids: [Int64]) {
        let storage = storageManager.viewStorage
        storage.deleteProductTags(siteID: siteID, ids: ids)
        storage.saveIfNeeded()
    }

}

private extension ProductTagStore {
    /// Updates (OR Inserts) the specified ReadOnly ProductTag entities into the Storage Layer.
    ///
    /// - Parameters:
    ///     - readOnlyProductTags: Remote ProductTags to be persisted.
    ///     - storage: Where we should save all the things!
    ///     - siteID: site ID for looking up the ProductTag.
    ///
    func upsertStoredProductTags(_ readOnlyProductTags: [Networking.ProductTag],
                                       in storage: StorageType,
                                       siteID: Int64) {
        // Upserts the ProductTag models from the read-only version
        for readOnlyProductTag in readOnlyProductTags {
            let storageProductTag: Storage.ProductTag = {
                if let storedTag = storage.loadProductTag(siteID: siteID, tagID: readOnlyProductTag.tagID) {
                    return storedTag
                }
                return storage.insertNewObject(ofType: Storage.ProductTag.self)
            }()
            storageProductTag.update(with: readOnlyProductTag)
        }
    }
}

// MARK: - Constant
//
private extension ProductTagStore {
    enum Constants {
        /// Max number allowed by the API to maximize our changes on getting all item in one request.
        ///
        static let defaultMaxPageSize = 100
    }
}
