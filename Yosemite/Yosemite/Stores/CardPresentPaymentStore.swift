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

    private var cancellables: Set<AnyCancellable> = []

    public init(dispatcher: Dispatcher, storageManager: StorageManagerType, network: Network, cardReaderService: CardReaderService) {
        self.cardReaderService = cardReaderService
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
        case .startCardReaderDiscovery(let completion):
            startCardReaderDiscovery(completion: completion)
        case .connect(let reader, let completion):
            connect(reader: reader, onCompletion: completion)
        }
    }
}


// MARK: - Services
//
private extension CardPresentPaymentStore {
    func startCardReaderDiscovery(completion: @escaping (_ readers: [CardReader]) -> Void) {
        cardReaderService.start()

        // Over simplification. This is the point where we would receive
        // new data via the CardReaderService's stream of discovered readers
        // In here, we should redirect that data to Storage and also up to the UI.
        // For now we are sending the data up to the UI directly
        cardReaderService.discoveredReaders.sink { readers in
            completion(readers)
        }.store(in: &cancellables)
    }

    func connect(reader: Yosemite.CardReader, onCompletion: @escaping (Result<Yosemite.CardReader, Error>) -> Void) {
        cardReaderService.connect(reader).sink(receiveCompletion: { error in
            //
            print("===== completion received")
        }, receiveValue: { (result) in
            //
            print("value received === ", result)
        }).store(in: &cancellables)

        cardReaderService.connectedReaders.sink { connectedHardwareReaders in
            guard let firstReader = connectedHardwareReaders.first else {
//                let result: Result<Yosemite.CardReader, Error> = .failure(CardPresentPaymentError.internalState)
//                onCompletion(result)
                return
            }
            let result: Result<Yosemite.CardReader, Error> = .success(firstReader)
            onCompletion(result)
        }.store(in: &cancellables)
    }
}


public enum CardPresentPaymentError: Error {
    case internalState
}
