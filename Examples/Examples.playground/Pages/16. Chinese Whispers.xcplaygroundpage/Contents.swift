import Venice

func whisper(left: ReceivingChannel<Int>, _ right: SendingChannel<Int>) {
    left <- 1 + !<-right
}

let numberOfWhispers = 100

let leftmost = Channel<Int>()
var right = leftmost
var left = leftmost

for _ in 0 ..< numberOfWhispers {
    right = Channel<Int>()
    co(whisper(left.receivingChannel, right.sendingChannel))
    left = right
}

co(right <- 1)
print(!<-leftmost)
