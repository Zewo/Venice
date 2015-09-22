import SwiftGo
import Darwin

var a: Channel<String>? = Channel<String>()
var b: Channel<String>? = Channel<String>()

if arc4random_uniform(2) == 0 {
    a = nil
    print("nil a")
} else {
    b = nil
    print("nil b")
}

go(a <- "a")
go(b <- "b")

select { when in
    when.receiveFrom(a) { s in
        print("got \(s)")
    }
    when.receiveFrom(b) { s in
        print("got \(s)")
    }
}

