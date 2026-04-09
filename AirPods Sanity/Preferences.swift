//
// Created by Tobias Punke on 27.08.22.
//

import Foundation

class Preferences
{
	private static var _Instance: Preferences?
	private let _PreferencesFile: PreferencesFile

	private init()
	{
		self._PreferencesFile = PreferencesLoader.LoadSettings()
		self.MigrateIfNeeded()
	}
	
	static var Instance: Preferences
	{
		if _Instance == nil
		{
			_Instance = Preferences()
		}

		return _Instance!
	}
	
	public var LaunchOnLogin: Bool
	{
		get
		{
			if let __UnWrapped = self._PreferencesFile.LaunchOnLogin
			{
				return __UnWrapped
			}
			else
			{
				return false
			}
		}
		set(value)
		{
			self._PreferencesFile.LaunchOnLogin = value
		}
	}
	
	public var ShowInMenuBar: Bool
	{
		get
		{
			if let __UnWrapped = self._PreferencesFile.ShowInMenuBar
			{
				return __UnWrapped
			}
			else
			{
				return true
			}
		}
		set(value)
		{
			self._PreferencesFile.ShowInMenuBar = value
		}
	}
	
	public var ShowInDock: Bool
	{
		get
		{
			if let __UnWrapped = self._PreferencesFile.ShowInDock
			{
				return __UnWrapped
			}
			else
			{
				return false
			}
		}
		set(value)
		{
			self._PreferencesFile.ShowInDock = value
		}
	}
	
	public var IsEnabled: Bool
	{
		get
		{
			if let __UnWrapped = self._PreferencesFile.IsEnabled
			{
				return __UnWrapped
			}
			else
			{
				return true
			}
		}
		set(value)
		{
			self._PreferencesFile.IsEnabled = value
		}
	}
	
	public var InputDeviceName: String?
	{
		get
		{
			return self._PreferencesFile.InputDeviceName
		}
		set(value)
		{
			self._PreferencesFile.InputDeviceName = value
		}
	}
	
	public var AirPodsDeviceNames: [String]
	{
		get
		{
			if let __UnWrapped = self._PreferencesFile.AirPodsDeviceNames
			{
				return __UnWrapped
			}
			else
			{
				return []
			}
		}
		set(value)
		{
			self._PreferencesFile.AirPodsDeviceNames = value
		}
	}
	
	public var InputDevicePriority: [String]
	{
		get
		{
			if let __UnWrapped = self._PreferencesFile.InputDevicePriority
			{
				return __UnWrapped
			}
			else
			{
				return []
			}
		}
		set(value)
		{
			self._PreferencesFile.InputDevicePriority = value
		}
	}
	
	public var OutputDevicePriority: [String]
	{
		get
		{
			if let __UnWrapped = self._PreferencesFile.OutputDevicePriority
			{
				return __UnWrapped
			}
			else
			{
				return []
			}
		}
		set(value)
		{
			self._PreferencesFile.OutputDevicePriority = value
		}
	}
	
	public func WriteSettings()
	{
		PreferencesLoader.WriteSettings(preferences: self._PreferencesFile)
	}
	
	private func MigrateIfNeeded()
	{
		var __DidMigrate = false

		if self._PreferencesFile.InputDevicePriority == nil,
		   let __InputDeviceName = self._PreferencesFile.InputDeviceName
		{
			self._PreferencesFile.InputDevicePriority = [__InputDeviceName]
			__DidMigrate = true
		}

		if self._PreferencesFile.OutputDevicePriority == nil,
		   let __AirPodsDeviceNames = self._PreferencesFile.AirPodsDeviceNames,
		   !__AirPodsDeviceNames.isEmpty
		{
			self._PreferencesFile.OutputDevicePriority = __AirPodsDeviceNames
			__DidMigrate = true
		}

		if __DidMigrate
		{
			self.WriteSettings()
		}
	}
}
