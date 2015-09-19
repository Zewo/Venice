import SwiftGo
//: Worker Pools
//: ------------
//:
//: In this example we'll look at how to implement
//: a _worker pool_ using goroutines and channels.
//:
//: Here's the worker, of which we'll run several
//: concurrent instances. These workers will receive
//: work on the `jobs` channel and send the corresponding
//: results on `results`. We'll sleep a second per job to
//: simulate an expensive task.
func worker(id: Int, jobs: Channel<Int>, results: Channel<Int>) {
    for j in jobs {
        print("worker \(id) processing job \(j)")
        nap(now + 1 * second)
        results <- j * 2
    }
}
//: In order to use our pool of workers we need to send
//: them work and collect their results. We make 2
//: channels for this.
let jobs = Channel<Int>(bufferSize: 100)
let results = Channel<Int>(bufferSize: 100)
//: This starts up 3 workers, initially blocked
//: because there are no jobs yet.
for w in 1 ... 3 {
    go(worker(w, jobs: jobs, results: results))
}
//: Here we send 9 `jobs` and then `close` that
//: channel to indicate that's all the work we have.
for j in 1 ... 9 {
    jobs <- j
}

jobs.close()
//: Finally we collect all the results of the work.
for _ in 1 ... 9 {
    <-results
}
//: Our running program shows the 9 jobs being executed by various workers. The program only 
//: takes about 3 seconds despite doing about 9 seconds of total work because there are 3 
//: workers operating concurrently.
//:
//: Next example: [Rate Limiting](@next)
