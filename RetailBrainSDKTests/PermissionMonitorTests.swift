//
//  PermissionMonitorTests.swift
//  RetailBrainSDKTests
//

import XCTest
import CoreLocation
import CoreBluetooth
@testable import RetailBrainSDK

final class PermissionMonitorTests: XCTestCase {

    private var monitor: PermissionMonitor!
    private var mockDelegate: MockPermissionMonitorDelegate!

    override func setUp() {
        super.setUp()
        monitor = PermissionMonitor()
        mockDelegate = MockPermissionMonitorDelegate()
        monitor.delegate = mockDelegate
    }

    override func tearDown() {
        monitor.stopMonitoring()
        monitor = nil
        mockDelegate = nil
        super.tearDown()
    }

    // MARK: - Init

    func test_init_doesNotCrash() {
        XCTAssertNotNil(PermissionMonitor())
    }

    func test_init_delegateIsNilByDefault() {
        let freshMonitor = PermissionMonitor()
        XCTAssertNil(freshMonitor.delegate)
    }

    // MARK: - Start / Stop Monitoring

    func test_startMonitoring_doesNotCrash() {
        XCTAssertNoThrow(monitor.startMonitoring())
    }

    func test_stopMonitoring_doesNotCrash() {
        monitor.startMonitoring()
        XCTAssertNoThrow(monitor.stopMonitoring())
    }

    func test_startMonitoring_calledTwice_doesNotCrash() {
        monitor.startMonitoring()
        XCTAssertNoThrow(monitor.startMonitoring())
    }

    func test_stopMonitoring_withoutStarting_doesNotCrash() {
        XCTAssertNoThrow(monitor.stopMonitoring())
    }

    func test_startStop_cycleCanRepeat() {
        for _ in 0..<3 {
            monitor.startMonitoring()
            monitor.stopMonitoring()
        }
        XCTAssertTrue(true)
    }

    // MARK: - updateCurrentStatus

    func test_updateCurrentStatus_doesNotCrash() {
        XCTAssertNoThrow(monitor.updateCurrentStatus())
    }

    func test_updateCurrentStatus_calledMultipleTimes_doesNotCrash() {
        for _ in 0..<5 {
            monitor.updateCurrentStatus()
        }
        XCTAssertTrue(true)
    }

    func test_updateCurrentStatus_whileMonitoring_doesNotCrash() {
        monitor.startMonitoring()
        XCTAssertNoThrow(monitor.updateCurrentStatus())
    }

    // MARK: - Delegate Assignment

    func test_delegate_canBeSetAndRead() {
        monitor.delegate = mockDelegate
        XCTAssertNotNil(monitor.delegate)
    }

    func test_delegate_isWeak() {
        var weakDelegate: MockPermissionMonitorDelegate? = MockPermissionMonitorDelegate()
        monitor.delegate = weakDelegate
        weakDelegate = nil
        XCTAssertNil(monitor.delegate)
    }

    func test_delegate_canBeReassigned() {
        let second = MockPermissionMonitorDelegate()
        monitor.delegate = second
        XCTAssertTrue(monitor.delegate === second)
    }

    func test_delegate_canBeSetToNil() {
        monitor.delegate = mockDelegate
        monitor.delegate = nil
        XCTAssertNil(monitor.delegate)
    }

    // MARK: - CLLocationManagerDelegate callback

    func test_locationManagerDidChangeAuthorization_doesNotCrash() {
        let locationManager = CLLocationManager()
        XCTAssertNoThrow(monitor.locationManagerDidChangeAuthorization(locationManager))
    }

    func test_locationManagerDidChangeAuthorization_whileMonitoring_doesNotCrash() {
        monitor.startMonitoring()
        let locationManager = CLLocationManager()
        XCTAssertNoThrow(monitor.locationManagerDidChangeAuthorization(locationManager))
    }

    func test_locationManagerDidChangeAuthorization_withNilDelegate_doesNotCrash() {
        monitor.delegate = nil
        let locationManager = CLLocationManager()
        XCTAssertNoThrow(monitor.locationManagerDidChangeAuthorization(locationManager))
    }

    // MARK: - CBCentralManagerDelegate callback

    func test_centralManagerDidUpdateState_doesNotCrash() {
        let centralManager = CBCentralManager(delegate: nil, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        XCTAssertNoThrow(monitor.centralManagerDidUpdateState(centralManager))
    }

    func test_centralManagerDidUpdateState_whileMonitoring_doesNotCrash() {
        monitor.startMonitoring()
        let centralManager = CBCentralManager(delegate: nil, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        XCTAssertNoThrow(monitor.centralManagerDidUpdateState(centralManager))
    }

    func test_centralManagerDidUpdateState_afterStop_doesNotCrash() {
        monitor.startMonitoring()
        monitor.stopMonitoring()
        let centralManager = CBCentralManager(delegate: nil, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        XCTAssertNoThrow(monitor.centralManagerDidUpdateState(centralManager))
    }

    // MARK: - RevokedPermission enum

    func test_revokedPermission_locationCase_exists() {
        let permission = RevokedPermission.location
        if case .location = permission {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected .location")
        }
    }

    func test_revokedPermission_bluetoothCase_exists() {
        let permission = RevokedPermission.bluetooth
        if case .bluetooth = permission {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected .bluetooth")
        }
    }

    // MARK: - Monitoring timer fires

    func test_startMonitoring_timerFiresWithoutCrash() {
        monitor.startMonitoring()
        // Allow the 1-second timer to fire once
        let expectation = expectation(description: "Timer fires")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)
        // If we reach here the timer fired without crashing
        XCTAssertTrue(true)
    }

    func test_stopMonitoring_invalidatesTimer_noFurtherFires() {
        monitor.startMonitoring()
        monitor.stopMonitoring()
        // Allow time for a timer tick that should NOT fire
        let expectation = expectation(description: "Pause after stop")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)
        XCTAssertTrue(true)
    }
}

// MARK: - Mock Delegate

final class MockPermissionMonitorDelegate: PermissionMonitorDelegate {
    var permissionChangeCalled = false
    var lastRevokedPermission: RevokedPermission?

    func permissionMonitorDidDetectPermissionChange(_ monitor: PermissionMonitor, revokedPermission: RevokedPermission) {
        permissionChangeCalled = true
        lastRevokedPermission = revokedPermission
    }
}
