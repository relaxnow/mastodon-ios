//
//  AuthenticationViewModel.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021/2/1.
//

import os.log
import UIKit
import CoreData
import CoreDataStack
import Combine
import MastodonSDK

final class AuthenticationViewModel {
    
    var disposeBag = Set<AnyCancellable>()
    
    // input
    let context: AppContext
    let coordinator: SceneCoordinator
    let isAuthenticationExist: Bool
    let input = CurrentValueSubject<String, Never>("")
    
    // output
    let viewHierarchyShouldReset: Bool
    let domain = CurrentValueSubject<String?, Never>(nil)
    let isSignInButtonEnabled = CurrentValueSubject<Bool, Never>(false)
    let isAuthenticating = CurrentValueSubject<Bool, Never>(false)
    let authenticated = PassthroughSubject<(domain: String, account: Mastodon.Entity.Account), Never>()
    let error = CurrentValueSubject<Error?, Never>(nil)
    
    var mastodonPinBasedAuthenticationViewController: UIViewController?
    
    init(context: AppContext, coordinator: SceneCoordinator, isAuthenticationExist: Bool) {
        self.context = context
        self.coordinator = coordinator
        self.isAuthenticationExist = isAuthenticationExist
        self.viewHierarchyShouldReset = isAuthenticationExist
        
        input
            .map { input in
                let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !trimmed.isEmpty else { return nil }
                
                let urlString = trimmed.hasPrefix("https://") ? trimmed : "https://" + trimmed
                guard let url = URL(string: urlString),
                      let host = url.host else {
                    return nil
                }
                let components = host.components(separatedBy: ".")
                guard !components.contains(where: { $0.isEmpty }) else { return nil }
                guard components.count >= 2 else { return nil }
                
                os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: iput host: %s", ((#file as NSString).lastPathComponent), #line, #function, host)

                return host
            }
            .assign(to: \.value, on: domain)
            .store(in: &disposeBag)
        
        domain
            .map { $0 != nil }
            .assign(to: \.value, on: isSignInButtonEnabled)
            .store(in: &disposeBag)
    }
    
}

extension AuthenticationViewModel {
    
    struct AuthenticateInfo {
        let domain: String
        let clientID: String
        let clientSecret: String
        let url: URL
    }
    
    func authenticate(info: AuthenticateInfo, pinCodePublisher: PassthroughSubject<String, Never>) {
        pinCodePublisher
            .handleEvents(receiveOutput: { [weak self] _ in
                guard let self = self else { return }
                self.isAuthenticating.value = true
                self.mastodonPinBasedAuthenticationViewController?.dismiss(animated: true, completion: nil)
                self.mastodonPinBasedAuthenticationViewController = nil
            })
            .compactMap { [weak self] code -> AnyPublisher<Mastodon.Response.Content<Mastodon.Entity.Account>, Error>? in
                guard let self = self else { return nil }
                return self.context.apiService
                    .userAccessToken(
                        domain: info.domain,
                        clientID: info.clientID,
                        clientSecret: info.clientSecret,
                        code: code
                    )
                    .flatMap { response -> AnyPublisher<Mastodon.Response.Content<Mastodon.Entity.Account>, Error> in
                        let token = response.value
                        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: sign in success. Token: %s", ((#file as NSString).lastPathComponent), #line, #function, token.accessToken)
                        return AuthenticationViewModel.verifyAndSaveAuthentication(
                            context: self.context,
                            info: info,
                            userToken: token
                        )
                    }
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                switch completion {
                case .failure(let error):
                    os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: swap user access token swap fail: %s", ((#file as NSString).lastPathComponent), #line, #function, error.localizedDescription)
                    self.isAuthenticating.value = false
                    self.error.value = error
                case .finished:
                    break
                }
            } receiveValue: { [weak self] response in
                guard let self = self else { return }
                let account = response.value
                os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: user %s sign in success", ((#file as NSString).lastPathComponent), #line, #function, account.username)
                
                self.authenticated.send((domain: info.domain, account: account))
            }
            .store(in: &self.disposeBag)
    }
    
    static func verifyAndSaveAuthentication(
        context: AppContext,
        info: AuthenticateInfo,
        userToken: Mastodon.Entity.Token
    ) -> AnyPublisher<Mastodon.Response.Content<Mastodon.Entity.Account>, Error> {
        let authorization = Mastodon.API.OAuth.Authorization(accessToken: userToken.accessToken)
        let managedObjectContext = context.backgroundManagedObjectContext

        return context.apiService.accountVerifyCredentials(
            domain: info.domain,
            authorization: authorization
        )
        .flatMap { response -> AnyPublisher<Mastodon.Response.Content<Mastodon.Entity.Account>, Error> in
            let account = response.value
            let mastodonUserRequest = MastodonUser.sortedFetchRequest
            mastodonUserRequest.predicate = MastodonUser.predicate(domain: info.domain, id: account.id)
            mastodonUserRequest.fetchLimit = 1
            guard let mastodonUser = try? managedObjectContext.fetch(mastodonUserRequest).first else {
                return Fail(error: APIService.APIError.explicit(.badCredentials)).eraseToAnyPublisher()
            }
            
            let property = MastodonAuthentication.Property(
                domain: info.domain,
                userID: mastodonUser.id,
                username: mastodonUser.username,
                appAccessToken: userToken.accessToken,  // TODO: swap app token
                userAccessToken: userToken.accessToken,
                clientID: info.clientID,
                clientSecret: info.clientSecret
            )
            return managedObjectContext.performChanges {
                _ = APIService.CoreData.createOrMergeMastodonAuthentication(
                    into: managedObjectContext,
                    for: mastodonUser,
                    in: info.domain,
                    property: property,
                    networkDate: response.networkDate
                )
            }
            .setFailureType(to: Error.self)
            .tryMap { result in
                switch result {
                case .failure(let error):   throw error
                case .success:              return response
                }
            }
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
    
}