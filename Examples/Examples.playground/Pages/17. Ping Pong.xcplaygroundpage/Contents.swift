import Venice

final class Ball { var hits: Int = 0 }

func player(name: String, table: Channel<Ball>) {
    while true {
        let ball = !<-table
        ball.hits++
        print("\(name) \(ball.hits)")
        nap(100 * millisecond)
        table <- ball
    }
}

let table = Channel<Ball>()

co(player("ping", table: table))
co(player("pong", table: table))

table <- Ball()
nap(1 * second)
<-table
