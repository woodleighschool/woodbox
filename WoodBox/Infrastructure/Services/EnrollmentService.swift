import Foundation

@MainActor
protocol EnrollmentServicing {
  func fetchSnapshot() async throws -> EnrollmentSnapshot
  func assign(_ policy: EnrollmentPolicy, serials: [String]) async throws
}

struct LiveEnrollmentService: EnrollmentServicing {
  let settings: AppSettings

  private func client() throws -> IntuneClient {
    guard let client = settings.intuneClient else {
      throw IntegrationError(
        action: "load enrollment",
        integration: "Intune",
        message: "The integration is not enabled or configured"
      )
    }
    return client
  }

  func fetchSnapshot() async throws -> EnrollmentSnapshot {
    let client = try client()
    var policies: [EnrollmentPolicy] = []
    var devices: [EnrollmentDevice] = []
    for token in try await client.fetchEnrollmentTokens() {
      try Task.checkCancellation()
      async let fetchedProfiles = client.fetchEnrollmentProfiles(tokenId: token.id)
      async let identities = client.fetchEnrollmentDevices(tokenId: token.id)
      let profiles = try await fetchedProfiles
      policies += profiles.map { EnrollmentPolicy($0, tokenId: token.id) }
      policies += EnrollmentPolicy.defaults(of: token, excluding: profiles)
      try await devices += identities.compactMap { EnrollmentDevice($0, tokenId: token.id) }
    }
    return EnrollmentSnapshot(policies: policies, devices: devices)
  }

  func assign(_ policy: EnrollmentPolicy, serials: [String]) async throws {
    try await client().assignEnrollmentProfile(id: policy.id, tokenId: policy.tokenId, serials: serials)
  }
}

struct EnrollmentCoordinator {
  let service: any EnrollmentServicing

  func assign(_ proposed: EnrollmentAssignmentPlan, progress: (String, OperationActivity) -> Void) async throws {
    let snapshot = try await service.fetchSnapshot()
    guard let target = snapshot.policy(id: proposed.target.id), target.tokenId == proposed.target.tokenId else {
      throw IntegrationError(action: "assign policy", integration: "Intune", message: "The selected policy is no longer available")
    }
    let plan = EnrollmentAssignmentPlan(serials: proposed.serials, target: target, snapshot: snapshot)
    for serial in plan.serials {
      switch plan.decisions[serial] {
      case .assign: progress(serial, .waiting)
      case .unchanged: progress(serial, .unchanged)
      case let .skip(reason): progress(serial, .skipped(reason))
      case nil: break
      }
    }
    for batch in plan.batches {
      try Task.checkCancellation()
      batch.forEach { progress($0, .working("Assigning")) }
      do {
        try await service.assign(target, serials: batch)
        batch.forEach { progress($0, .applied) }
      } catch {
        batch.forEach { progress($0, .failed(error.localizedDescription)) }
      }
    }
  }
}
