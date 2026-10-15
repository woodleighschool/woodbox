import Foundation

/// Raw values are the platform names Graph uses for enrollment program devices.
nonisolated enum EnrollmentPlatform: String {
  case iOS = "ios"
  case macOS
  case tvOS = "tvos"
  case visionOS

  var title: String {
    switch self {
    case .iOS: "iOS/iPadOS"
    case .macOS: "macOS"
    case .tvOS: "tvOS"
    case .visionOS: "visionOS"
    }
  }
}

/// A device enrollment profile exposed by Intune’s enrollment program API.
nonisolated struct EnrollmentPolicy: Identifiable, Hashable {
  let id: String
  let tokenId: String
  let name: String
  let platform: EnrollmentPlatform?
  /// Token defaults exposed only for their display names cannot accept assignments.
  var isAssignable = true
}

nonisolated struct EnrollmentDevice: Equatable {
  let serial: String
  let tokenId: String
  let platform: EnrollmentPlatform?
  let policyId: String?
  /// Apple's description of the hardware, such as "MBP 16.0 SPACE GRAY".
  let summary: String?
}

nonisolated enum EnrollmentDecision: Equatable {
  case assign
  case unchanged
  case skip(String)
}

nonisolated struct EnrollmentSnapshot {
  let policies: [EnrollmentPolicy]
  let devices: [String: EnrollmentDevice]
  private let deviceCounts: [String?: Int]

  init(policies: [EnrollmentPolicy], devices: [EnrollmentDevice]) {
    // Graph prefixes profile IDs with a token ID or ECV2_, but device assignments can use
    // the bare GUID. Resolve only an unambiguous match within the device's token.
    let policiesByGUID = Dictionary(grouping: policies) { Self.guid(in: $0.id) }
    let devices = devices.map { device in
      guard let requested = device.policyId, let guid = Self.guid(in: requested) else { return device }
      let matches = policiesByGUID[guid, default: []].filter { $0.tokenId == device.tokenId }
      if matches.contains(where: { $0.id == requested }) {
        return device
      }
      guard matches.count == 1 else { return device }
      return EnrollmentDevice(
        serial: device.serial,
        tokenId: device.tokenId,
        platform: device.platform,
        policyId: matches[0].id,
        summary: device.summary
      )
    }

    self.policies = policies.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    self.devices = Dictionary(devices.map { ($0.serial, $0) }, uniquingKeysWith: { _, latest in latest })
    deviceCounts = Dictionary(grouping: self.devices.values, by: \.policyId).mapValues(\.count)
  }

  private static func guid(in id: String) -> UUID? {
    guard let suffix = id.split(separator: "_", omittingEmptySubsequences: false).last else { return nil }
    return UUID(uuidString: String(suffix))
  }

  /// Policy IDs that devices request but no loaded policy matches, such as a deleted profile.
  var unrecognizedPolicyIds: [String] {
    deviceCounts.keys.compactMap(\.self).filter { policy(id: $0) == nil }.sorted()
  }

  func policy(id: String?) -> EnrollmentPolicy? {
    guard let id else { return nil }
    return policies.first { $0.id == id }
  }

  func deviceCount(policyId: String?) -> Int {
    deviceCounts[policyId] ?? 0
  }

  func serials(policyId: String?) -> [String] {
    devices.values.filter { $0.policyId == policyId }.map(\.serial).sorted()
  }

  func policyDescription(serial: String) -> String {
    guard let device = devices[serial] else { return "Not in an enrollment program token" }
    guard let policyId = device.policyId else { return "No policy" }
    return policy(id: policyId)?.name ?? "Unknown policy \(policyId)"
  }

  func decision(serial: String, target: EnrollmentPolicy) -> EnrollmentDecision {
    guard target.isAssignable else {
      return .skip("Policy does not support assignment")
    }
    guard let device = devices[serial] else {
      return .skip("Not in an enrollment program token")
    }
    guard device.tokenId == target.tokenId else {
      return .skip("In a different enrollment program token")
    }
    if let platform = target.platform, let devicePlatform = device.platform, platform != devicePlatform {
      return .skip("Policy is for \(platform.title) devices")
    }
    return device.policyId == target.id ? .unchanged : .assign
  }
}

/// The devices a run assigns, in batches, and what happens to the rest. Devices already on the
/// target are left alone so that repeating a run sends nothing.
nonisolated struct EnrollmentAssignmentPlan: Identifiable {
  let id = UUID()
  let target: EnrollmentPolicy
  let serials: [String]
  let decisions: [String: EnrollmentDecision]
  let batches: [[String]]

  init(
    serials: [String],
    target: EnrollmentPolicy,
    snapshot: EnrollmentSnapshot,
    batchSize: Int = 100
  ) {
    let decisions = Dictionary(
      serials.map { ($0, snapshot.decision(serial: $0, target: target)) },
      uniquingKeysWith: { first, _ in first }
    )
    let serials = serials.reduce(into: [String]()) {
      if !$0.contains($1) {
        $0.append($1)
      }
    }
    let batchSize = max(1, batchSize)
    let assignable = serials.filter { decisions[$0] == .assign }

    self.target = target
    self.serials = serials
    self.decisions = decisions
    batches = stride(from: 0, to: assignable.count, by: batchSize).map {
      Array(assignable[$0 ..< min($0 + batchSize, assignable.count)])
    }
  }
}

// MARK: - Intune

extension EnrollmentPolicy {
  nonisolated init(_ profile: IntuneEnrollmentProfile, tokenId: String, isAssignable: Bool = true) {
    id = profile.id
    self.tokenId = tokenId
    self.isAssignable = isAssignable
    name = profile.displayName.nilIfEmpty ?? profile.id
    platform = switch profile.odataType {
    case "#microsoft.graph.depIOSEnrollmentProfile": .iOS
    case "#microsoft.graph.depMacOSEnrollmentProfile": .macOS
    case "#microsoft.graph.depTvOSEnrollmentProfile": .tvOS
    case "#microsoft.graph.depVisionOSEnrollmentProfile": .visionOS
    default: nil
    }
  }

  nonisolated static func defaults(of token: IntuneEnrollmentToken, excluding profiles: [IntuneEnrollmentProfile]) -> [EnrollmentPolicy] {
    [token.defaultTvOSEnrollmentProfile, token.defaultVisionOSEnrollmentProfile]
      .compactMap(\.self)
      .filter { profile in !profiles.contains { $0.id == profile.id } }
      .map { EnrollmentPolicy($0, tokenId: token.id, isAssignable: false) }
  }
}

extension EnrollmentDevice {
  /// Devices removed from Apple School Manager or Apple Business Manager can't be assigned, so they
  /// are left out.
  nonisolated init?(_ device: IntuneEnrollmentDevice, tokenId: String) {
    guard let serial = device.serialNumber.nilIfEmpty, device.isDeleted != true else { return nil }
    self.serial = serial
    self.tokenId = tokenId
    platform = device.platform.flatMap(EnrollmentPlatform.init(rawValue:))
    policyId = device.requestedEnrollmentProfileId.nilIfEmpty
    summary = device.description.nilIfEmpty
  }
}
