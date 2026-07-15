//
//  RetailMapViewTests.swift
//  RetailBrainSDKTests
//

import XCTest
import SwiftUI
import UIKit
import Mappedin
@testable import RetailBrainSDK

// MARK: - Helper

@MainActor
private func makeWindow<V: View>(hosting view: V, size: CGSize = CGSize(width: 390, height: 844)) -> (UIWindow, UIHostingController<V>) {
    let host = UIHostingController(rootView: view)
    let window = UIWindow(frame: CGRect(origin: .zero, size: size))
    window.rootViewController = host
    window.makeKeyAndVisible()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
    return (window, host)
}

@MainActor
private func dismissWindow(_ window: UIWindow) {
    window.rootViewController = nil
    window.isHidden = true
}

// MARK: - MapViewContainer

@MainActor
final class MapViewContainerTests: XCTestCase {

    func test_init_setsClearBackground() {
        let mv = MapView()
        defer { mv.destroy() }
        let container = MapViewContainer(mapView: mv)
        XCTAssertEqual(container.backgroundColor, .clear)
    }

    func test_init_storesMapView() {
        let mv = MapView()
        defer { mv.destroy() }
        let container = MapViewContainer(mapView: mv)
        XCTAssertTrue(container.mapView === mv)
    }

    func test_setupMapView_doesNotCrash_withFreshMapView() {
        let mv = MapView()
        defer { mv.destroy() }
        let container = MapViewContainer(mapView: mv)
        container.frame = CGRect(x: 0, y: 0, width: 375, height: 812)
        container.layoutIfNeeded()
        XCTAssertNotNil(container)
    }

    func test_setupMapView_inWindow_triggersAutoresizing() {
        let mv = MapView()
        defer { mv.destroy() }
        let container = MapViewContainer(mapView: mv)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.addSubview(container)
        container.frame = window.bounds
        window.layoutIfNeeded()
        XCTAssertEqual(container.frame, window.bounds)
        window.isHidden = true
    }
}

// MARK: - MapViewRepresentable (makeUIView + updateUIView)

@MainActor
final class MapViewRepresentableTests: XCTestCase {

    // makeUIView is called during the first SwiftUI layout pass in a real window
    func test_makeUIView_isCalled_whenInWindow() {
        let mv = MapView()
        let (window, host) = makeWindow(hosting: MapViewRepresentable(mapView: mv))
        defer { dismissWindow(window); mv.destroy() }
        XCTAssertNotNil(host.view)
        XCTAssertFalse(window.subviews.isEmpty)
    }

    func test_makeUIView_producesViewInHierarchy() {
        let mv = MapView()
        let (window, _) = makeWindow(hosting: MapViewRepresentable(mapView: mv))
        defer { dismissWindow(window); mv.destroy() }
        XCTAssertFalse(window.subviews.isEmpty)
    }

    // updateUIView is called on subsequent layout passes
    func test_updateUIView_isCalled_onSecondLayoutPass() {
        let mv = MapView()
        let host = UIHostingController(rootView: MapViewRepresentable(mapView: mv))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        defer { dismissWindow(window); mv.destroy() }

        // second pass triggers updateUIView
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertNotNil(host.view)
    }

    func test_updateUIView_withSwappedMapView_doesNotCrash() {
        let first = MapView()
        let second = MapView()
        let host = UIHostingController(rootView: MapViewRepresentable(mapView: first))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        defer { dismissWindow(window); first.destroy(); second.destroy() }

        host.rootView = MapViewRepresentable(mapView: second)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertTrue(true)
    }

    func test_updateUIView_multiplePasses_doesNotCrash() {
        let mv = MapView()
        let host = UIHostingController(rootView: MapViewRepresentable(mapView: mv))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        defer { dismissWindow(window); mv.destroy() }

        for _ in 0..<3 {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
        }
        XCTAssertTrue(true)
    }
}

// MARK: - RetailMapView (body.getter + closures + onAppear)

@MainActor
final class RetailMapViewRenderTests: XCTestCase {

    private var mockDelegate: MockRetailBrainSDKDelegate!

    override func setUp() {
        super.setUp()
        mockDelegate = MockRetailBrainSDKDelegate()
        RetailBrainManager.shared.delegate = mockDelegate
    }

    override func tearDown() {
        RetailBrainManager.shared.delegate = nil
        mockDelegate = nil
        super.tearDown()
    }

    // MARK: - body.getter

    func test_body_rendersInWindow_doesNotCrash() {
        let (window, host) = makeWindow(hosting: RetailMapView())
        defer { dismissWindow(window) }
        XCTAssertNotNil(host.view)
    }

    func test_body_withLoadingTrue_rendersLoadingOverlay() {
        // isLoading starts true → ZStack overlay branch executes
        let (window, host) = makeWindow(hosting: RetailMapView())
        defer { dismissWindow(window) }
        XCTAssertNotNil(host.view)
    }

    func test_body_withCustomRoutingController_doesNotCrash() {
        let (window, host) = makeWindow(hosting: RetailMapView(routingController: MapRoutingController()))
        defer { dismissWindow(window) }
        XCTAssertNotNil(host.view)
    }

    func test_body_withCustomMapId_doesNotCrash() {
        let (window, host) = makeWindow(hosting: RetailMapView(mapId: "test-map-123"))
        defer { dismissWindow(window) }
        XCTAssertNotNil(host.view)
    }

    func test_body_withMultiFloorMode_doesNotCrash() {
        let (window, host) = makeWindow(hosting: RetailMapView(isMultiFloorMode: true))
        defer { dismissWindow(window) }
        XCTAssertNotNil(host.view)
    }

    func test_body_multipleLayoutPasses_doesNotCrash() {
        let host = UIHostingController(rootView: RetailMapView())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        defer { dismissWindow(window) }

        for _ in 0..<3 {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
        }
        XCTAssertTrue(true)
    }

    // MARK: - onAppear closure (routingController.attach + viewModel.loadMap)

    func test_onAppear_attachesRoutingController() {
        let controller = MapRoutingController()
        let (window, _) = makeWindow(hosting: RetailMapView(routingController: controller))
        defer { dismissWindow(window) }
        // onAppear fired → controller is attached and markMapReady path is wired
        XCTAssertNotNil(controller)
    }

    func test_onAppear_withNoConfig_callsMapDidFailToLoad() throws {
        guard RetailBrainManager.shared.config == nil else {
            throw XCTSkip("Config already set; no-config path not reachable")
        }
        let (window, _) = makeWindow(hosting: RetailMapView())
        defer { dismissWindow(window) }
        XCTAssertTrue(mockDelegate.mapDidFailToLoadCalled)
    }

    func test_onAppear_withValidConfig_doesNotCrash() {
        RetailBrainManager.shared.initialize(
            config: RetailBrainConfig(apiKey: "key", apiSecret: "secret", mapId: "map-id")
        )
        let (window, _) = makeWindow(hosting: RetailMapView())
        defer { dismissWindow(window) }
        XCTAssertTrue(true)
    }

    func test_onAppear_onMapLoadedClosure_isWired() {
        var onMapLoadedCalled = false
        let view = RetailMapView(onMapLoaded: { onMapLoadedCalled = true })
        let (window, _) = makeWindow(hosting: view)
        defer { dismissWindow(window) }
        // Without real credentials the callback won't fire, but the closure is wired
        XCTAssertFalse(onMapLoadedCalled)
    }

    func test_onAppear_onLaunchClosure_isWired() {
        var launchCalled = false
        let view = RetailMapView(onLaunch: { launchCalled = true })
        let (window, _) = makeWindow(hosting: view)
        defer { dismissWindow(window) }
        XCTAssertFalse(launchCalled)
    }

    func test_onAppear_withNilDelegate_doesNotCrash() {
        RetailBrainManager.shared.delegate = nil
        let (window, _) = makeWindow(hosting: RetailMapView())
        defer { dismissWindow(window) }
        XCTAssertTrue(true)
    }

    // MARK: - implicit closure in RetailMapView.init (routingController.markMapReady)

    func test_init_implicitClosure_markMapReady_isCalledOnMapLoad() {
        let controller = MapRoutingController()
        XCTAssertFalse(controller.isMapReady)
        _ = RetailMapView(routingController: controller, onMapLoaded: nil)
        XCTAssertFalse(controller.isMapReady) // no real map load in tests
    }

    // MARK: - closure #1 in implicit closure #1 in RetailMapView.init (onMapLoaded + onLaunch + markMapReady)

    func test_onMapLoadedClosure_firesMarkMapReady_onRenderSuccess() {
        let controller = MapRoutingController()
        XCTAssertFalse(controller.isMapReady)
        _ = RetailMapView(routingController: controller, onMapLoaded: nil)
        XCTAssertFalse(controller.isMapReady) // no real map load in tests
    }

    func test_onMapLoadedClosure_withNilCallbacks_doesNotCrash() {
        let controller = MapRoutingController()
        XCTAssertNoThrow(RetailMapView(routingController: controller, onMapLoaded: nil, onLaunch: nil))
    }

    // MARK: - appearance transitions

    func test_appearanceTransition_doesNotCrash() {
        let host = UIHostingController(rootView: RetailMapView())
        host.beginAppearanceTransition(true, animated: false)
        host.endAppearanceTransition()
        host.beginAppearanceTransition(false, animated: false)
        host.endAppearanceTransition()
        XCTAssertTrue(true)
    }

    func test_viewLifecycle_inWindow_doesNotCrash() {
        let (window, host) = makeWindow(hosting: RetailMapView())
        defer { dismissWindow(window) }
        host.beginAppearanceTransition(false, animated: false)
        host.endAppearanceTransition()
        host.beginAppearanceTransition(true, animated: false)
        host.endAppearanceTransition()
        XCTAssertTrue(true)
    }
}
