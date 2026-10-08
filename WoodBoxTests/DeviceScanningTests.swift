import Testing
@testable import WoodBox

@Suite("Continuous device scanning")
@MainActor
struct DeviceScanningTests {
  @Test("OCR considers ambiguous glyphs even when one serial is an exact match")
  func resolvesOCRWithoutGuessing() {
    let zero = Device(serial: "AB01234567", assetTag: "100", model: "Test Laptop")
    let letter = Device(serial: "ABO1234567", assetTag: "1OO", model: "Test Laptop")
    let lookup = DeviceScanLookup(devices: [zero, letter])

    #expect(Set(lookup.matches(.text(zero.serial)).map(\.serial)) == [zero.serial, letter.serial])
    #expect(lookup.matches(.barcode("100")).map(\.serial) == [zero.serial])
    #expect(lookup.matches(.barcode("1O0")).isEmpty)
    #expect(lookup.matches(.text("AC01234567")).isEmpty)
    #expect(zero.serial == "AB01234567")
    #expect(letter.serial == "ABO1234567")
  }

  @Test("a unique OCR match accepts multiple confused glyphs without editing the serial")
  func resolvesUniqueOCRMatch() {
    let device = Device(serial: "AB01234567", assetTag: "100", model: "Test Laptop")
    let lookup = DeviceScanLookup(devices: [device])
    #expect(lookup.matches(.text("A8OLZ34567")).map(\.serial) == [device.serial])
    #expect(DeviceScan.serialCandidates(in: "California Serial: ab01234567") == ["CALIFORNIA", "AB01234567"])
    #expect(DeviceScan.serialCandidates(in: "Designed by Apple").isEmpty)
  }

  @Test("a printed word is not reported as a missing device")
  func unmatchedWords() {
    #expect(!DeviceScan.text("CALIFORNIA").isReportableMiss)
    #expect(DeviceScan.text("AB01234567").isReportableMiss)
    #expect(DeviceScan.barcode("ASSET").isReportableMiss)
  }

  @Test("repeats are throttled without delaying a different machine")
  func continuousObservations() {
    var session = DeviceScanSession()
    let now = ContinuousClock.now
    let first = session.accepts(.text("AB01234567"), now: now)
    let repeated = session.accepts(.text("AB01234567"), now: now.advanced(by: .milliseconds(100)))
    let different = session.accepts(.text("AC01234567"), now: now.advanced(by: .milliseconds(100)))
    let later = session.accepts(.text("AB01234567"), now: now.advanced(by: .seconds(3)))
    #expect(first)
    #expect(!repeated)
    #expect(different)
    #expect(later)
  }

  @Test("only completed unique additions count and success survives repeated recognition")
  func sessionFeedback() {
    var session = DeviceScanSession()
    let now = ContinuousClock.now
    session.report("No match")
    #expect(session.addedSerials.isEmpty)
    session.added(serial: "AB01234567", label: "100", now: now)
    session.added(serial: "AB01234567", label: "100", now: now)
    session.report("Already queued", now: now.advanced(by: .milliseconds(100)))
    #expect(session.addedSerials.count == 1)
    #expect(session.feedback == ScanFeedback(message: "Added 100", isSuccess: true))
    session.added(serial: "AC01234567", label: "101", now: now.advanced(by: .milliseconds(200)))
    #expect(session.addedSerials.count == 2)
    session.report("Unable to save", immediately: true, now: now.advanced(by: .milliseconds(300)))
    #expect(session.feedback?.message == "Unable to save")
    #expect(DeviceScanSession().addedSerials.isEmpty)
  }
}
