local _, addon = ...

local groupData = addon.GroupData

local serializer = {}

serializer.TYPE_BOOLEAN = 1
serializer.TYPE_NUMBER = 2
serializer.TYPE_STRING = 3

local TYPE_IDS_BY_LUA_TYPE = {
	boolean = serializer.TYPE_BOOLEAN,
	number = serializer.TYPE_NUMBER,
	string = serializer.TYPE_STRING,
}

local FIELD_SEPARATOR = "\t"
local KEY_VALUE_SEPARATOR = "="

local TYPE_HANDLERS = {
	[serializer.TYPE_BOOLEAN] = {
		serialize = function(value)
			return value and "1" or "0"
		end,
		deserialize = function(value)
			return value ~= "0"
		end,
	},
	[serializer.TYPE_NUMBER] = {
		serialize = function(value)
			return tostring(value)
		end,
		deserialize = function(value)
			return tonumber(value)
		end,
	},
	[serializer.TYPE_STRING] = {
		serialize = function(value)
			return tostring(value)
		end,
		deserialize = function(value)
			return value
		end,
	},
}

local function GetHandler(typeID)
	return TYPE_HANDLERS[typeID]
end

local function GetTypeIDForValue(value)
	return TYPE_IDS_BY_LUA_TYPE[type(value)]
end

function serializer.Serialize(fields)
	local keys = {}
	for key, value in pairs(fields or {}) do
		if type(key) == "string" and value ~= nil and GetTypeIDForValue(value) then
			keys[#keys + 1] = key
		end
	end

	table.sort(keys)

	local parts = {}
	for _, key in ipairs(keys) do
		local value = fields[key]
		local typeID = GetTypeIDForValue(value)
		local handler = GetHandler(typeID)
		parts[#parts + 1] = tostring(typeID) .. key .. KEY_VALUE_SEPARATOR .. handler.serialize(value)
	end

	return table.concat(parts, FIELD_SEPARATOR)
end

function serializer.Deserialize(message)
	local fields = {}

	for fieldText in string.gmatch((message or "") .. FIELD_SEPARATOR, "(.-)" .. FIELD_SEPARATOR) do
		local separatorIndex = string.find(fieldText, KEY_VALUE_SEPARATOR, 1, true)
		if separatorIndex then
			local typedKey = string.sub(fieldText, 1, separatorIndex - 1)
			local valueText = string.sub(fieldText, separatorIndex + 1)
			local typeText, key = string.match(typedKey, "^(%d+)(.+)$")
			local typeID = tonumber(typeText)
			local handler = typeID and GetHandler(typeID) or nil
			if handler and key and key ~= "" then
				fields[key] = handler.deserialize(valueText)
			end
		end
	end

	return fields
end

groupData.Serializer = serializer
