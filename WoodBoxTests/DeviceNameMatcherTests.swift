import Testing
@testable import WoodBox

@Suite("Device name matching")
struct DeviceNameMatcherTests {
  @Test("matches a regular expression anywhere in the name")
  func matchesPattern() {
    #expect(DeviceNameMatcher.matches("SPARE-MBP-042", pattern: "SPARE-(MBP|MBA)-[0-9]+"))
  }

  @Test("rejects absent input")
  func rejectsAbsentInput() {
    #expect(DeviceNameMatcher.matches(nil, pattern: "SPARE") == false)
    #expect(DeviceNameMatcher.matches("", pattern: "SPARE") == false)
    #expect(DeviceNameMatcher.matches("SPARE-MBP-042", pattern: "") == false)
  }

  @Test("invalid expressions never match")
  func rejectsInvalidPattern() {
    #expect(DeviceNameMatcher.matches("SPARE-MBP-042", pattern: "[") == false)
  }

  @Test("matching remains case-sensitive")
  func preservesCaseSensitivity() {
    #expect(DeviceNameMatcher.matches("spare-mbp-042", pattern: "SPARE") == false)
  }
}
