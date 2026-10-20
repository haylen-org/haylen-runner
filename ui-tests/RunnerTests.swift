import XCTest

// The flow of the runner with the probe app of `ui-tests/probe`, which `haylen serve ui-tests/probe` serves while the tests run: the address and the folder of the probe reach the tests as `RUNNER_ADDRESS` and `RUNNER_PROBE`, through the prefix `TEST_RUNNER_` of xcodebuild. The tests open the probe by its link or its typed address, check that it has no native access, change its source to check the hot reload, come back to the runner and find it in the history with its name, then remove it.
class RunnerTests: HaylenUITestCase {
    var address: String!
    var message: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        address = try XCTUnwrap(Self.environment["RUNNER_ADDRESS"], "Serve the probe with \"haylen serve ui-tests/probe\" and hand its address to the tests as \"TEST_RUNNER_RUNNER_ADDRESS\".")
        let probe = try XCTUnwrap(Self.environment["RUNNER_PROBE"], "Hand the folder of the probe to the tests as \"TEST_RUNNER_RUNNER_PROBE\".")
        message = URL(fileURLWithPath: probe).appendingPathComponent("source/message.lua")
        try write("First version")
    }

    override func tearDown() {
        try? write("First version")
        super.tearDown()
    }

    func write(_ text: String) throws {
        try "return {text = '\(text)'}\n".write(to: message, atomically: true, encoding: .utf8)
    }

    // The probe plays its first version, takes a save in place, and the history keeps it by the name of its package once it is back in the runner.
    func playTheProbeWithHotReload() throws {
        if !element("First version").waitForExistence(timeout: Self.timeout) {
            try saveScreenshot("not-opened")
        }
        waitFor(element("First version"), timeout: 1)
        // The runner launches the probe without native access.
        waitFor(element("No native access"), timeout: 1)
        try saveScreenshot("probe")
        try write("Second version")
        waitFor(element("Second version"))
        try saveScreenshot("reloaded")
    }

    func checkTheHistoryAndRemoveTheProbe() throws {
        waitFor(element(matching: "Probe.*"))
        try saveScreenshot("history")
#if !os(tvOS)
        tap("Remove Probe")
        waitUntil("The history still shows the probe.") { !element("Remove Probe").exists }
        try saveScreenshot("removed")
#endif
    }

#if os(iOS) || os(visionOS)
    // Taps the keys of the software keyboard one by one, as a person types, switching between the letters and the digits.
    func press(_ text: String) {
        let keyboard = app.keyboards.firstMatch
        for character in text {
            let key = keyboard.keys[String(character)]
            // The key "more" switches between the letters and the digits with the marks of an address.
            if !key.exists {
                keyboard.keys["more"].tap()
            }
            waitFor(key).tap()
        }
    }

    func testALinkOpensTheAppWithHotReloadAndTheAppQuitsBackToTheRunner() throws {
        let link = "haylen-runner://open?url=" + address.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        app.open(URL(string: link)!)
        // The system asks whether the link opens the runner.
        let open = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Open"]
        if open.waitForExistence(timeout: 10) {
            open.tap()
        }
        try playTheProbeWithHotReload()
        tap("Quit to the runner")
        try checkTheHistoryAndRemoveTheProbe()
    }

    func testATypedAddressOpensTheApp() throws {
        tap("Address of the app")
        waitFor(app.keyboards.firstMatch)
        press(address)
        waitFor(app.keyboards.buttons["Go"]).tap()
        try playTheProbeWithHotReload()
        tap("Quit to the runner")
        try checkTheHistoryAndRemoveTheProbe()
    }
#endif

#if os(tvOS)
    // The remote types the address with the keyboard of the system, and a hold of its play and pause button leaves the probe, which the probe cannot take.
    func testTheRemoteTypesTheAddressAndAHoldOfPlayAndPauseComesBack() throws {
        let remote = XCUIRemote.shared
        let field = element("Address of the app")
        waitFor(field)
        for _ in 0..<4 where !field.hasFocus {
            remote.press(.up)
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        try saveScreenshot("field-focused")
        remote.press(.select)
        waitFor(app.keyboards.firstMatch)
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        try saveScreenshot("keyboard")
        app.typeText(address)
        try saveScreenshot("typed")
        remote.press(.menu)
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        remote.press(.down)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        try saveScreenshot("open-focused")
        remote.press(.select)
        try playTheProbeWithHotReload()
        remote.press(.playPause, forDuration: 2.5)
        try checkTheHistoryAndRemoveTheProbe()
    }
#endif
}
