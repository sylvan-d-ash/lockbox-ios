/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import RxSwift
import RxCocoa
import FxAClient
import SwiftyJSON
import SwiftKeychainWrapper
import WebKit

enum KeychainKey: String {
    // note: these additional keys are holdovers from the previous Lockbox-owned style of
    // authentication
    case email, displayName, avatarURL, accountJSON

    static let allValues: [KeychainKey] = [.accountJSON, .email, .displayName, .avatarURL]
}

class AccountStore {
    static let shared = AccountStore()

    private var dispatcher: Dispatcher
    private var keychainWrapper: KeychainWrapper
    private var urlCache: URLCache
    private var webData: WKWebsiteDataStore
    private let disposeBag = DisposeBag()

    private var fxa: FirefoxAccount?

    private var _loginURL = ReplaySubject<URL>.create(bufferSize: 1)
    private var _profile = ReplaySubject<Profile?>.create(bufferSize: 1)
    private var _oauthInfo = ReplaySubject<OAuthInfo?>.create(bufferSize: 1)

    public var loginURL: Observable<URL> {
        return _loginURL.asObservable()
    }

    public var profile: Observable<Profile?> {
        return _profile.asObservable()
    }

    public var oauthInfo: Observable<OAuthInfo?> {
        return _oauthInfo.asObservable()
    }

    init(dispatcher: Dispatcher = Dispatcher.shared,
         keychainWrapper: KeychainWrapper = KeychainWrapper.standard,
         urlCache: URLCache = URLCache.shared,
         webData: WKWebsiteDataStore = WKWebsiteDataStore.default()
    ) {
        self.dispatcher = dispatcher
        self.keychainWrapper = keychainWrapper
        self.urlCache = urlCache
        self.webData = webData

        self.dispatcher.register
                .filterByType(class: AccountAction.self)
                .subscribe(onNext: { action in
                    switch action {
                    case .oauthRedirect(let url):
                        self.oauthLogin(url)
                    case .clear:
                        self.clear()
                    }
                })
                .disposed(by: self.disposeBag)

        if let accountJSON = self.keychainWrapper.string(forKey: KeychainKey.accountJSON.rawValue) {
            self.fxa = try? FirefoxAccount.fromJSON(state: accountJSON)
            self.generateLoginURL()
            self.populateAccountInformation()
        } else {
            FxAConfig.release { (config: FxAConfig?, _) in
                if let config = config {
                   self.fxa = try? FirefoxAccount(
                           config: config,
                           clientId: Constant.fxa.clientID,
                           redirectUri: Constant.fxa.redirectURI)

                    self.generateLoginURL()
                    self.populateAccountInformation()
                }
            }
        }
    }
}

extension AccountStore {
    private func generateLoginURL() {
        self.fxa?.beginOAuthFlow(scopes: Constant.fxa.scopes, wantsKeys: true) { url, _ in
            if let url = url {
                self._loginURL.onNext(url)
            }
        }
    }

    private func populateAccountInformation() {
        self.fxa?.getOAuthToken(scopes: Constant.fxa.scopes) { (info: OAuthInfo?, _) in
            self._oauthInfo.onNext(info)
        }

        self.fxa?.getProfile { (profile: Profile?, _) in
            self._profile.onNext(profile)
        }
    }

    private func clear() {
        for identifier in KeychainKey.allValues {
            _ = self.keychainWrapper.removeObject(forKey: identifier.rawValue)
        }

        self.webData.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            self.webData.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) { }
        }

        self.urlCache.removeAllCachedResponses()

        self._profile.onNext(nil)
        self._oauthInfo.onNext(nil)
    }

    private func oauthLogin(_ navigationURL: URL) {
        guard let components = URLComponents(url: navigationURL, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else {
            return
        }

        var dic = [String: String]()
        queryItems.forEach {
            dic[$0.name] = $0.value
        }

        guard let code = dic["code"],
              let state = dic["state"] else {
            return
        }

        self.fxa?.completeOAuthFlow(code: code, state: state) { (info: OAuthInfo?, _) in
            self._oauthInfo.onNext(info)

            if let opt = try? self.fxa?.toJSON(), let accountJSON = opt {
                self.keychainWrapper.set(accountJSON, forKey: KeychainKey.accountJSON.rawValue)
            }

            self.fxa?.getProfile { (profile: Profile?, _) in
                self._profile.onNext(profile)
            }
        }

    }
}
