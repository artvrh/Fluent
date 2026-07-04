local httpService = game:GetService("HttpService")

local InterfaceManager = {}
do
	InterfaceManager.Folder = "FluentSettings"
	InterfaceManager.Settings = {
		Theme = "Dark",
		Acrylic = true,
		Transparency = true,
		MenuKeybind = "K",
	}

	function InterfaceManager:SetFolder(folder)
		self.Folder = folder
		self:BuildFolderTree()
	end

	function InterfaceManager:SetLibrary(library)
		self.Library = library
	end

	function InterfaceManager:BuildFolderTree()
		local paths = {}

		local parts = self.Folder:split("/")
		for idx = 1, #parts do
			paths[#paths + 1] = table.concat(parts, "/", 1, idx)
		end

		table.insert(paths, self.Folder)
		table.insert(paths, self.Folder .. "/settings")
		table.insert(paths, self.Folder .. "/button_configs")

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function InterfaceManager:SaveSettings()
		writefile(self.Folder .. "/options.json", httpService:JSONEncode(InterfaceManager.Settings))
	end

	function InterfaceManager:LoadSettings()
		local path = self.Folder .. "/options.json"
		if isfile(path) then
			local data = readfile(path)
			local success, decoded = pcall(httpService.JSONDecode, httpService, data)

			if success then
				for i, v in next, decoded do
					InterfaceManager.Settings[i] = v
				end
			end
		end
	end

	function InterfaceManager:SaveButtonConfig(name)
		if not name or name:gsub(" ", "") == "" then
			return false, "Invalid config name"
		end

		local ButtonManager = getgenv().ButtonManager
		if not ButtonManager or not ButtonManager.Buttons then
			return false, "ButtonManager not found or no buttons"
		end

		local data = {}
		for _, button in ipairs(ButtonManager.Buttons) do
			if button.DragFrame then
				local pos = button.DragFrame.Position
				data[button.Text] = {
					X = { Scale = pos.X.Scale, Offset = pos.X.Offset },
					Y = { Scale = pos.Y.Scale, Offset = pos.Y.Offset },
				}
			end
		end

		local fullPath = self.Folder .. "/button_configs/" .. name .. ".json"
		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, "failed to encode data"
		end

		writefile(fullPath, encoded)
		return true
	end

	function InterfaceManager:LoadButtonConfig(name)
		if not name or name:gsub(" ", "") == "" then
			return false, "Invalid config name"
		end

		local file = self.Folder .. "/button_configs/" .. name .. ".json"
		if not isfile(file) then
			return false, "invalid file"
		end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then
			return false, "decode error"
		end

		local ButtonManager = getgenv().ButtonManager
		if not ButtonManager or not ButtonManager.Buttons then
			return false, "ButtonManager not found or no buttons"
		end

		local loadedCount = 0
		for _, button in ipairs(ButtonManager.Buttons) do
			local savedPos = decoded[button.Text]
			if savedPos and button.DragFrame then
				button.DragFrame.Position =
					UDim2.new(savedPos.X.Scale, savedPos.X.Offset, savedPos.Y.Scale, savedPos.Y.Offset)
				loadedCount = loadedCount + 1
			end
		end

		return true, loadedCount
	end

	function InterfaceManager:RefreshButtonConfigList()
		local path = self.Folder .. "/button_configs"
		if not isfolder(path) then
			return {}
		end

		local list = listfiles(path)
		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == ".json" then
				local pos = file:find(".json", 1, true)
				local start = pos

				local char = file:sub(pos, pos)
				while char ~= "/" and char ~= "\\" and char ~= "" do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == "/" or char == "\\" then
					local name = file:sub(pos + 1, start - 1)
					table.insert(out, name)
				end
			end
		end

		return out
	end

	function InterfaceManager:BuildInterfaceSection(tab)
		assert(self.Library, "Must set InterfaceManager.Library")
		local Library = self.Library
		local Settings = InterfaceManager.Settings

		InterfaceManager:LoadSettings()

		local section = tab:AddSection("Interface")

		local InterfaceTheme = section:AddDropdown("InterfaceTheme", {
			Title = "Theme",
			Description = "Changes the interface theme.",
			Values = Library.Themes,
			Default = Settings.Theme,
			Callback = function(Value)
				Library:SetTheme(Value)
				Settings.Theme = Value
				InterfaceManager:SaveSettings()
			end,
		})

		InterfaceTheme:SetValue(Settings.Theme)

		section:AddToggle("TransparentToggle", {
			Title = "Transparency",
			Description = "Makes the interface transparent.",
			Default = Settings.Transparency,
			Callback = function(Value)
				Library:ToggleTransparency(Value)
				Settings.Transparency = Value
				InterfaceManager:SaveSettings()
			end,
		})

		section:AddToggle("AcrylicToggle", {
			Title = "Acrylic",
			Description = "Enables the blur effect behind the interface.",
			Default = Settings.Acrylic,
			Callback = function(Value)
				Library:ToggleAcrylic(Value)
				Settings.Acrylic = Value
				InterfaceManager:SaveSettings()
			end,
		})

		local MenuKeybind =
			section:AddKeybind("MenuKeybind", { Title = "Minimize Bind", Default = Settings.MenuKeybind })
		MenuKeybind:OnChanged(function()
			Settings.MenuKeybind = MenuKeybind.Value
			InterfaceManager:SaveSettings()
		end)
		Library.MinimizeKeybind = MenuKeybind

		-- Button Configuration Section
		local buttonSection = tab:AddSection("Button Configuration")

		local configNameInput = buttonSection:AddInput("ButtonConfig_Name", {
			Title = "Config Name",
		})

		local configListDropdown = buttonSection:AddDropdown("ButtonConfig_List", {
			Title = "Config List",
			Values = InterfaceManager:RefreshButtonConfigList(),
			AllowNull = true,
		})

		buttonSection:AddButton({
			Title = "Overwrite Config",
			Callback = function()
				local name = configListDropdown.Value
				if not name or name == "" then
					return Library:Notify({
						Title = "Button Config",
						Content = "No config selected to overwrite",
						Duration = 5,
					})
				end

				local success, err = InterfaceManager:SaveButtonConfig(name)
				if not success then
					return Library:Notify({
						Title = "Button Config",
						Content = "Failed to overwrite config: " .. tostring(err),
						Duration = 5,
					})
				end

				Library:Notify({
					Title = "Button Config",
					Content = string.format("Successfully overwrote config %q", name),
					Duration = 5,
				})
			end,
		})

		buttonSection:AddButton({
			Title = "Save Config",
			Callback = function()
				local name = configNameInput.Value
				if name:gsub(" ", "") == "" then
					return Library:Notify({
						Title = "Button Config",
						Content = "Invalid config name (empty)",
						Duration = 5,
					})
				end

				local success, err = InterfaceManager:SaveButtonConfig(name)
				if not success then
					return Library:Notify({
						Title = "Button Config",
						Content = "Failed to save button positions: " .. tostring(err),
						Duration = 5,
					})
				end

				Library:Notify({
					Title = "Button Config",
					Content = string.format("Successfully saved config %q", name),
					Duration = 5,
				})

				configListDropdown:SetValues(InterfaceManager:RefreshButtonConfigList())
				configListDropdown:SetValue(nil)
			end,
		})

		buttonSection:AddButton({
			Title = "Load Config",
			Callback = function()
				local name = configListDropdown.Value
				if not name or name == "" then
					return Library:Notify({
						Title = "Button Config",
						Content = "No config selected to load",
						Duration = 5,
					})
				end

				local success, err = InterfaceManager:LoadButtonConfig(name)
				if not success then
					return Library:Notify({
						Title = "Button Config",
						Content = "Failed to load config: " .. tostring(err),
						Duration = 5,
					})
				end

				Library:Notify({
					Title = "Button Config",
					Content = string.format("Successfully loaded config %q", name),
					Duration = 5,
				})
			end,
		})

		-- Ignore these settings in the main config saving
		local SaveManager = getgenv().SaveManager
		if SaveManager and SaveManager.SetIgnoreIndexes then
			SaveManager:SetIgnoreIndexes({ "ButtonConfig_Name", "ButtonConfig_List" })
		end
	end
end

return InterfaceManager
