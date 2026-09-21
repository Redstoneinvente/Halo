/// Describes how this Halo binary is distributed.
///
/// Keep compile-condition checks in this file. The rest of Halo should ask for
/// a capability instead of branching on `HALO_DIRECT` or `HALO_APPSTORE`.
enum HaloDistribution: String, CaseIterable, Sendable {
    case direct
    case appStore

    static let current: HaloDistribution = {
#if HALO_DIRECT && HALO_APPSTORE
#error("Halo cannot be built with both HALO_DIRECT and HALO_APPSTORE.")
#elseif HALO_DIRECT
        return .direct
#elseif HALO_APPSTORE
        return .appStore
#else
#error("Halo must be built with either HALO_DIRECT or HALO_APPSTORE.")
#endif
    }()

    var capabilities: HaloDistributionCapabilities {
        switch self {
        case .direct:
            return HaloDistributionCapabilities(
                supportsSparkle: true,
                supportsExternalLicensing: true,
                supportsUnrestrictedFileAccess: true,
                supportsPartnerIntegrations: true
            )
        case .appStore:
            return HaloDistributionCapabilities(
                supportsSparkle: false,
                supportsExternalLicensing: false,
                supportsUnrestrictedFileAccess: false,
                supportsPartnerIntegrations: false
            )
        }
    }

    var supportsSparkle: Bool { capabilities.supportsSparkle }
    var supportsExternalLicensing: Bool { capabilities.supportsExternalLicensing }
    var supportsUnrestrictedFileAccess: Bool { capabilities.supportsUnrestrictedFileAccess }
    var supportsPartnerIntegrations: Bool { capabilities.supportsPartnerIntegrations }
}

/// Distribution-sensitive capabilities exposed to the rest of Halo.
///
/// These are deliberately capability-oriented. If App Store policy or Halo's
/// implementation changes later, update the mapping above without rewriting
/// feature call sites.
struct HaloDistributionCapabilities: Equatable, Sendable {
    let supportsSparkle: Bool
    let supportsExternalLicensing: Bool
    let supportsUnrestrictedFileAccess: Bool
    let supportsPartnerIntegrations: Bool
}
