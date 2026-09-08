import Foundation
import Testing
@testable import DefaultAppsCore

@Suite("locations")
struct LocationsTests {
    @Test("machine-local state lives outside the shareable presets directory")
    func stateIsNotSharedWithPresets() {
        let locations = Locations.standard

        #expect(
            locations.state.path.hasPrefix(locations.presets.path) == false,
            "state under ~/.mda would travel in a dotfiles checkout")
        #expect(locations.presets.lastPathComponent == ".mda")
        #expect(locations.state.path.contains("Application Support"))
    }

    @Test("both directories are overridable, independently")
    func envOverrides() {
        let locations = Locations.standard(
            environment: ["MDA_PRESETS_DIR": "/tmp/p", "MDA_STATE_DIR": "/tmp/s"])

        #expect(locations.presets.path == "/tmp/p")
        #expect(locations.state.path == "/tmp/s")
    }
}
