import SwiftGo
import Darwin

var channelA: Channel<String>? = Channel<String>()
var channelB: Channel<String>? = Channel<String>()

if arc4random_uniform(2) == 0 {
    channelA = nil
    print("disabled channel a")
} else {
    channelB = nil
    print("disabled channel b")
}

go { channelA?.receive("a") }
go { channelB?.receive("b") }

select { when in
    when.receiveFrom(channelA) { value in
        print("received \(value) from channel a")
    }
    when.receiveFrom(channelB) { value in
        print("received \(value) from channel b")
    }
}

