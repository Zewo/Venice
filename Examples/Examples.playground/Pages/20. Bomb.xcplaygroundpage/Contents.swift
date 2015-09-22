import SwiftGo

let tick = Ticker(period: 100 * millisecond).internalChannel
let boom = Timer(deadline: now + 500 * millisecond).internalChannel

var done = false
while !done {
    select { when in
        when.receiveFrom(tick) { _ in
            print("tick")
        }
        when.receiveFrom(boom) { _ in
            print("BOOM!")
            done = true
        }
        when.otherwise {
            print("    .")
            nap(50 * millisecond)
        }
    }
}