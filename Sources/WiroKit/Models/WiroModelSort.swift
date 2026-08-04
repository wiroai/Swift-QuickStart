import Foundation

/// Field used to sort Wiro model search results.
public enum WiroModelSort: String, Sendable, Equatable, CaseIterable {
    /// Sorts by search relevance.
    case relevance
    /// Sorts by publication time.
    case time
    /// Sorts by the number of user ratings.
    case ratedUserCount
    /// Sorts by the number of comments.
    case commentCount
    /// Sorts by average user rating.
    case averagePoint

    /// Value sent to the Wiro API.
    public var apiValue: String {
        switch self {
        case .relevance: return "relevance"
        case .time: return "time"
        case .ratedUserCount: return "ratedusercount"
        case .commentCount: return "commentcount"
        case .averagePoint: return "averagepoint"
        }
    }
}

/// Direction used to order Wiro model search results.
public enum WiroSortOrder: String, Sendable, Equatable, CaseIterable {
    /// Sorts from the smallest or oldest value.
    case ascending
    /// Sorts from the largest or newest value.
    case descending

    /// Value sent to the Wiro API.
    public var apiValue: String {
        switch self {
        case .ascending: return "ASC"
        case .descending: return "DESC"
        }
    }
}
