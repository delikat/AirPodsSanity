//
//  ObservableSCA.swift
//  AirPods Sanity
//
//  Created by Tobias Punke on 25.08.22.
//

import Foundation
import SimplyCoreAudio

class DevicesObserver: ObservableObject
{
	let InputDevicesChanged = Event<[AudioDevice]>()
	let OutputDevicesChanged = Event<[AudioDevice]>()
	let DefaultDeviceChanged = Event<Void>()

	private let _Simply = SimplyCoreAudio()
	private var _Observers = [NSObjectProtocol]()
	private let _NotificationCenter = NotificationCenter.default
	private var _RefreshTimer: Timer?
	private var _RetryCount = 0
	private let _MaxRetries = 3

	init()
	{
		self.UpdateDefaultInputDevice()
		self.UpdateDefaultOutputDevice()
		self.UpdateDefaultSystemDevice()

		self.AddObservers()
		self.StartPeriodicRefresh()
	}

	deinit
	{
		self.RemoveObservers()
		self.StopPeriodicRefresh()
	}
}

internal extension DevicesObserver
{
	func UpdateDefaultInputDevice()
	{
		self.DefaultDeviceChanged.raise(data: ())
	}

	func UpdateDefaultOutputDevice()
	{
		self.DefaultDeviceChanged.raise(data: ())
	}

	func UpdateDefaultSystemDevice()
	{
	}

	private func OnDeviceListChanged()
	{
		self._RetryCount = 0
		self.RefreshDeviceListWithRetry()
	}
	
	private func RefreshDeviceListWithRetry()
	{
		let currentInputDevices = self._Simply.allInputDevices
		let currentOutputDevices = self._Simply.allOutputDevices
		
		// Debug logging to track device detection
		NSLog("AirPods Sanity: Device list refresh attempt \(self._RetryCount + 1)/\(self._MaxRetries + 1), found \(currentInputDevices.count) input devices, \(currentOutputDevices.count) output devices")
		
		self.InputDevicesChanged.raise(data: currentInputDevices)
		self.OutputDevicesChanged.raise(data: currentOutputDevices)
		
		// If we haven't reached max retries, schedule another attempt
		if self._RetryCount < self._MaxRetries {
			self._RetryCount += 1
			let delay = Double(self._RetryCount) * 0.5 // 0.5s, 1s, 1.5s delays
			
			DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
				self.RefreshDeviceListWithRetry()
			}
		}
	}
	
	private func StartPeriodicRefresh()
	{
		// Refresh device list every 30 seconds to catch missed devices
		self._RefreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
			NSLog("AirPods Sanity: Periodic device list refresh")
			self.InputDevicesChanged.raise(data: self._Simply.allInputDevices)
			self.OutputDevicesChanged.raise(data: self._Simply.allOutputDevices)
		}
	}
	
	private func StopPeriodicRefresh()
	{
		self._RefreshTimer?.invalidate()
		self._RefreshTimer = nil
	}

	func AddObservers()
	{
		self._Observers.append(contentsOf: [
			self._NotificationCenter.addObserver(forName: .deviceListChanged, object: nil, queue: .main) { (notification) in
				self.OnDeviceListChanged()
			},

			self._NotificationCenter.addObserver(forName: .defaultInputDeviceChanged, object: nil, queue: .main) { (_) in
				self.UpdateDefaultInputDevice()
			},

			self._NotificationCenter.addObserver(forName: .defaultOutputDeviceChanged, object: nil, queue: .main) { (_) in
				self.UpdateDefaultOutputDevice()
			},

			self._NotificationCenter.addObserver(forName: .defaultSystemOutputDeviceChanged, object: nil, queue: .main) { (_) in
				self.UpdateDefaultSystemDevice()
			},

			self._NotificationCenter.addObserver(forName: .deviceNominalSampleRateDidChange, object: nil, queue: .main) { (notification) in
			},

			self._NotificationCenter.addObserver(forName: .deviceClockSourceDidChange, object: nil, queue: .main) { (notification) in
			},
		])
	}

	func RemoveObservers()
	{
		for __Observer in self._Observers
		{
			self._NotificationCenter.removeObserver(__Observer)
		}

		self._Observers.removeAll()
	}
}
