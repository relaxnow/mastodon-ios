//
//  DataSourceFacade+Follow.swift
//  Mastodon
//
//  Created by MainasuK on 2022-1-24.
//

import UIKit
import CoreDataStack

extension DataSourceFacade {
    static func responseToUserFollowAction(
        dependency: NeedsDependency,
        user: ManagedObjectRecord<MastodonUser>,
        authenticationBox: MastodonAuthenticationBox
    ) async throws {
        let selectionFeedbackGenerator = UISelectionFeedbackGenerator()
        await selectionFeedbackGenerator.selectionChanged()
    
        _ = try await dependency.context.apiService.toggleFollow(
            user: user,
            authenticationBox: authenticationBox
        )
    }   // end func
}