import Venice
import Darwin

struct Item : Equatable {
    let domain: String
    let title: String
    let GUID: String
}

func ==(lhs: Item, rhs: Item) -> Bool {
    return lhs.GUID == rhs.GUID
}

struct FetchResponse {
    let items: [Item]
    let nextFetchTime: Int
}

protocol FetcherType {
    func fetch() -> Result<FetchResponse>
}

struct Fetcher : FetcherType {
    let domain: String

    func randomItems() -> [Item] {
        let items = [
            Item(domain: domain, title: "Swift 2.0", GUID: "1"),
            Item(domain: domain, title: "Strings in Swift 2", GUID: "2"),
            Item(domain: domain, title: "Swift-er SDK", GUID: "3"),
            Item(domain: domain, title: "Swift 2 Apps in the App Store", GUID: "4"),
            Item(domain: domain, title: "Literals in Playgrounds", GUID: "5"),
            Item(domain: domain, title: "Swift Open Source", GUID: "6")
        ]
        return [Item](items[0..<Int(arc4random_uniform(UInt32(items.count)))])
    }

    func fetch() -> Result<FetchResponse> {
        if arc4random_uniform(2) == 0 {
            let fetchResponse = FetchResponse(
                items: randomItems(),
                nextFetchTime: now + 300 * millisecond
            )
            return Result.Value(fetchResponse)
        } else {
            struct Error : ErrorType, CustomStringConvertible { let description: String }
            return Result.Error(Error(description: "Network Error"))
        }
    }
}

protocol SubscriptionType {
    var updates: SendingChannel<Item> { get }
    func close() -> ErrorType?
}

struct Subscription : SubscriptionType {
    let fetcher: FetcherType
    let items = Channel<Item>()
    let closing = Channel<Channel<ErrorType?>>()

    init(fetcher: FetcherType) {
        self.fetcher = fetcher
        co(self.getUpdates())
    }

    var updates: SendingChannel<Item> {
        return self.items.sendingChannel
    }

    func getUpdates() {
        let maxPendingItems = 10
        let fetchDone = Channel<Result<FetchResponse>>(bufferSize: 1)

        var lastError: ErrorType?
        var pendingItems: [Item] = []
        var seenItems: [Item] = []
        var nextFetchTime = now
        var fetching = false

        forSelect { when, done in
            when.receiveFrom(closing) { errorChannel in
                errorChannel <- lastError
                self.items.close()
                done()
            }

            if !fetching && pendingItems.count < maxPendingItems {
                when.timeout(nextFetchTime) {
                    fetching = true
                    co {
                        fetchDone <- self.fetcher.fetch()
                    }
                }
            }

            when.receiveFrom(fetchDone) { fetchResult in
                fetching = false
                fetchResult.success { response in
                    for item in response.items {
                        if !seenItems.contains(item) {
                            pendingItems.append(item)
                            seenItems.append(item)
                        }
                    }
                    lastError = nil
                    nextFetchTime = response.nextFetchTime
                }
                fetchResult.failure { error in
                    lastError = error
                    nextFetchTime = now + 1 * second
                }
            }

            if let item = pendingItems.first {
                when.send(item, to: items) {
                    pendingItems.removeFirst()
                }
            }
        }
    }

    func close() -> ErrorType? {
        let errorChannel = Channel<ErrorType?>()
        closing <- errorChannel
        return !<-errorChannel
    }
}

let fetcher = Fetcher(domain: "developer.apple.com/swift/blog/")
let subscription = Subscription(fetcher: fetcher)

after(5 * second) {
    if let lastError = subscription.close() {
        print("Closed with last error: \(lastError)")
    } else {
        print("Closed with no last error")
    }
}

for item in subscription.updates {
    print("\(item.domain): \(item.title)")
}
