import SwiftGo
//: Non-Blocking Channel Operations
//: -------------------------------
//:
//: Basic sends and receives on channels are blocking.
//: However, we can use `select` with a `otherwise` clause to
//: implement _non-blocking_ sends, receives, and even
//: non-blocking multi-way `select`s.
let messages = Channel<String>()
let signals = Channel<Bool>()
//: Here's a non-blocking receive. If a value is
//: available on `messages` then `select` will take
//: the `receiveFrom(messages)` case with that value. If not
//: it will immediately take the `otherwise` case.
select { when in
    when.receiveFrom(messages) { msg in
        print("received message \(msg)")
    }
    when.otherwise {
        print("no message received")
    }
}
//: A non-blocking send works similarly.
let msg = "hi"

select { when in
    when.sendValue(msg, to: messages) {
        print("sent message \(msg)")
    }
    when.otherwise {
        print("no message sent")
    }
}
//: We can use multiple cases above the `otherwise`
//: clause to implement a multi-way non-blocking
//: select. Here we attempt non-blocking receives
//: on both `messages` and `signals`.
select { when in
    when.receiveFrom(messages) { msg in
        print("receive message \(msg)")
    }
    when.receiveFrom(signals) { sig in
        print("received signal \(sig)")
    }
    when.otherwise {
        print("no activity")
    }
}
//:
//: Next example: [Closing Channels](@next)
