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

		// Evaluate without observer management — no observers are
		// registered yet so there is nothing to remove and nothing
		// that could fire re-entrantly.
		self.PerformInputEvaluation()
		self.PerformOutputEvaluation()
		self.AddObservers()

		// An output switch above may cause macOS to silently hijack
		// the default input (same issue that EvaluateOutputPriority
		// handles). Schedule a delayed re-evaluation to correct it.
		self.ScheduleDelayedInputReEvaluation()
	}

	deinit
	{
		self.RemoveObservers()
	}
}

internal extension AirPodsObserver
{
	// Called from notification handlers — wraps evaluation with
	// observer teardown/setup to prevent re-entrant notifications.

	func EvaluateInputPriority()
	{
		self.RemoveObservers()
		self.PerformInputEvaluation()
		self.AddObservers()
	}

	func EvaluateOutputPriority()
	{
		self.RemoveObservers()
		self.PerformOutputEvaluation()
		self.AddObservers()

		// macOS may silently flip the default input to the headset mic
		// when we switch the output to a Bluetooth device. Because
		// observers were removed during the switch, that
		// defaultInputDeviceChanged notification was lost.
		// Re-evaluate input after a short delay to correct the hijack.
		self.ScheduleDelayedInputReEvaluation()
	}

	func EvaluateAllPriorities()
	{
		self.RemoveObservers()
		self.PerformInputEvaluation()
		self.PerformOutputEvaluation()
		self.AddObservers()

		// Same delayed re-evaluation: an output switch may trigger
		// a cascading input change that we need to catch.
		self.ScheduleDelayedInputReEvaluation()
	}
}

private extension AirPodsObserver
{
	// Core evaluation logic — does NOT manage observers.

	func PerformInputEvaluation()
	{
		let __PriorityList = self._Preferences.InputDevicePriority

		if __PriorityList.isEmpty
		{
			// Legacy fallback: no priority list configured.
			// Always track the last non-AirPods input device, even when
			// the sanitizer is disabled, so that re-enabling picks up
			// the correct fallback device.
			self.TrackLegacyInputDevice()

			if self._Preferences.IsEnabled
			{
				self.LegacyInputFallback()
			}
			return
		}

		if !self._Preferences.IsEnabled
		{
			return
		}

		let __AvailableDevices = self._Simply.allInputDevices
		guard let __DesiredDevice = self.FindHighestPriorityDevice(priorityList: __PriorityList, availableDevices: __AvailableDevices) else { return }
		guard let __CurrentDefault = self._Simply.defaultInputDevice else { return }

		if __CurrentDefault.id != __DesiredDevice.id
		{
			NSLog("AirPods Sanity: Switching input device from '\(__CurrentDefault.name)' to '\(__DesiredDevice.name)' (priority-based)")
			__DesiredDevice.isDefaultInputDevice = true
		}
	}

	func PerformOutputEvaluation()
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
			__DesiredDevice.isDefaultOutputDevice = true

			self.BoostSampleRateAfterDelay(device: __DesiredDevice)
		}
	}

	func ScheduleDelayedInputReEvaluation()
	{
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
		{
			self.EvaluateInputPriority()
		}
	}

	func TrackLegacyInputDevice()
	{
		guard let __DefaultInputDevice = self._Simply.defaultInputDevice else { return }

		// If the current default is NOT an AirPods device, remember it
		// as the safe fallback. This runs even when the sanitizer is
		// disabled so re-enabling picks up the correct device.
		let __AirPodsNames = self._Preferences.AirPodsDeviceNames
		if __AirPodsNames.first(where: { $0 == __DefaultInputDevice.name }) == nil
		{
			self._DefaultInputDeviceName = __DefaultInputDevice.name
		}
	}

	func LegacyInputFallback()
	{
		guard let __DefaultInputDevice = self._Simply.defaultInputDevice else { return }

		// If the current default is NOT an AirPods device, nothing to do.
		let __AirPodsNames = self._Preferences.AirPodsDeviceNames
		if __AirPodsNames.first(where: { $0 == __DefaultInputDevice.name }) == nil
		{
			return
		}

		// Current default IS an AirPods device — restore the previous
		// non-AirPods input (or the explicit InputDeviceName if set).
		guard let __NewInputDeviceName = self._Preferences.InputDeviceName ?? self._DefaultInputDeviceName else { return }
		guard let __InputDevice = self._Simply.allInputDevices.first(where: { $0.name == __NewInputDeviceName }) else { return }

		if __DefaultInputDevice.id != __InputDevice.id
		{
			__InputDevice.isDefaultInputDevice = true
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
