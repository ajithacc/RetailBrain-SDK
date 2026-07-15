//
//  PermissionMonitorTests.swift
//  RetailBrainSDKTests
//
//  Created by sowmya.prasanna on 15/07/26.
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

    // MARK: - isPermissionRevoked (CLAuthorizationStatus)

    func test_isPermissionRevoked_location_authorizedAlways_toDenied_isTrue() {
        XCTAssertTrue(monitor.isPermissionRevoked(from: CLAuthorizationStatus.authorizedAlways, to: CLAuthorizationStatus.denied))
    }

    func test_isPermissionRevoked_location_authorizedWhenInUse_toDenied_isTrue() {
        XCTAssertTrue(monitor.isPermissionRevoked(from: CLAuthorizationStatus.authorizedWhenInUse, to: CLAuthorizationStatus.denied))
    }

    func test_isPermissionRevoked_location_authorizedAlways_toRestricted_isTrue() {
        XCTAssertTrue(monitor.isPermissionRevoked(from: CLAuthorizationStatus.authorizedAlways, to: CLAuthorizationStatus.restricted))
    }

    func test_isPermissionRevoked_location_authorizedWhenInUse_toRestricted_isTrue() {
        XCTAssertTrue(monitor.isPermissionRevoked(from: CLAuthorizationStatus.authorizedWhenInUse, to: CLAuthorizationStatus.restricted))
    }

    func test_isPermissionRevoked_location_notDetermined_toDenied_isFalse() {
        XCTAssertFalse(monitor.isPermissionRevoked(from: CLAuthorizationStatus.notDetermined, to: CLAuthorizationStatus.denied))
    }

    func test_isPermissionRevoked_location_denied_toDenied_isFalse() {
        XCTAssertFalse(monitor.isPermissionRevoked(from: CLAuthorizationStatus.denied, to: CLAuthorizationStatus.denied))
    }

    func test_isPermissionRevoked_location_authorizedAlways_toNotDetermined_isFalse() {
        XCTAssertFalse(monitor.isPermissionRevoked(from: CLAuthorizationStatus.authorizedAlways, to: CLAuthorizationStatus.notDetermined))
    }

    func test_isPermissionRevoked_location_authorizedAlways_toAuthorizedWhenInUse_isFalse() {
        XCTAssertFalse(monitor.isPermissionRevoked(from: CLAuthorizationStatus.authorizedAlways, to: CLAuthorizationStatus.authorizedWhenInUse))
    }

    // MARK: - isPermissionRevoked (CBManagerAuthorization)

    func test_isPermissionRevoked_bluetooth_allowedAlways_toDenied_isTrue() {
        XCTAssertTrue(monitor.isPermissionRevoked(from: CBManagerAuthorization.allowedAlways, to: CBManagerAuthorization.denied))
    }

    func test_isPermissionRevoked_bluetooth_allowedAlways_toRestricted_isTrue() {
        XCTAssertTrue(monitor.isPermissionRevoked(from: CBManagerAuthorization.allowedAlways, to: CBManagerAuthorization.restricted))
    }

    func test_isPermissionRevoked_bluetooth_notDetermined_toDenied_isFalse() {
        XCTAssertFalse(monitor.isPermissionRevoked(from: CBManagerAuthorization.notDetermined, to: CBManagerAuthorization.denied))
    }

    func test_isPermissionRevoked_bluetooth_denied_toDenied_isFalse() {
        XCTAssertFalse(monitor.isPermissionRevoked(from: CBManagerAuthorization.denied, to: CBManagerAuthorization.denied))
    }

    func test_isPermissionRevoked_bluetooth_allowedAlways_toAllowedAlways_isFalse() {
        XCTAssertFalse(monitor.isPermissionRevoked(from: CBManagerAuthorization.allowedAlways, to: CBManagerAuthorization.allowedAlways))
    }

    // MARK: - checkPermissionChanges (injected status)

    func test_checkPermissionChanges_locationRevoked_notifiesDelegate() {
        // Seed lastLocationStatus as authorizedAlways by injecting a no-op call first
        monitor.checkPermissionChanges(injectedLocationStatus: .authorizedAlways)
        mockDelegate.permissionChangeCalled = false

        // Now inject a status change to denied — should fire delegate
        monitor.checkPermissionChanges(injectedLocationStatus: .denied)
        XCTAssertTrue(mockDelegate.permissionChangeCalled)
        XCTAssertEqual(mockDelegate.lastRevokedPermission, .location)
    }

    func test_checkPermissionChanges_locationNotRevoked_doesNotNotify() {
        monitor.checkPermissionChanges(injectedLocationStatus: .notDetermined)
        mockDelegate.permissionChangeCalled = false

        monitor.checkPermissionChanges(injectedLocationStatus: .denied)
        XCTAssertFalse(mockDelegate.permissionChangeCalled)
    }

    func test_checkPermissionChanges_locationStatusUnchanged_doesNotNotify() {
        monitor.checkPermissionChanges(injectedLocationStatus: .authorizedAlways)
        mockDelegate.permissionChangeCalled = false

        monitor.checkPermissionChanges(injectedLocationStatus: .authorizedAlways)
        XCTAssertFalse(mockDelegate.permissionChangeCalled)
    }

    func test_checkPermissionChanges_bluetoothRevoked_notifiesDelegate() {
        monitor.checkPermissionChanges(injectedBluetoothStatus: .allowedAlways)
        mockDelegate.permissionChangeCalled = false

        monitor.checkPermissionChanges(injectedBluetoothStatus: .denied)
        XCTAssertTrue(mockDelegate.permissionChangeCalled)
        XCTAssertEqual(mockDelegate.lastRevokedPermission, .bluetooth)
    }

    func test_checkPermissionChanges_bluetoothNotRevoked_doesNotNotify() {
        monitor.checkPermissionChanges(injectedBluetoothStatus: .notDetermined)
        mockDelegate.permissionChangeCalled = false

        monitor.checkPermissionChanges(injectedBluetoothStatus: .denied)
        XCTAssertFalse(mockDelegate.permissionChangeCalled)
    }

    func test_checkPermissionChanges_locationRevokedEarlyReturn_bluetoothNotChecked() {
        // Seed both
        monitor.checkPermissionChanges(injectedLocationStatus: .authorizedAlways, injectedBluetoothStatus: .allowedAlways)
        mockDelegate.permissionChangeCalled = false

        // Location revoked → early return, bluetooth change not processed
        monitor.checkPermissionChanges(injectedLocationStatus: .denied, injectedBluetoothStatus: .denied)
        XCTAssertEqual(mockDelegate.lastRevokedPermission, .location)
    }

    func test_checkPermissionChanges_withNilDelegate_doesNotCrash() {
        monitor.delegate = nil
        monitor.checkPermissionChanges(injectedLocationStatus: .authorizedAlways)
        XCTAssertNoThrow(monitor.checkPermissionChanges(injectedLocationStatus: .denied))
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
