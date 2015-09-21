import SwiftGo
//: Tickers
//: -------
//:
//: [Timers](timers) are for when you want to do
//: something once in the future - _tickers_ are for when
//: you want to do something repeatedly at regular
//: intervals. Here's an example of a ticker that ticks
//: periodically until we stop it.
//:
//: Tickers use a similar mechanism to timers: a
//: channel that is sent values. Here we'll use the
//: `generator` builtin on the channel to iterate over
//: the values as they arrive every 500ms.
let ticker = Ticker(period: 500 * millisecond)

go {
    for time in ticker.channel {
        print("Tick at \(time)")
    }
}
//: Tickers can be stopped like timers. Once a ticker
//: is stopped it won't receive any more values on its
//: channel. We'll stop ours after 1600ms.
nap(now + 1600 * millisecond)
ticker.stop()
print("Ticker stopped")
//: When we run this program the ticker should tick 3 times before we stop it.
//:
//: Next example: [Worker Pools](@next)
