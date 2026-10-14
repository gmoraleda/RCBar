import Foundation

if CommandLine.arguments.contains("--selftest") {
    runSelfTest()
    exit(0)
}
RCBarApp.main()
