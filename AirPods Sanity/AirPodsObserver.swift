//
//  ObservableSCA.swift
//  AirPods Sanity
//
//  Created by Tobias Punke on 25.08.22.
//

import Foundation
import SimplyCoreAudio

class AirPodsObserver: ObservableObject
{
	private let _Preferences: Preferences
	private let _Simply: SimplyCoreAudio
	private let _NotificationCenter: NotificationCenter

	private var _Observers: [NSObjectProtocol]

	// Legacy fallback: tracks the last known non-AirPods input device
	// so users without an explicit InputDevicePriority still get sanitized.
	private var _DefaultInputDeviceName: String?

	init()
	{
		self._Preferences = Preferences.Instance
		self._Simply = SimplyCoreAudio()
		self._NotificationCenter = NotificationCenter.default
		self._Observers = []

		self.EvaluateInputPriority()
		self.EvaluateOutputPriority()
		self.AddObservers()
	}

	deinit
	{
		self.RemoveObservers()
	}
}

internal extension AirPodsObserver
{
	func EvaluateInputPriority()
	{
		if !self._Preferences.IsEnabled
		{
			return
		}

		let __PriorityList = self._Preferences.InputDevicePriority

		if __PriorityList.isEmpty
		{
			// Legacy fallback: no priority list configured.
			// Replicate main-branch behavior: remember the last non-AirPods
			// input device and restore it when AirPods hijack the input.
			self.LegacyInputFallback()
			return
		}

		let __AvailableDevices = self._Simply.allInputDevices
		guard let __DesiredDevice = self.FindHighestPriorityDevice(priorityList: __PriorityList, availableDevices: __AvailableDevices) else { return }
		guard let __CurrentDefault = self._Simply.defaultInputDevice else { return }

		if __CurrentDefault.id != __DesiredDevice.id
		{
			NSLog("AirPods Sanity: Switching input device from '\(__CurrentDefault.name)' to '\(__DesiredDevice.name)' (priority-based)")

			self.RemoveObservers()
			__DesiredDevice.isDefaultInputDevice = true
			self.AddObservers()
		}
	}

	func EvaluateOutputPriority()
	{
		if !self._Preferences.IsEnabled
		{
			return
		}

		let __PriorityList = self._Preferences.OutputDevicePriority

		guard !__PriorityList.isEmpty else { return }

		let __AvailableDevices = self._Simply.allOutputDevices
		guard let __DesiredDevice = self.FindHighestPriorityDevice(priorityList: __PriorityList, availableDevices: __AvailableDevices) else { return }
		guard let __CurrentDefault = self._Simply.defaultOutputDevice else { return }

		if __CurrentDefault.id != __DesiredDevice.id
		{
			NSLog("AirPods Sanity: Switching output device from '\(__CurrentDefault.name)' to '\(__DesiredDevice.name)' (priority-based)")

			self.RemoveObservers()
			__DesiredDevice.isDefaultOutputDevice = true
			self.AddObservers()

			self.BoostSampleRateAfterDelay(device: __DesiredDevice)
		}
	}

	func EvaluateAllPriorities()
	{
		self.EvaluateInputPriority()
		self.EvaluateOutputPriority()
	}
}

private extension AirPodsObserver
{
	func LegacyInputFallback()
	{
		guard let __DefaultInputDevice = self._Simply.defaultInputDevice else { return }

		// If the current default is NOT an AirPods device, remember it
		// as the safe fallback.
		let __AirPodsNames = self._Preferences.AirPodsDeviceNames
		if __AirPodsNames.first(where: { $0 == __DefaultInputDevice.name }) == nil
		{
			self._DefaultInputDeviceName = __DefaultInputDevice.name
			return
		}

		// Current default IS an AirPods device — restore the previous
		// non-AirPods input (or the explicit InputDeviceName if set).
		guard let __NewInputDeviceName = self._Preferences.InputDeviceName ?? self._DefaultInputDeviceName else { return }
		guard let __InputDevice = self._Simply.allInputDevices.first(where: { $0.name == __NewInputDeviceName }) else { return }

		if __DefaultInputDevice.id != __InputDevice.id
		{
			self.RemoveObservers()
			__InputDevice.isDefaultInputDevice = true
			self.AddObservers()
		}

		let __Seconds = 10.0

		DispatchQueue.main.asyncAfter(deadline: .now() + __Seconds)
		{
			guard let __DefaultOutputDevice = self._Simply.defaultOutputDevice else { return }
			guard let __SampleRates = __DefaultOutputDevice.nominalSampleRates?.sorted(by: { $0 > $1 }) else { return }
			guard !__SampleRates.isEmpty else { return }

			self.RemoveObservers()
			__DefaultOutputDevice.setNominalSampleRate(__SampleRates[0])
			self.AddObservers()
		}
	}

	func FindHighestPriorityDevice(priorityList: [String], availableDevices: [AudioDevice]) -> AudioDevice?
	{
		for __DeviceName in priorityList
		{
			if let __Device = availableDevices.first(where: { $0.name == __DeviceName })
			{
				return __Device
			}
		}

		return nil
	}

	func BoostSampleRateAfterDelay(device: AudioDevice)
	{
		let __Seconds = 10.0

		DispatchQueue.main.asyncAfter(deadline: .now() + __Seconds)
		{
			guard let __SampleRates = device.nominalSampleRates?.sorted(by: { $0 > $1 }) else { return }
			guard !__SampleRates.isEmpty else { return }

			self.RemoveObservers()
			device.setNominalSampleRate(__SampleRates[0])
			self.AddObservers()
		}
	}

	func AddObservers()
	{
		self._Observers.append(contentsOf:[
			self._NotificationCenter.addObserver(forName: .defaultInputDeviceChanged, object: nil, queue: .main) { (_) in
				self.EvaluateInputPriority()
			},
			self._NotificationCenter.addObserver(forName: .defaultOutputDeviceChanged, object: nil, queue: .main) { (_) in
				self.EvaluateOutputPriority()
			},
			self._NotificationCenter.addObserver(forName: .deviceListChanged, object: nil, queue: .main) { (_) in
				self.EvaluateAllPriorities()
			},
			self._NotificationCenter.addObserver(forName: .priorityListChanged, object: nil, queue: .main) { (_) in
				self.EvaluateAllPriorities()
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
