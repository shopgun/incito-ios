//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

public protocol IncitoLoaderViewControllerDelegate: IncitoViewControllerDelegate {
    /**
     If you wish to customize the viewcontroller used to show the error state when loading the incito, implement this delegate method and return a view controller showing an error view.
     */
    func errorViewController(for error: Error, in viewController: IncitoLoaderViewController) -> UIViewController
    
    /**
     If you wish to customize the viewcontroller used to show the loading activity when loading the incito, implement this delegate method and return a view controller showing a loading view. If you do not implement this method a default viewcontroller showing a loading spinner will be used.
     */
    func loadingViewController(in viewController: IncitoLoaderViewController) -> UIViewController
    
    func stateDidChange(from oldState: IncitoLoaderViewController.State, to newState: IncitoLoaderViewController.State, in viewController: IncitoLoaderViewController)
}

public extension IncitoLoaderViewControllerDelegate {
    func errorViewController(for error: Error, in viewController: IncitoLoaderViewController) -> UIViewController {
        return buildDefaultErrorViewController(for: error, backgroundColor: viewController.view.backgroundColor ?? .white) { [weak viewController] in
            guard let loader = viewController?.lastLoader else { return }
            viewController?.reload(loader, completion: viewController?.lastReloadCompletion)
        }
    }
    
    func loadingViewController(in viewController: IncitoLoaderViewController) -> UIViewController {
         return DefaultLoadingViewController.build(backgroundColor: viewController.view.backgroundColor ?? .white)
    }
    
    func stateDidChange(from oldState: IncitoLoaderViewController.State, to newState: IncitoLoaderViewController.State, in viewController: IncitoLoaderViewController) { }
}

/**
 A utility view controller that allows for an incito to be loaded asyncronously, using an IncitoLoader. It shows loading/error views depending on the loading process.
 */
open class IncitoLoaderViewController: UIViewController {
    
    public enum State: Equatable {
        case loading
        case success(IncitoViewController)
        case error(Error)
        
        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading):
                return true
            case let (.success(lhsVC), .success(rhsVC)):
                return lhsVC === rhsVC
            case let (.error(lhsErr), .error(rhsErr)):
                return lhsErr.localizedDescription == rhsErr.localizedDescription
            default:
                return false
            }
        }
        
        public var isSuccess: Bool {
            if case .success = self {
                return true
            } else {
                return false
            }
        }
    }
    
    public fileprivate(set) var state: State = .loading {
        didSet {
            updateViewState()
            
            if state != oldValue {                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.stateDidChange(
                        from: oldValue,
                        to: self.state,
                        in: self
                    )
                }
            }
        }
    }

    public weak var delegate: IncitoLoaderViewControllerDelegate?
    
    public var incitoViewController: IncitoViewController? {
        guard case let .success(incitoVC) = self.state else {
            return nil
        }
        return incitoVC
    }
    
    public var isLoading: Bool {
        if case .loading = self.state {
            return true
        } else {
            return false
        }
    }
    
    fileprivate var reloadId: Int = 0
    fileprivate var lastLoader: IncitoLoader?
    fileprivate var lastReloadCompletion: ((Result<IncitoViewController>) -> Void)?
    fileprivate var loaderQueue = DispatchQueue(label: "IncitoLoaderQueue", qos: .userInitiated)
    
    fileprivate var currentStateViewController: UIViewController?
    fileprivate var stateContainerView = UIView()

    override open func viewDidLoad() {
        super.viewDidLoad()
        
        stateContainerView.frame = self.view.bounds
        stateContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(stateContainerView)
        
        updateViewState()
    }
    
    /**
     Given an IncitoLoader, we will start reloading the IncitoViewController.
     */
    public func reload(_ loader: IncitoLoader, completion: ((Result<IncitoViewController>) -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.state = .loading
            self.lastLoader = loader
            self.lastReloadCompletion = completion
            
            self.reloadId += 1
            let currReloadId = self.reloadId
            
            loader
                .async(on: self.loaderQueue, completesOn: .main)
                .run({ [weak self] renderableDocResult in
                    guard let self = self else { return }
                    guard self.reloadId == currReloadId else { return }
                    
                    switch renderableDocResult {
                    case let .error(err):
                        self.state = .error(err)                        
                        completion?(.error(err))
                    case let .success(renderableDocument):
                        
                        let incitoVC = IncitoViewController()
                        incitoVC.delegate = self.delegate
                        incitoVC.update(renderableDocument: renderableDocument)
                        
                        self.state = .success(incitoVC)
                        
                        completion?(.success(incitoVC))
                    }
                })
        }
    }
    
    private func updateViewState() {
        
        class DefaultDelegate: IncitoLoaderViewControllerDelegate {}
        let delegate: IncitoLoaderViewControllerDelegate = self.delegate ?? DefaultDelegate()
        
        let oldVC = currentStateViewController
        
        let newVC: UIViewController
        switch state {
        case .loading:
            newVC = delegate.loadingViewController(in: self)
        case .error(let error):
            newVC = delegate.errorViewController(for: error, in: self)
        case .success(let incitoVC):
            newVC = incitoVC
        }
        
        self.currentStateViewController = newVC
        
        self.cycleFromViewController(
            oldViewController: oldVC,
            toViewController: newVC,
            in: stateContainerView
        )
    }
}

extension UIViewController {
    func cycleFromViewController(oldViewController: UIViewController?, toViewController newViewController: UIViewController, in container: UIView? = nil) {
        
        newViewController.view.translatesAutoresizingMaskIntoConstraints = false
        self.addChild(newViewController)
        self.addSubview(
            subView: newViewController.view,
            toView: container ?? self.view
        )
        
        newViewController.view.layoutIfNeeded()
        
        guard let oldVC = oldViewController else {
            newViewController.didMove(toParent: self)
            newViewController.view.alpha = 1
            return
        }
        
        oldVC.willMove(toParent: nil)
        newViewController.view.alpha = 0
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .transitionCrossDissolve, animations: {
            newViewController.view.alpha = 1
            oldVC.view.alpha = 0
        }) { (finished) in
            oldVC.view.removeFromSuperview()
            oldVC.removeFromParent()
            newViewController.didMove(toParent: self)
        }
    }
    
    private func addSubview(subView: UIView, toView parentView: UIView) {
        self.view.layoutIfNeeded()
        parentView.addSubview(subView)
        
        NSLayoutConstraint.activate([
            subView.topAnchor.constraint(equalTo: parentView.topAnchor),
            subView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
            subView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            subView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor)
            ])
    }
}
