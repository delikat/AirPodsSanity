//
// Created by Tobias Punke on 27.08.22.
//

import AppKit
import Foundation
import LaunchAtLogin
import SimplyCoreAudio

class MenuBar
{
	private let _SimplyCoreAudio: SimplyCoreAudio
	private let _Preferences: Preferences

	private var _InputDeviceItems: [NSMenuItem]
	private var _OutputDeviceItems: [NSMenuItem]

	private var _StatusBarItem: NSStatusItem

	init()
	{
		self._SimplyCoreAudio = SimplyCoreAudio()
		self._Preferences = Preferences.Instance

		self._InputDeviceItems = []
		self._OutputDeviceItems = []

		self._StatusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

		self.CreateStatusItem()
		self.SetShowInMenuBar()
		self.SetShowInDock()
	}

	private func CreateStatusItem()
	{
		let __Image = NSImage(named: "airpods-icon")

		__Image?.isTemplate = true

		if let __Button = self._StatusBarItem.button
		{
			__Button.toolTip = NSLocalizedString("MenuBar.ToolTip", comment: "")

			if __Image != nil
			{
				__Button.image = __Image
			}
			else
			{
				__Button.title = NSLocalizedString("MenuBar.ToolTip", comment: "")
			}
		}
	}

	public func CreateMenu()
	{
		self._InputDeviceItems.removeAll()
		self._InputDeviceItems = self.CreateInputPriorityItems(simply: self._SimplyCoreAudio, preferences: self._Preferences)

		self._OutputDeviceItems.removeAll()
		self._OutputDeviceItems = self.CreateOutputPriorityItems(simply: self._SimplyCoreAudio, preferences: self._Preferences)

		let __Menu = NSMenu()

		__Menu.addItem(self.CreateIsEnabledItem(preferences: self._Preferences))

		__Menu.addItem(NSMenuItem.separator())
		__Menu.addItem(self.CreateLaunchOnLoginItem(preferences: self._Preferences))
		__Menu.addItem(self.CreateShowInMenuBarItem(preferences: self._Preferences))
		__Menu.addItem(self.CreateShowInDockItem(preferences: self._Preferences))

		__Menu.addItem(NSMenuItem.separator())
		self.AddItems(menu: __Menu, items: self._InputDeviceItems, label: NSLocalizedString("MenuBar.InputDevices", comment: ""))

		__Menu.addItem(NSMenuItem.separator())
		self.AddItems(menu: __Menu, items: self._OutputDeviceItems, label: NSLocalizedString("MenuBar.OutputDevices", comment: ""))

		__Menu.addItem(NSMenuItem.separator())
		__Menu.addItem(self.CreateQuitApplicationItem())
		
		self.SetShowInMenuBar()
		self._StatusBarItem.menu = __Menu
	}
	
	public var IsVisible: Bool
	{
		get
		{
			return self._StatusBarItem.isVisible
		}
	}
	
	public func Show()
	{
		self._StatusBarItem.isVisible = true;
	}
	
	public func Hide()
	{
		self._StatusBarItem.isVisible = false;
	}
	
	private func SetShowInMenuBar()
	{
		self._StatusBarItem.isVisible = self._Preferences.ShowInMenuBar
	}
	
	private func SetLaunchOnLogin()
	{
		LaunchAtLogin.isEnabled = self._Preferences.LaunchOnLogin
	}
	
	private func SetShowInDock()
	{
		let __Preferences = self._Preferences

		if __Preferences.ShowInDock
		{
			// The application is an ordinary app that appears in the Dock and may
			// have a user interface.
			NSApp.setActivationPolicy(.regular)
		}
		else
		{
			// The application does not appear in the Dock and may not create
			// windows or be activated.
			NSApp.setActivationPolicy(.prohibited)
		}
	}
	
	private func CreateLaunchOnLoginItem(preferences: Preferences) -> NSMenuItem
	{
		let __MenuItem = NSMenuItem()

		__MenuItem.title = NSLocalizedString("MenuBar.LaunchOnLogin", comment: "")
		__MenuItem.target = self
		__MenuItem.action = #selector(OnToggleLaunchOnLogin(_:))

		if preferences.LaunchOnLogin
		{
			__MenuItem.state = NSControl.StateValue.on
		}
		else
		{
			__MenuItem.state = NSControl.StateValue.off
		}

		return __MenuItem
	}
	
	private func CreateShowInMenuBarItem(preferences: Preferences) -> NSMenuItem
	{
		let __MenuItem = NSMenuItem()

		__MenuItem.title = NSLocalizedString("MenuBar.ShowInMenuBar", comment: "")
		__MenuItem.target = self
		__MenuItem.action = #selector(OnToggleShowInMenuBar(_:))

		if preferences.ShowInMenuBar
		{
			__MenuItem.state = NSControl.StateValue.on
		}
		else
		{
			__MenuItem.state = NSControl.StateValue.off
		}

		return __MenuItem
	}

	private func CreateShowInDockItem(preferences: Preferences) -> NSMenuItem
	{
		let __MenuItem = NSMenuItem()

		__MenuItem.title = NSLocalizedString("MenuBar.ShowInDock", comment: "")
		__MenuItem.target = self
		__MenuItem.action = #selector(OnToggleShowInDock(_:))

		if preferences.ShowInDock
		{
			__MenuItem.state = NSControl.StateValue.on
		}
		else
		{
			__MenuItem.state = NSControl.StateValue.off
		}

		return __MenuItem
	}

	private func CreateIsEnabledItem(preferences: Preferences) -> NSMenuItem
	{
		let __MenuItem = NSMenuItem()

		__MenuItem.title = NSLocalizedString("MenuBar.IsEnabled", comment: "")
		__MenuItem.target = self
		__MenuItem.action = #selector(OnToggleIsEnabled(_:))

		if preferences.IsEnabled
		{
			__MenuItem.state = NSControl.StateValue.on
		}
		else
		{
			__MenuItem.state = NSControl.StateValue.off
		}

		return __MenuItem
	}

	private func CreateQuitApplicationItem() -> NSMenuItem
	{
		let __QuitLabel = NSLocalizedString("MenuBar.Quit", comment: "")
		let __QuitShortcut = NSLocalizedString("MenuBar.QuitShortcut", comment: "")

		return NSMenuItem(title: __QuitLabel, action: #selector(NSApplication.terminate(_:)), keyEquivalent: __QuitShortcut)
	}

	// MARK: - Priority-based Device Items

	private func CreateInputPriorityItems(simply: SimplyCoreAudio, preferences: Preferences) -> [NSMenuItem]
	{
		let __AllDevices = simply.allInputDevices
		let __PriorityList = preferences.InputDevicePriority
		let __DefaultDevice = simply.defaultInputDevice

		return self.CreatePriorityDeviceItems(
			allDevices: __AllDevices,
			priorityList: __PriorityList,
			activeDeviceName: __DefaultDevice?.name,
			isInput: true
		)
	}

	private func CreateOutputPriorityItems(simply: SimplyCoreAudio, preferences: Preferences) -> [NSMenuItem]
	{
		let __AllDevices = simply.allOutputDevices
		let __PriorityList = preferences.OutputDevicePriority
		let __DefaultDevice = simply.defaultOutputDevice

		return self.CreatePriorityDeviceItems(
			allDevices: __AllDevices,
			priorityList: __PriorityList,
			activeDeviceName: __DefaultDevice?.name,
			isInput: false
		)
	}

	private func CreatePriorityDeviceItems(allDevices: [AudioDevice], priorityList: [String], activeDeviceName: String?, isInput: Bool) -> [NSMenuItem]
	{
		var __MenuItems: [NSMenuItem] = []
		let __AllDeviceNames = Set(allDevices.map { $0.name })

		// Show priority-listed devices first, in priority order
		for (index, deviceName) in priorityList.enumerated()
		{
			let __IsAvailable = __AllDeviceNames.contains(deviceName)
			let __IsActive = deviceName == activeDeviceName
			let __Rank = index + 1

			let __MenuItem = NSMenuItem()

			if __IsAvailable
			{
				__MenuItem.title = "#\(__Rank) \(deviceName)"
			}
			else
			{
				__MenuItem.title = "#\(__Rank) \(deviceName) (\(NSLocalizedString("MenuBar.Disconnected", comment: "")))"
			}

			if __IsActive
			{
				__MenuItem.state = NSControl.StateValue.on
			}

			// Submenu with Move Up / Move Down / Remove
			let __SubMenu = NSMenu()

			if index > 0
			{
				let __MoveUp = NSMenuItem()
				__MoveUp.title = NSLocalizedString("MenuBar.MoveUp", comment: "")
				__MoveUp.target = self
				__MoveUp.representedObject = PriorityAction(deviceName: deviceName, isInput: isInput, action: .moveUp)
				__MoveUp.action = #selector(OnPriorityAction(_:))
				__SubMenu.addItem(__MoveUp)
			}

			if index < priorityList.count - 1
			{
				let __MoveDown = NSMenuItem()
				__MoveDown.title = NSLocalizedString("MenuBar.MoveDown", comment: "")
				__MoveDown.target = self
				__MoveDown.representedObject = PriorityAction(deviceName: deviceName, isInput: isInput, action: .moveDown)
				__MoveDown.action = #selector(OnPriorityAction(_:))
				__SubMenu.addItem(__MoveDown)
			}

			__SubMenu.addItem(NSMenuItem.separator())

			let __Remove = NSMenuItem()
			__Remove.title = NSLocalizedString("MenuBar.RemoveFromPriority", comment: "")
			__Remove.target = self
			__Remove.representedObject = PriorityAction(deviceName: deviceName, isInput: isInput, action: .remove)
			__Remove.action = #selector(OnPriorityAction(_:))
			__SubMenu.addItem(__Remove)

			__MenuItem.submenu = __SubMenu

			__MenuItems.append(__MenuItem)
		}

		// Show unranked devices (available but not in priority list)
		let __PrioritySet = Set(priorityList)
		let __UnrankedDevices = allDevices.filter { !__PrioritySet.contains($0.name) }.sorted(by: { $0.name < $1.name })

		if !__UnrankedDevices.isEmpty
		{
			let __Separator = NSMenuItem.separator()
			__MenuItems.append(__Separator)

			for __AudioDevice in __UnrankedDevices
			{
				let __MenuItem = NSMenuItem()
				__MenuItem.title = "  \(__AudioDevice.name)"

				if __AudioDevice.name == activeDeviceName
				{
					__MenuItem.state = NSControl.StateValue.on
				}

				// Submenu with Add to Priority List
				let __SubMenu = NSMenu()
				let __Add = NSMenuItem()
				__Add.title = NSLocalizedString("MenuBar.AddToPriority", comment: "")
				__Add.target = self
				__Add.representedObject = PriorityAction(deviceName: __AudioDevice.name, isInput: isInput, action: .add)
				__Add.action = #selector(OnPriorityAction(_:))
				__SubMenu.addItem(__Add)

				__MenuItem.submenu = __SubMenu

				__MenuItems.append(__MenuItem)
			}
		}

		return __MenuItems
	}

	private func AddItems(menu: NSMenu, items: [NSMenuItem], label: String)
	{
		let __Label = NSMenuItem()

		__Label.title = label
		__Label.isEnabled = false

		menu.addItem(__Label)

		for __MenuItem in items
		{
			menu.addItem(__MenuItem)
		}
	}
	
	// MARK: - Toggle Actions

	@objc private func OnToggleLaunchOnLogin(_ sender: NSMenuItem)
	{
		let __Preferences = self._Preferences
		let __State = sender.state

		if __State == NSControl.StateValue.on
		{
			__Preferences.LaunchOnLogin = false
			sender.state = NSControl.StateValue.off
		}
		else if __State == NSControl.StateValue.off
		{
			__Preferences.LaunchOnLogin = true
			sender.state = NSControl.StateValue.on
		}

		self.SetLaunchOnLogin()

		self._Preferences.WriteSettings()
	}
	
	@objc private func OnToggleShowInMenuBar(_ sender: NSMenuItem)
	{
		let __Preferences = self._Preferences
		let __State = sender.state

		if __State == NSControl.StateValue.on
		{
			__Preferences.ShowInMenuBar = false
			sender.state = NSControl.StateValue.off
		}
		else if __State == NSControl.StateValue.off
		{
			__Preferences.ShowInMenuBar = true
			sender.state = NSControl.StateValue.on
		}

		self.SetShowInMenuBar()
		
		self._Preferences.WriteSettings()
	}

	@objc private func OnToggleShowInDock(_ sender: NSMenuItem)
	{
		let __Preferences = self._Preferences
		let __State = sender.state

		if __State == NSControl.StateValue.on
		{
			__Preferences.ShowInDock = false
			sender.state = NSControl.StateValue.off
		}
		else if __State == NSControl.StateValue.off
		{
			__Preferences.ShowInDock = true
			sender.state = NSControl.StateValue.on
		}

		self.SetShowInDock()
		
		self._Preferences.WriteSettings()
	}

	@objc private func OnToggleIsEnabled(_ sender: NSMenuItem)
	{
		let __Preferences = self._Preferences
		let __State = sender.state

		if __State == NSControl.StateValue.on
		{
			__Preferences.IsEnabled = false
			sender.state = NSControl.StateValue.off
		}
		else if __State == NSControl.StateValue.off
		{
			__Preferences.IsEnabled = true
			sender.state = NSControl.StateValue.on
		}
		
		self._Preferences.WriteSettings()
	}

	// MARK: - Priority Actions

	@objc private func OnPriorityAction(_ sender: NSMenuItem)
	{
		guard let __Action = sender.representedObject as? PriorityAction else { return }

		var __PriorityList = __Action.isInput ? self._Preferences.InputDevicePriority : self._Preferences.OutputDevicePriority

		switch __Action.action
		{
		case .moveUp:
			if let __Index = __PriorityList.firstIndex(of: __Action.deviceName), __Index > 0
			{
				__PriorityList.swapAt(__Index, __Index - 1)
			}

		case .moveDown:
			if let __Index = __PriorityList.firstIndex(of: __Action.deviceName), __Index < __PriorityList.count - 1
			{
				__PriorityList.swapAt(__Index, __Index + 1)
			}

		case .add:
			if !__PriorityList.contains(__Action.deviceName)
			{
				__PriorityList.append(__Action.deviceName)
			}

		case .remove:
			__PriorityList.removeAll { $0 == __Action.deviceName }
		}

		if __Action.isInput
		{
			self._Preferences.InputDevicePriority = __PriorityList
		}
		else
		{
			self._Preferences.OutputDevicePriority = __PriorityList
		}

		self._Preferences.WriteSettings()
		self.CreateMenu()

		// Post notification so AirPodsObserver re-evaluates priorities
		NotificationCenter.default.post(name: .priorityListChanged, object: nil)
	}
}

// MARK: - Supporting Types

private enum PriorityActionType
{
	case moveUp
	case moveDown
	case add
	case remove
}

private class PriorityAction: NSObject
{
	let deviceName: String
	let isInput: Bool
	let action: PriorityActionType

	init(deviceName: String, isInput: Bool, action: PriorityActionType)
	{
		self.deviceName = deviceName
		self.isInput = isInput
		self.action = action
	}
}

// MARK: - Custom Notification Name

extension Notification.Name
{
	static let priorityListChanged = Notification.Name("eu.punke.AirPods-Sanity.PriorityListChanged")
}
