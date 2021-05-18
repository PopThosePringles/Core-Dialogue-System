local YOOTIL = require(script:GetCustomProperty("YOOTIL"))

local Dialogue_System_Common = require(script:GetCustomProperty("Dialogue_System_Common"))
local Dialogue_System_Events = require(script:GetCustomProperty("Dialogue_System_Events"))
local Dialogue_Player_Choice = require(script:GetCustomProperty("Dialogue_Player_Choice_Class"))

local local_player = Game.GetLocalPlayer()
local Conversation_Entry = {}

function Conversation_Entry:init()
	self.id = Dialogue_System_Common.get_prop(self.root, "id", false)
	self.text = Dialogue_System_Common.get_prop(self.root, "text", false)
	self.condition = Dialogue_System_Common.get_prop(self.root, "condition", false)
	self.event = Dialogue_System_Common.get_prop(self.root, "call_event", false)

	self.choices = {}
	self.entries = {}

	self.played = false
	self.clicked = false
	self.writing = false

	if(self.id <= 0) then
		Dialogue_System_Events.trigger("warning", "\"" .. self.root.name .. "\" needs a unique ID.")

		return
	end

	Dialogue_System_Events.on("left_button_clicked", function()
		if(self.writing) then
			self.clicked = true
		end
	end)

	self:build()
end

function Conversation_Entry:build()
	for index, entry in ipairs(self.root:GetChildren()) do
		if(string.find(entry.id, "Dialogue_Conversation_Entry")) then
			self.entries[#self.entries + 1] = Conversation_Entry:new(entry)
		elseif(string.find(entry.id, "Dialogue_Player_Choice")) then
			self.choices[#self.choices + 1] = Dialogue_Player_Choice:new(entry, Conversation_Entry)
		end
	end
end

function Conversation_Entry:play(dialogue_trigger, dialogue, text_obj, close, next, speaker, npc_name, choices_panel)
	next.visibility = Visibility.FORCE_OFF
	close.visibility = Visibility.FORCE_OFF
	
	self:clear_choices(choices_panel)

	local entry = Dialogue_System_Common.get_entry(self)

	if(entry == nil) then
		if(self:has_choices()) then
			self:show_choices(dialogue_trigger, dialogue, text_obj, close, next, speaker, npc_name, choices_panel)
		else
			next.visibility = Visibility.FORCE_OFF
			close.visibility = Visibility.FORCE_ON
		end
	else
		if(string.len(npc_name) > 0) then
			speaker.text = npc_name

			local size = speaker:ComputeApproximateSize()

			while(size == nil) do
				Task.Wait()
				size = speaker:ComputeApproximateSize()
			end

			speaker.parent.width = size.x + 20
			
			speaker.parent.visibility = Visibility.FORCE_ON
		end

		Dialogue_System_Common.write_text(entry, text_obj)
	end

	local method = nil

	if(entry ~= nil) then
		self:call_event()

		if(not entry:has_choices() and not entry:has_entries()) then
			next.visibility = Visibility.FORCE_OFF
			close.visibility = Visibility.FORCE_ON
		else
			entry:set_played(true)

			next.visibility = Visibility.FORCE_ON
			
			method = entry.play

			local fired = false

			next.clickedEvent:Connect(function()
				if(not fired) then
					fired = true
					method(entry, dialogue_trigger, dialogue, text_obj, close, next, speaker, npc_name, choices_panel)
				end
			end)
		end
	end

	Dialogue_System_Events.on("left_button_clicked", function(evt_id)
		Dialogue_System_Events.off(evt_id)

		if(Object.IsValid(dialogue)) then
			if(close.visibility ~= Visibility.FORCE_OFF) then
				dialogue:Destroy()
				self:enable_player_controls()
				dialogue_trigger.isInteractable = true
			elseif(next.visibility ~= Visibility.FORCE_OFF and method ~= nil) then
				method(entry, dialogue_trigger, dialogue, text_obj, close, next, speaker, npc_name, choices_panel)
			end
		end
	end)
end

function Conversation_Entry:show_choices(dialogue_trigger, dialogue, text_obj, close, next, speaker, npc_name, choices_panel)
	self:clear_choices(choices_panel)

	if(speaker.parent.visibility ~= Visibility.FORCE_OFF) then
		speaker.text = "You"

		local size = speaker:ComputeApproximateSize()

		while(size == nil) do
			Task.Wait()
			size = speaker:ComputeApproximateSize()
		end

		speaker.parent.width = size.x + 20
	end

	next.visibility = Visibility.FORCE_OFF
	close.visibility = Visibility.FORCE_OFF

	text_obj.text = ""

	local offset = 0

	for i, c in ipairs(self.choices) do
		local choice = World.SpawnAsset(Dialogue_System_Common.choice_template, { parent = choices_panel })

		choice.text = "  " .. c:get_text()
		choice.y = offset
		
		offset = offset + 35

		choice.clickedEvent:Connect(function()
			if(c:has_entries()) then
				c:play(dialogue_trigger, dialogue, text_obj, close, next, speaker, npc_name, choices_panel)
			else
				dialogue:Destroy()
				self:enable_player_controls()
				dialogue_trigger.isInteractable = true
			end
		end)
	end
end

function Conversation_Entry:set_played(v)
	self.played = v
end

function Conversation_Entry:has_played()
	return self.played
end

function Conversation_Entry:clear_choices(choices_panel)
	for _, c in pairs(choices_panel:GetChildren()) do
		c:Destroy()
	end
end

function Conversation_Entry:call_event()
	if(self.event ~= nil and string.len(self.event) > 0) then
		Events.Broadcast(self.event, self)
	end
end

function Conversation_Entry:enable_player_controls()
	Events.Broadcast("dialogue_system_disable_ui_interact")
	YOOTIL.Events.broadcast_to_server("dialogue_system_enable_player")

	Dialogue_System_Events.trigger("player_controls_enabled", self)
end

function Conversation_Entry:get_condition()
	return self.condition
end

function Conversation_Entry:get_id()
	return self.id
end

function Conversation_Entry:get_text()
	return self.text
end

function Conversation_Entry:has_entries()
	if(#self.entries > 0) then
		return true
	end

	return false
end

function Conversation_Entry:has_choices()
	if(#self.choices > 0) then
		return true
	end

	return false
end

function Conversation_Entry:clean_up()
	if(self.trigger_event ~= nil and self.trigger_event.isConnected) then
		self.trigger_event:Disconnect()
	end
end

function Conversation_Entry:get_prop(prop, wait)
	if(wait) then
		return self.root:GetCustomProperty(prop):WaitForObject()
	end

	return self.root:GetCustomProperty(prop)
end

function Conversation_Entry:new(entry)
	self.__index = self

	local o = setmetatable({

		root = entry,
		played = false

	}, self)

	o:init()

	return o
end

return Conversation_Entry