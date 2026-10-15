import Foundation

/// The enrollment program devices and policies loaded from Intune, and the devices queued to move to
/// another policy. The queue lives for the session; it is a working list, not a record.
@Observable
@MainActor
final class EnrollmentQueue {
  enum AddResult {
    case added
    case alreadyListed
    case notEnrolled
    case notLoaded

    func failureMessage(label: String) -> String? {
      switch self {
      case .added: nil
      case .alreadyListed: "\(label) is already in the list."
      case .notEnrolled: "\(label) isn't in an enrollment program token."
      case .notLoaded: "Enrollment program devices haven't loaded."
      }
    }
  }

  // MARK: - Properties

  private(set) var snapshot: EnrollmentSnapshot?
  private(set) var loadState = LoadState.idle
  private var refreshID = UUID()
  private(set) var serials: [String] = []
  var targetPolicyId: String?

  private let service: any EnrollmentServicing

  var targetPolicy: EnrollmentPolicy? {
    guard let policy = snapshot?.policy(id: targetPolicyId), policy.isAssignable else { return nil }
    return policy
  }

  // MARK: - Init

  init(service: any EnrollmentServicing) {
    self.service = service
  }

  // MARK: - Loading

  func refresh() async {
    let id = UUID()
    refreshID = id
    loadState = .loading
    do {
      let fetched = try await service.fetchSnapshot()
      try Task.checkCancellation()
      guard refreshID == id else { return }
      snapshot = fetched
      if targetPolicy == nil {
        targetPolicyId = nil
      }
      loadState = .loaded
    } catch {
      guard refreshID == id else { return }
      loadState = Task.isCancelled ? (snapshot == nil ? .idle : .loaded) : .failed(error.localizedDescription)
    }
  }

  // MARK: - Queue

  func add(serial: String) -> AddResult {
    guard let snapshot else { return .notLoaded }
    guard snapshot.devices[serial] != nil else { return .notEnrolled }
    guard !serials.contains(serial) else { return .alreadyListed }
    serials.append(serial)
    return .added
  }

  /// Queues every device currently assigned to the policy, or every device without one.
  func addDevices(policyId: String?) {
    guard let snapshot else { return }
    let listed = Set(serials)
    serials += snapshot.serials(policyId: policyId).filter { !listed.contains($0) }
  }

  /// Names a device together with its current policy, so that scanning shows where it is.
  func describe(serial: String, as label: String) -> String {
    guard let snapshot else { return label }
    return "\(label) (\(snapshot.policyDescription(serial: serial)))"
  }

  func remove(serial: String) {
    serials.removeAll { $0 == serial }
  }

  func clear() {
    serials.removeAll()
  }
}
