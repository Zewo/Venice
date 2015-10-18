import Venice

let tick = Ticker(period: 100 * millisecond).channel
let boom = Timer(deadline: now + 500 * millisecond).channel

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
