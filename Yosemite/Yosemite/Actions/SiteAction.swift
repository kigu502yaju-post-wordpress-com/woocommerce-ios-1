import Foundation

/// SiteAction: Defines all of the Actions supported by the SiteStore.
///
public enum SiteAction: Action {
    /// Creates a site in the store creation flow.
    /// - Parameters:
    ///   - name: The name of the site.
    ///   - domain: Domain name selected for the site.
    ///   - completion: The result of site creation.
    case createSite(name: String,
                    domain: String,
                    completion: (Result<SiteCreationResult, SiteCreationError>) -> Void)

    /// Launches a site publicly through WPCOM.
    /// - Parameter:
    ///   - siteID: ID of the site to launch.
    ///   - completion: Called when the result of site launch is available.
    case launchSite(siteID: Int64, completion: (Result<Void, SiteLaunchError>) -> Void)
}

/// The result of site creation including necessary site information.
public struct SiteCreationResult: Equatable {
    public let siteID: Int64
    public let name: String
    public let url: String
    public let siteSlug: String
}
