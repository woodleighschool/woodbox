#if os(iOS)
  import SwiftUI
  import UIKit

  /// SwiftUI exposes the refresh action, but not programmatic presentation of its native control.
  struct RefreshControlPresentation: UIViewControllerRepresentable {
    let isRefreshing: Bool
    let isEnabled: Bool

    func makeUIViewController(context _: Context) -> RefreshControlPresenter {
      RefreshControlPresenter()
    }

    func updateUIViewController(_ controller: RefreshControlPresenter, context _: Context) {
      controller.isRefreshing = isRefreshing
      controller.isEnabled = isEnabled
      controller.updateRefreshControl()
    }
  }

  final class RefreshControlPresenter: UIViewController {
    var isRefreshing = false
    var isEnabled = true
    private var isVisible = false
    private var presentedProgrammatically = false
    private weak var scrollView: UIScrollView?

    override func loadView() {
      view = UIView()
      view.isUserInteractionEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      isVisible = true
      updateRefreshControl()
    }

    override func viewWillDisappear(_ animated: Bool) {
      super.viewWillDisappear(animated)
      isVisible = false
      if presentedProgrammatically {
        scrollView?.refreshControl?.endRefreshing()
        presentedProgrammatically = false
      }
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      updateRefreshControl()
    }

    func updateRefreshControl() {
      // Beginning during a navigation transition leaves UIKit's refresh inset in the new layout.
      guard isVisible, view.window != nil else { return }
      if scrollView?.window != view.window {
        scrollView = findScrollView()
      }
      guard let scrollView, let control = scrollView.refreshControl else { return }
      control.isEnabled = isEnabled
      if isRefreshing, !control.isRefreshing {
        let top = -scrollView.adjustedContentInset.top
        let isAtTop = scrollView.contentOffset.y <= top + 1
        control.beginRefreshing()
        presentedProgrammatically = true
        // Reveal updates at the top without moving someone who is reading further down.
        if isAtTop, !scrollView.isDragging, !scrollView.isDecelerating {
          control.sizeToFit()
          scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: top - control.bounds.height), animated: true)
        }
      } else if !isRefreshing, presentedProgrammatically {
        control.endRefreshing()
        presentedProgrammatically = false
      }
    }

    private func findScrollView() -> UIScrollView? {
      var ancestor = view.superview
      while let container = ancestor, !(container is UIWindow) {
        if let scrollView = refreshableScrollView(in: container) {
          return scrollView
        }
        // Stay inside this screen's hosting controller during navigation and sheet transitions.
        if container.next is UIViewController {
          break
        }
        ancestor = container.superview
      }
      return nil
    }

    private func refreshableScrollView(in container: UIView) -> UIScrollView? {
      guard container !== view, !container.isHidden else { return nil }
      if let scrollView = container as? UIScrollView, scrollView.refreshControl != nil {
        return scrollView
      }
      return container.subviews.lazy.compactMap { self.refreshableScrollView(in: $0) }.first
    }
  }
#endif
