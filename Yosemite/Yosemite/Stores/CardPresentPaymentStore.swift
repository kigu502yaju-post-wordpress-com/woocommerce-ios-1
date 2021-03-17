import Storage
import Hardware
import Networking
import Combine

/// MARK: CardPresentPaymentStore
///
public final class CardPresentPaymentStore: Store {
    // Retaining the reference to the card reader service might end up being problematic.
    // At this point though, the ServiceLocator is part of the WooCommerce binary, so this is a good starting point.
    // If retaining the service here ended up being a problem, we would need to move this Store out of Yosemite and push it up to WooCommerce.
    private let cardReaderService: CardReaderService

    private let remote: WCPayRemote

    private var cancellables: Set<AnyCancellable> = []

    public init(dispatcher: Dispatcher, storageManager: StorageManagerType, network: Network, cardReaderService: CardReaderService) {
        self.cardReaderService = cardReaderService
        self.remote = WCPayRemote(network: network)
        super.init(dispatcher: dispatcher, storageManager: storageManager, network: network)
    }

    /// Registers for supported Actions.
    ///
    override public func registerSupportedActions(in dispatcher: Dispatcher) {
        dispatcher.register(processor: self, for: CardPresentPaymentAction.self)
    }

    /// Receives and executes Actions.
    ///
    override public func onAction(_ action: Action) {
        guard let action = action as? CardPresentPaymentAction else {
            assertionFailure("\(String(describing: self)) received an unsupported action")
            return
        }

        switch action {
        case .startCardReaderDiscovery(let siteID, let completion):
            startCardReaderDiscovery(siteID: siteID, completion: completion)
        case .cancelCardReaderDiscovery(let completion):
            cancelCardReaderDiscovery(completion: completion)
        case .connect(let reader, let completion):
            connect(reader: reader, onCompletion: completion)
        case .collectPayment(let siteID, let orderID, let parameters, let completion):
            collectPayment(siteID: siteID,
                           orderID: orderID,
                           parameters: parameters,
                           onCompletion: completion)
        }
    }
}


// MARK: - Services
//
private extension CardPresentPaymentStore {
    func startCardReaderDiscovery(siteID: Int64, completion: @escaping (_ readers: [CardReader]) -> Void) {
        cardReaderService.start(WCPayTokenProvider(siteID: siteID, remote: self.remote))

        // Over simplification. This is the point where we would receive
        // new data via the CardReaderService's stream of discovered readers
        // In here, we should redirect that data to Storage and also up to the UI.
        // For now we are sending the data up to the UI directly
        print("**** Store. starting discovery*")
        cardReaderService.discoveredReaders.sink { readers in
            completion(readers)
        }.store(in: &cancellables)
    }

    func cancelCardReaderDiscovery(completion: @escaping (CardReaderServiceDiscoveryStatus) -> Void) {
        print("**** Store. cancelling discovery*")
        cardReaderService.discoveryStatus.sink { status in
            print("///// status received ", status)
            completion(status)
        }.store(in: &cancellables)

        cardReaderService.cancelDiscovery()
    }

    func connect(reader: Yosemite.CardReader, onCompletion: @escaping (Result<[Yosemite.CardReader], Error>) -> Void) {
        // We tiptoe around this for now. We will get into error handling later:
        // https://github.com/woocommerce/woocommerce-ios/issues/3734
        // https://github.com/woocommerce/woocommerce-ios/issues/3741
        cardReaderService.connect(reader).sink(receiveCompletion: { error in
        }, receiveValue: { (result) in
        }).store(in: &cancellables)

        // Dispatch completion block everytime the service published a new
        // collection of connected readers
        cardReaderService.connectedReaders.sink { connectedHardwareReaders in
            onCompletion(.success(connectedHardwareReaders))
        }.store(in: &cancellables)
    }

    func collectPayment(siteID: Int64, orderID: Int64, parameters: PaymentParameters, onCompletion: @escaping (Result<Bool, Error>) -> Void) {
        // The high-level logic of this method would be:
        // 1. Attack the CardReaderService to create a payment intent.
        // When that is completed...
        // 2. Attack the CardReaderService to collect payment methods for that intent
        // When that is completed...
        // 3. Attack the CardReaderService to process the payment

        // For now, we will only implement step 1.
        // Create an intent.
        // And for now, we are not doing any error handling.
//        cardReaderService.createPaymentIntent(parameters).sink(receiveCompletion: {error in
//            switch error {
//            case .failure(let error):
//                let result: Result<Bool, Error> = .failure(error)
//                onCompletion(result)
//            case .finished:
//                let result: Result<Bool, Error> = .success(true)
//                onCompletion(result)
//            }
//        }) { (intent) in
//            print("==== Log for testing purposes. payment intent collected ")
//            print(intent)
//            print("//// payment intent collected ")
//            // TODO. Initiate step 2. Collect payment method.
//            // Deferred to https://github.com/woocommerce/woocommerce-ios/issues/3825
//            let result: Result<Bool, Error> = .success(true)
//            onCompletion(result)
//        }.store(in: &cancellables)

//        let createPaymentIntent = Deferred {
//            self.cardReaderService.createPaymentIntent(parameters)
//        }
//
//        let collectPaymentMethod = Deferred {
//            self.cardReaderService.collectPaymentMethod(<#T##intent: PaymentIntent##PaymentIntent#>)
//        }

        // The completion block is going to be called twice, as it is.
        // First, when we receive a value for an intent, and second when the
        // stream is completed. We will have to deal with this later on,
        // if we finally decide to move forward with the Combine-based API in the
        // card reader service
        cardReaderService.createPaymentIntent(parameters)
            .flatMap { intent in
                self.cardReaderService.collectPaymentMethod(intent)
            }.flatMap { intent in
                self.cardReaderService.processPaymentIntent(intent)
            }.sink { error in
            switch error {
            case .failure(let error):
                let result: Result<Bool, Error> = .failure(error)
                onCompletion(result)
            case .finished:
                print("===== finished ")
                print("===== error ", error)
                let result: Result<Bool, Error> = .success(true)
                onCompletion(result)
            }
        } receiveValue: { intent in
            print("==== Yosemite log for testing. Payment intent processed ")
            print(intent)
            print("//// payment intent processed ")
            // TODO. Initiate step 3. Process Payment intent.
            // Deferred to https://github.com/woocommerce/woocommerce-ios/issues/3825
            let result: Result<Bool, Error> = .success(true)
            onCompletion(result)
        }.store(in: &cancellables)
    }
}


/// Implementation of the CardReaderNetworkingAdapter
/// that fetches a token using WCPayRemote
private final class WCPayTokenProvider: CardReaderConfigProvider {
    private let siteID: Int64
    private let remote: WCPayRemote

    init(siteID: Int64, remote: WCPayRemote) {
        self.siteID = siteID
        self.remote = remote
    }

    func fetchToken(completion: @escaping(String?, Error?) -> Void) {
        remote.loadConnectionToken(for: siteID) { token, error in
            completion(token?.token, error)
        }
    }
}
