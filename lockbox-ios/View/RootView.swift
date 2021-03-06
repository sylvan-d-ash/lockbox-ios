/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
 // swiftlint:disable line_length

import UIKit

class RootView: UIViewController, RootViewProtocol {
    internal var presenter: RootPresenter?

    private var currentViewController: UINavigationController? {
        didSet {
            if let currentViewController = self.currentViewController {
                self.addChildViewController(currentViewController)
                currentViewController.view.frame = self.view.bounds
                self.view.addSubview(currentViewController.view)
                currentViewController.didMove(toParentViewController: self)

                if oldValue != nil {
                    self.view.sendSubview(toBack: currentViewController.view)
                }
            }

            guard let oldViewController = oldValue else {
                return
            }
            oldViewController.willMove(toParentViewController: nil)
            oldViewController.view.removeFromSuperview()
            oldViewController.removeFromParentViewController()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return self.currentViewController?.topViewController?.preferredStatusBarStyle ?? .lightContent
    }

    init() {
        super.init(nibName: nil, bundle: nil)
        self.presenter = RootPresenter(view: self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.presenter?.onViewReady()
    }

    func topViewIs<T: UIViewController>(_ type: T.Type) -> Bool {
        return self.currentViewController?.topViewController is T
    }

    func modalViewIs<T: UIViewController>(_ type: T.Type) -> Bool {
        return (self.currentViewController?.presentedViewController as? UINavigationController)?.topViewController is T
    }

    func mainStackIs<T: UINavigationController>(_ type: T.Type) -> Bool {
        return self.currentViewController is T
    }

    func modalStackIs<T: UINavigationController>(_ type: T.Type) -> Bool {
        return self.currentViewController?.presentedViewController is T
    }

    func startMainStack<T: UINavigationController>(_ type: T.Type) {
        self.currentViewController = type.init()
    }

    func startModalStack<T: UINavigationController>(_ navigationController: T) {
        self.currentViewController?.present(navigationController, animated: true)
    }

    func dismissModals() {
        self.currentViewController?.presentedViewController?.dismiss(animated: true, completion: nil)
    }

    func pushLoginView(view: LoginRouteAction) {
        switch view {
        case .welcome:
            self.currentViewController?.popToRootViewController(animated: true)
        case .fxa:
            self.currentViewController?.pushViewController(FxAView(), animated: true)
        case .onboardingConfirmation:
            if let onboardingConfirmationView = UIStoryboard(name: "OnboardingConfirmation", bundle: nil).instantiateViewController(withIdentifier: "onboardingconfirmation") as? OnboardingConfirmationView {
                self.currentViewController?.pushViewController(onboardingConfirmationView, animated: true)
            }
        }
    }

    func pushMainView(view: MainRouteAction) {
        switch view {
        case .list:
            self.currentViewController?.popToRootViewController(animated: true)
        case .detail(let id):
            if let itemDetailView = UIStoryboard(name: "ItemDetail", bundle: nil).instantiateViewController(withIdentifier: "itemdetailview") as? ItemDetailView {
                itemDetailView.itemId = id
                self.currentViewController?.pushViewController(itemDetailView, animated: true)
            }
        }
    }

    func pushSettingView(view: SettingRouteAction) {
        switch view {
        case .list:
            self.currentViewController?.popToRootViewController(animated: true)
        case .account:
            if let accountSettingView = UIStoryboard(name: "AccountSetting", bundle: nil).instantiateViewController(withIdentifier: "accountsetting") as? AccountSettingView {
                self.currentViewController?.pushViewController(accountSettingView, animated: true)
            }
        case .autoLock:
            self.currentViewController?.pushViewController(AutoLockSettingView(), animated: true)
        case .preferredBrowser:
            self.currentViewController?.pushViewController(PreferredBrowserSettingView(), animated: true)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
    }
}
