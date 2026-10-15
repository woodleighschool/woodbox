import Foundation
import Testing
@testable import WoodBox

@Suite("Enrollment policies")
struct EnrollmentPolicyTests {
  @Test("mirrored policies and legacy profiles are read from one collection")
  func mapsProfiles() throws {
    let json = """
    {
      "@odata.nextLink": "https://graph.example.invalid/next",
      "value": [
        {
          "@odata.type": "#microsoft.graph.depMacOSEnrollmentProfile",
          "id": "token-1_profile-1",
          "displayName": "Legacy Mac",
          "isDefault": true
        },
        {
          "@odata.type": "#microsoft.graph.depIOSEnrollmentProfile",
          "id": "ECV2_policy-2",
          "displayName": "iOS Policy"
        },
        {
          "@odata.type": "#microsoft.graph.enrollmentProfile",
          "id": "ECV2_policy-3",
          "displayName": ""
        }
      ]
    }
    """

    let page = try JSONDecoder().decode(
      IntunePage<IntuneEnrollmentProfile>.self,
      from: Data(json.utf8)
    )
    let policies = page.value.map { EnrollmentPolicy($0, tokenId: "token-1") }

    #expect(page.nextLink == "https://graph.example.invalid/next")
    #expect(policies.map(\.platform) == [.macOS, .iOS, nil])
    #expect(policies.map(\.name) == ["Legacy Mac", "iOS Policy", "ECV2_policy-3"])
  }

  @Test("devices removed from Apple or without a serial are left out")
  func mapsDevices() throws {
    let json = """
    {
      "value": [
        {
          "id": "1",
          "serialNumber": "SERIAL-001",
          "platform": "macOS",
          "requestedEnrollmentProfileId": "token-1_profile-1",
          "isDeleted": false,
          "description": "MBA 13.3"
        },
        {
          "id": "2",
          "serialNumber": "SERIAL-002",
          "platform": "ios",
          "requestedEnrollmentProfileId": "",
          "isDeleted": false
        },
        { "id": "3", "serialNumber": "SERIAL-003", "platform": "macOS", "isDeleted": true },
        { "id": "4", "serialNumber": "", "platform": "macOS" }
      ]
    }
    """

    let page = try JSONDecoder().decode(
      IntunePage<IntuneEnrollmentDevice>.self,
      from: Data(json.utf8)
    )
    let devices = page.value.compactMap { EnrollmentDevice($0, tokenId: "token-1") }

    #expect(page.nextLink == nil)
    #expect(devices == [
      EnrollmentDevice(
        serial: "SERIAL-001",
        tokenId: "token-1",
        platform: .macOS,
        policyId: "token-1_profile-1",
        summary: "MBA 13.3"
      ),
      EnrollmentDevice(
        serial: "SERIAL-002",
        tokenId: "token-1",
        platform: .iOS,
        policyId: nil,
        summary: nil
      ),
    ])
  }

  @Test("a token's default policies name devices without accepting assignments")
  func mapsTokenDefaults() throws {
    let json = """
    {
      "value": [
        {
          "id": "token-1",
          "defaultTvOSEnrollmentProfile": {
            "@odata.type": "#microsoft.graph.depTvOSEnrollmentProfile",
            "id": "ECV2_aaaaaaaa-0000-0000-0000-000000000001",
            "displayName": "TV Policy"
          },
          "defaultVisionOSEnrollmentProfile": {
            "@odata.type": "#microsoft.graph.depVisionOSEnrollmentProfile",
            "id": "aaaaaaaa-0000-0000-0000-000000000002",
            "displayName": "Vision Policy"
          }
        }
      ]
    }
    """

    let token = try #require(
      JSONDecoder().decode(IntunePage<IntuneEnrollmentToken>.self, from: Data(json.utf8)).value.first
    )
    let defaults = EnrollmentPolicy.defaults(of: token, excluding: [])
    let snapshot = EnrollmentSnapshot(
      policies: defaults,
      devices: [
        device("TV-1", platform: .tvOS, policyId: "aaaaaaaa-0000-0000-0000-000000000001"),
        device("VISION-1", platform: .visionOS, policyId: "aaaaaaaa-0000-0000-0000-000000000002"),
      ]
    )

    #expect(defaults.map(\.platform) == [.tvOS, .visionOS])
    #expect(defaults.allSatisfy { !$0.isAssignable })
    #expect(snapshot.policyDescription(serial: "TV-1") == "TV Policy")
    #expect(snapshot.policyDescription(serial: "VISION-1") == "Vision Policy")
    #expect(snapshot.decision(serial: "TV-1", target: defaults[0]) == .skip("Policy does not support assignment"))

    let listedProfile = try #require(token.defaultVisionOSEnrollmentProfile)
    let remainingDefaults = EnrollmentPolicy.defaults(of: token, excluding: [listedProfile])
    #expect(remainingDefaults.map(\.id) == [defaults[0].id])
    #expect(EnrollmentPolicy(listedProfile, tokenId: token.id).isAssignable)
  }

  @Test("assignment requests identify devices by serial number")
  func encodesAssignment() throws {
    let request = IntuneProfileAssignmentRequest(deviceIds: ["SERIAL-001", "SERIAL-002"])

    let payload = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
    )

    #expect(payload["deviceIds"] as? [String] == ["SERIAL-001", "SERIAL-002"])
  }

  @Test("a plan batches the devices that can move and leaves the rest alone")
  func plansAssignment() {
    let target = EnrollmentPolicy(
      id: "ECV2_mac",
      tokenId: "token-1",
      name: "Mac Policy",
      platform: .macOS
    )
    let snapshot = EnrollmentSnapshot(
      policies: [target],
      devices: [
        device("MAC-1", policyId: "legacy"),
        device("MAC-2", policyId: nil),
        device("MAC-3", policyId: "ECV2_mac"),
        device("IPAD-1", platform: .iOS, policyId: "legacy"),
        device("MAC-4", tokenId: "token-2", policyId: "legacy"),
        device("UNREPORTED-1", platform: nil, policyId: "legacy"),
      ]
    )

    let plan = EnrollmentAssignmentPlan(
      serials: ["MAC-1", "MAC-2", "MAC-3", "IPAD-1", "MAC-4", "UNREPORTED-1", "MISSING-1"],
      target: target,
      snapshot: snapshot,
      batchSize: 2
    )

    #expect(plan.batches == [["MAC-1", "MAC-2"], ["UNREPORTED-1"]])
    #expect(plan.decisions["MAC-3"] == .unchanged)
    #expect(plan.decisions["IPAD-1"] == .skip("Policy is for macOS devices"))
    #expect(plan.decisions["MAC-4"] == .skip("In a different enrollment program token"))
    #expect(plan.decisions["MISSING-1"] == .skip("Not in an enrollment program token"))
  }

  @Test("devices match the one policy whose ID ends in the same GUID, and others stay visible")
  func matchesPrefixedPolicyIds() {
    let legacyGUID = "aaaaaaaa-0000-0000-0000-000000000001"
    let mirroredGUID = "bbbbbbbb-0000-0000-0000-000000000002"
    let ambiguousGUID = "cccccccc-0000-0000-0000-000000000003"
    let legacy = EnrollmentPolicy(id: "token-1_\(legacyGUID)", tokenId: "token-1", name: "Legacy", platform: .macOS)
    let mirrored = EnrollmentPolicy(id: "ECV2_\(mirroredGUID)", tokenId: "token-1", name: "Policy", platform: .macOS)
    let ambiguous = ["ECV2_\(ambiguousGUID)", "token-1_\(ambiguousGUID)"].map {
      EnrollmentPolicy(id: $0, tokenId: "token-1", name: $0, platform: .macOS)
    }
    let snapshot = EnrollmentSnapshot(
      policies: [legacy, mirrored] + ambiguous,
      devices: [
        device("MAC-1", policyId: legacyGUID),
        device("MAC-2", policyId: mirroredGUID.uppercased()),
        device("MAC-3", policyId: mirrored.id),
        device("MAC-4", tokenId: "token-2", policyId: mirroredGUID),
        device("MAC-5", policyId: ambiguousGUID),
        device("MAC-6", policyId: "deleted"),
        device("MAC-7", policyId: ambiguous[0].id),
      ]
    )

    #expect(snapshot.deviceCount(policyId: legacy.id) == 1)
    #expect(snapshot.deviceCount(policyId: mirrored.id) == 2)
    #expect(snapshot.deviceCount(policyId: ambiguous[0].id) == 1)
    #expect(snapshot.unrecognizedPolicyIds == [mirroredGUID, ambiguousGUID, "deleted"].sorted())
    #expect(snapshot.serials(policyId: ambiguousGUID) == ["MAC-5"])
    #expect(snapshot.policyDescription(serial: "MAC-6") == "Unknown policy deleted")
    #expect(snapshot.decision(serial: "MAC-2", target: mirrored) == .unchanged)
  }

  @Test("arbitrary suffixes are not treated as GUIDs")
  func preservesOpaqueIds() {
    let policy = EnrollmentPolicy(id: "prefix_shared", tokenId: "token-1", name: "Policy", platform: .macOS)
    let snapshot = EnrollmentSnapshot(policies: [policy], devices: [
      device("MAC-1", policyId: policy.id),
      device("MAC-2", policyId: "other_shared"),
      device("MAC-3", policyId: "shared"),
      device("MAC-4", policyId: nil),
    ])

    #expect(snapshot.deviceCount(policyId: policy.id) == 1)
    #expect(snapshot.deviceCount(policyId: nil) == 1)
    #expect(snapshot.unrecognizedPolicyIds == ["other_shared", "shared"])
    #expect(snapshot.decision(serial: "MAC-2", target: policy) == .assign)
  }

  private func device(
    _ serial: String,
    tokenId: String = "token-1",
    platform: EnrollmentPlatform? = .macOS,
    policyId: String?
  ) -> EnrollmentDevice {
    EnrollmentDevice(
      serial: serial,
      tokenId: tokenId,
      platform: platform,
      policyId: policyId,
      summary: nil
    )
  }
}
