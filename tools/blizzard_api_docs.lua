#!/usr/bin/env luajit

local function stderr(...)
	io.stderr:write(table.concat({ ... }, ""), "\n")
end

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function starts_with(s, prefix)
	return s:sub(1, #prefix) == prefix
end

local function shell_quote(s)
	return string.format("%q", s)
end

local function dirname(path)
	return (path:match("^(.*)/[^/]*$")) or "."
end

local function join_path(...)
	local parts = { ... }
	local path = table.remove(parts, 1) or ""
	for _, part in ipairs(parts) do
		if path == "" or path:sub(-1) == "/" then
			path = path .. part
		else
			path = path .. "/" .. part
		end
	end
	return path
end

local function is_array(tbl)
	local count = 0
	for key, _ in pairs(tbl) do
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			return false
		end
		count = count + 1
	end
	for i = 1, count do
		if tbl[i] == nil then
			return false
		end
	end
	return true
end

local function json_escape(s)
	local replacements = {
		['"'] = '\\"',
		["\\"] = "\\\\",
		["\b"] = "\\b",
		["\f"] = "\\f",
		["\n"] = "\\n",
		["\r"] = "\\r",
		["\t"] = "\\t",
	}

	return s:gsub('[%z\1-\31\\"]', function(ch)
		return replacements[ch] or string.format("\\u%04x", ch:byte())
	end)
end

local function to_json(value, seen)
	local value_type = type(value)
	if value_type == "nil" then
		return "null"
	elseif value_type == "boolean" or value_type == "number" then
		return tostring(value)
	elseif value_type == "string" then
		return '"' .. json_escape(value) .. '"'
	elseif value_type ~= "table" then
		return '"' .. json_escape(tostring(value)) .. '"'
	end

	seen = seen or {}
	if seen[value] then
		error("Cannot encode recursive table")
	end
	seen[value] = true

	local out = {}
	if is_array(value) then
		for i = 1, #value do
			out[#out + 1] = to_json(value[i], seen)
		end
		seen[value] = nil
		return "[" .. table.concat(out, ",") .. "]"
	end

	local keys = {}
	for key, _ in pairs(value) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		if type(a) == type(b) then
			return tostring(a) < tostring(b)
		end
		return type(a) < type(b)
	end)

	for _, key in ipairs(keys) do
		out[#out + 1] = '"' .. json_escape(tostring(key)) .. '":' .. to_json(value[key], seen)
	end

	seen[value] = nil
	return "{" .. table.concat(out, ",") .. "}"
end

local function get_script_dir()
	local source = arg[0] or "."
	if starts_with(source, "./") then
		local pwd = os.getenv("PWD")
		if pwd and pwd ~= "" then
			source = join_path(pwd, source:sub(3))
		end
	elseif not starts_with(source, "/") then
		local pwd = os.getenv("PWD")
		if pwd and pwd ~= "" then
			source = join_path(pwd, source)
		end
	end
	return dirname(source)
end

local SCRIPT_DIR = get_script_dir()
local REPO_ROOT = dirname(SCRIPT_DIR)
local DEFAULT_DOC_ROOT = join_path(REPO_ROOT, "../../../BlizzardInterfaceCode/Interface/AddOns/Blizzard_APIDocumentationGenerated")

local function usage()
	print(([[
Usage:
  %s stats
  %s systems [pattern]
  %s find <pattern>
  %s show <api name>
  %s dump-json [pattern]

Options:
  --doc-root <path>   Override the Blizzard_APIDocumentationGenerated directory.
  --type <kind>       Filter matches by api type: system, function, event, table, callback.
  --json              Emit JSON for find/show/systems output.

Examples:
  %s show UnitName
  %s find aura
  %s --type function find '^Unit'
]]) :format(arg[0], arg[0], arg[0], arg[0], arg[0], arg[0], arg[0], arg[0]))
end

local function read_lines(path)
	local file, err = io.open(path, "r")
	if not file then
		return nil, err
	end

	local lines = {}
	for line in file:lines() do
		lines[#lines + 1] = line
	end
	file:close()
	return lines
end

local function parse_toc(doc_root)
	local toc_path = join_path(doc_root, "Blizzard_APIDocumentationGenerated.toc")
	local lines, err = read_lines(toc_path)
	if not lines then
		error(("Failed to read TOC %s: %s"):format(toc_path, err or "unknown error"))
	end

	local files = {}
	for _, line in ipairs(lines) do
		local trimmed = trim(line)
		if trimmed ~= "" and not starts_with(trimmed, "#") then
			files[#files + 1] = trimmed
		end
	end
	return files
end

local function copy_value(value, seen)
	local value_type = type(value)
	if value_type ~= "table" then
		return value
	end

	seen = seen or {}
	if seen[value] then
		return seen[value]
	end

	local out = {}
	seen[value] = out
	for key, nested in pairs(value) do
		if type(key) ~= "function" and type(nested) ~= "function" and type(key) ~= "userdata" and type(nested) ~= "userdata" then
			out[copy_value(key, seen)] = copy_value(nested, seen)
		end
	end
	return out
end

local function make_signature(item, system)
	local function describe_args(args)
		if not args or #args == 0 then
			return ""
		end

		local parts = {}
		for _, arg_info in ipairs(args) do
			local part = arg_info.Name or "arg"
			if arg_info.Type then
				part = ("%s: %s"):format(part, arg_info.Type)
			end
			if arg_info.Nilable then
				part = part .. "?"
			end
			parts[#parts + 1] = part
		end
		return table.concat(parts, ", ")
	end

	local namespace = system.Namespace
	local prefix = namespace and namespace ~= "" and (namespace .. ".") or ""
	local signature = ("%s%s(%s)"):format(prefix, item.Name or "Unknown", describe_args(item.Arguments))

	if item.Returns and #item.Returns > 0 then
		local returns = {}
		for _, return_info in ipairs(item.Returns) do
			local part = return_info.Name or "value"
			if return_info.Type then
				part = ("%s: %s"):format(part, return_info.Type)
			end
			if return_info.Nilable then
				part = part .. "?"
			end
			returns[#returns + 1] = part
		end
		signature = signature .. " -> " .. table.concat(returns, ", ")
	end

	return signature
end

local function build_index(doc_root)
	local files = parse_toc(doc_root)
	local loaded = {}

	local api_documentation = {
		docs = {},
		AddDocumentationTable = function(self, doc)
			if loaded.current_file then
				doc.__source = join_path(doc_root, loaded.current_file)
				doc.__source_file = loaded.current_file
			end
			table.insert(self.docs, doc)
		end,
	}

	local previous_api = _G.APIDocumentation
	_G.APIDocumentation = api_documentation

	local function make_placeholder(path)
		local function describe(value)
			if type(value) == "table" and value.__placeholder then
				return value.__placeholder
			end
			return tostring(value)
		end

		local function binary(op)
			return function(left, right)
				return make_placeholder(("(%s %s %s)"):format(describe(left), op, describe(right)))
			end
		end

		return setmetatable({ __placeholder = path }, {
			__index = function(self, key)
				local next_path = (self.__placeholder or "Placeholder") .. "." .. tostring(key)
				local value = make_placeholder(next_path)
				rawset(self, key, value)
				return value
			end,
			__call = function(self)
				return self
			end,
			__add = binary("+"),
			__sub = binary("-"),
			__mul = binary("*"),
			__div = binary("/"),
			__mod = binary("%%"),
			__pow = binary("^"),
			__concat = binary(".."),
			__unm = function(self)
				return make_placeholder("(-" .. describe(self) .. ")")
			end,
			__tostring = function(self)
				return self.__placeholder or "Placeholder"
			end,
		})
	end

	local sandbox = {
		APIDocumentation = api_documentation,
	}
	setmetatable(sandbox, {
		__index = function(_, key)
			local value = _G[key]
			if value ~= nil then
				return value
			end
			value = make_placeholder(tostring(key))
			rawset(sandbox, key, value)
			return value
		end,
	})

	for _, relative_path in ipairs(files) do
		loaded.current_file = relative_path
		local full_path = join_path(doc_root, relative_path)
		local chunk, load_err = loadfile(full_path)
		if not chunk then
			_G.APIDocumentation = previous_api
			error(("Failed to load %s: %s"):format(full_path, load_err))
		end
		setfenv(chunk, sandbox)
		local ok, err = pcall(chunk)
		if not ok then
			_G.APIDocumentation = previous_api
			error(("Failed to load %s: %s"):format(full_path, err))
		end
	end

	_G.APIDocumentation = previous_api

	local systems = {}
	local items = {}

	local function add_item(item_type, item, system)
		local copied = copy_value(item)
		copied.__api_type = item_type
		copied.__system = system and system.Name or nil
		copied.__namespace = system and system.Namespace or nil
		copied.__system_type = system and system.Type or nil
		copied.__source = system and system.__source or nil
		copied.__source_file = system and system.__source_file or nil
		copied.__signature = make_signature(copied, system or {})
		table.insert(items, copied)
	end

	for _, system in ipairs(api_documentation.docs) do
		local system_copy = copy_value(system)
		system_copy.__api_type = "system"
		system_copy.__signature = system.Namespace and system.Namespace ~= "" and system.Namespace or system.Name
		system_copy.__source = system.__source
		system_copy.__source_file = system.__source_file
		systems[#systems + 1] = system_copy
		items[#items + 1] = system_copy

		for _, field_name in ipairs({ "Functions", "Events", "Tables", "Callbacks" }) do
			local members = system[field_name]
			if members then
				local item_type = field_name:sub(1, -2):lower()
				if field_name == "Callbacks" then
					item_type = "callback"
				end
				for _, member in ipairs(members) do
					add_item(item_type, member, system)
				end
			end
		end
	end

	return {
		doc_root = doc_root,
		systems = systems,
		items = items,
	}
end

local function normalize(s)
	return string.lower(s or "")
end

local function matches_type(item, type_filter)
	return not type_filter or item.__api_type == type_filter
end

local function item_identity_candidates(item)
	local candidates = {}
	if item.Name then
		candidates[#candidates + 1] = item.Name
	end
	if item.__api_type == "system" and item.__namespace and item.__namespace ~= "" then
		candidates[#candidates + 1] = item.__namespace
	end
	if item.__api_type ~= "system" and item.__namespace and item.__namespace ~= "" and item.Name then
		candidates[#candidates + 1] = item.__namespace .. "." .. item.Name
	end
	if item.__signature then
		local bare_signature = item.__signature:gsub("%s*%-%>.*$", "")
		candidates[#candidates + 1] = bare_signature
	end
	return candidates
end

local function matches_pattern(item, pattern)
	local target = normalize(table.concat({
		item.Name or "",
		item.__system or "",
		item.__namespace or "",
		item.Type or "",
	}, " "))

	pattern = normalize(pattern)
	if target:find(pattern, 1, true) then
		return true
	end

	local ok, found = pcall(function()
		return target:find(pattern) ~= nil
	end)
	return ok and found or false
end

local function exact_matches(index, name, type_filter)
	local wanted = normalize(name)
	local matches = {}
	for _, item in ipairs(index.items) do
		if matches_type(item, type_filter) then
			for _, candidate in ipairs(item_identity_candidates(item)) do
				if normalize(candidate) == wanted then
					matches[#matches + 1] = item
					break
				end
			end
		end
	end
	return matches
end

local function fuzzy_matches(index, pattern, type_filter, systems_only)
	local pool = systems_only and index.systems or index.items
	local matches = {}
	for _, item in ipairs(pool) do
		if matches_type(item, type_filter) and matches_pattern(item, pattern) then
			matches[#matches + 1] = item
		end
	end

	table.sort(matches, function(a, b)
		local a_key = table.concat({ a.__api_type or "", a.__system or "", a.Name or "" }, "\0")
		local b_key = table.concat({ b.__api_type or "", b.__system or "", b.Name or "" }, "\0")
		return a_key < b_key
	end)

	return matches
end

local function render_doc_lines(lines)
	if not lines or #lines == 0 then
		return nil
	end
	return table.concat(lines, " ")
end

local function print_item(item)
	print(("[%s] %s"):format(item.__api_type, item.__signature or item.Name or "Unknown"))
	if item.__system then
		print(("  system: %s"):format(item.__system))
	end
	if item.Type then
		print(("  declared type: %s"):format(item.Type))
	end
	if item.__source_file then
		print(("  source: %s"):format(item.__source_file))
	end
	local docs = render_doc_lines(item.Documentation)
	if docs then
		print(("  docs: %s"):format(docs))
	end
	if item.Arguments and #item.Arguments > 0 then
		print("  arguments:")
		for _, arg_info in ipairs(item.Arguments) do
			local line = ("    - %s"):format(arg_info.Name or "arg")
			if arg_info.Type then
				line = line .. (": " .. arg_info.Type)
			end
			if arg_info.Nilable then
				line = line .. " (nilable)"
			end
			local arg_docs = render_doc_lines(arg_info.Documentation)
			if arg_docs then
				line = line .. (" -- %s"):format(arg_docs)
			end
			print(line)
		end
	end
	if item.Returns and #item.Returns > 0 then
		print("  returns:")
		for _, return_info in ipairs(item.Returns) do
			local line = ("    - %s"):format(return_info.Name or "value")
			if return_info.Type then
				line = line .. (": " .. return_info.Type)
			end
			if return_info.Nilable then
				line = line .. " (nilable)"
			end
			local return_docs = render_doc_lines(return_info.Documentation)
			if return_docs then
				line = line .. (" -- %s"):format(return_docs)
			end
			print(line)
		end
	end
end

local function summarize_items(items)
	local out = {}
	for _, item in ipairs(items) do
		out[#out + 1] = {
			api_type = item.__api_type,
			name = item.Name,
			signature = item.__signature,
			system = item.__system,
			namespace = item.__namespace,
			declared_type = item.Type,
			source_file = item.__source_file,
			documentation = item.Documentation,
		}
	end
	return out
end

local doc_root = DEFAULT_DOC_ROOT
local type_filter = nil
local json_output = false
local positionals = {}

local i = 1
	while i <= #arg do
	local token = arg[i]
	if token == "--doc-root" then
		i = i + 1
		doc_root = arg[i]
	elseif token == "--type" then
		i = i + 1
		type_filter = arg[i]
	elseif token == "--json" then
		json_output = true
	else
		positionals[#positionals + 1] = token
	end
	i = i + 1
end

if #positionals == 0 or positionals[1] == "help" or positionals[1] == "--help" then
	usage()
	os.exit(0)
end

local ok, index = pcall(build_index, doc_root)
if not ok then
	stderr(index)
	os.exit(1)
end

local command = positionals[1]

if command == "stats" then
	local counts = {
		system = 0,
		["function"] = 0,
		event = 0,
		table = 0,
		callback = 0,
	}
	for _, item in ipairs(index.items) do
		counts[item.__api_type] = (counts[item.__api_type] or 0) + 1
	end
	if json_output then
		print(to_json({
			doc_root = index.doc_root,
			counts = counts,
		}))
	else
		print(("doc_root: %s"):format(index.doc_root))
		for _, key in ipairs({ "system", "function", "event", "table", "callback" }) do
			print(("%s: %d"):format(key, counts[key] or 0))
		end
	end
elseif command == "systems" then
	local pattern = positionals[2]
	local matches = pattern and fuzzy_matches(index, pattern, type_filter or "system", true) or index.systems
	table.sort(matches, function(a, b)
		return (a.Name or "") < (b.Name or "")
	end)
	if json_output then
		print(to_json(summarize_items(matches)))
	else
		for _, item in ipairs(matches) do
			print(item.Name)
		end
	end
elseif command == "find" then
	local pattern = positionals[2]
	if not pattern then
		usage()
		os.exit(1)
	end
	local matches = fuzzy_matches(index, pattern, type_filter)
	if json_output then
		print(to_json(summarize_items(matches)))
	else
		for _, item in ipairs(matches) do
			local owner = item.__system and (" [" .. item.__system .. "]") or ""
			print(("[%s] %s%s"):format(item.__api_type, item.__signature or item.Name or "Unknown", owner))
		end
	end
elseif command == "show" then
	local name = positionals[2]
	if not name then
		usage()
		os.exit(1)
	end
	local matches = exact_matches(index, name, type_filter)
	if #matches == 0 then
		matches = fuzzy_matches(index, name, type_filter)
	end
	if json_output then
		print(to_json(matches))
	else
		for idx, item in ipairs(matches) do
			if idx > 1 then
				print("")
			end
			print_item(item)
		end
	end
elseif command == "dump-json" then
	local pattern = positionals[2]
	local payload = pattern and fuzzy_matches(index, pattern, type_filter) or index.items
	print(to_json(payload))
else
	stderr(("Unknown command: %s"):format(shell_quote(command)))
	usage()
	os.exit(1)
end
