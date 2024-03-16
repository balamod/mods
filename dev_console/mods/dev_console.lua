local math = require 'math'
local utf8 = require("utf8")

local logger = getLogger("dev_console")
local LINE_HEIGHT = 20
local console = {
    is_open = false,
    cmd = "> ",
    max_lines = love.graphics.getHeight() / LINE_HEIGHT,
    start_line_offset = 1,
    modifiers = {
        capslock = false,
        scrolllock = false,
        numlock = false,
        shift = false,
        ctrl = false,
        alt = false,
        meta = false,
    },
}

local function toggleConsole()
    console.is_open = not console.is_open
    love.keyboard.setKeyRepeat(console.is_open)  -- set key repeat to true when console is open
    if console.is_open then
        console.start_line_offset = 1
        love.textinput = function(t)
            console.cmd = console.cmd .. t
        end
    else
        love.textinput = nil
    end
end

local function longestCommonPrefix(strings)
    if #strings == 0 then
        return ""
    end
    local prefix = strings[1]
    for i = 2, #strings do
        local str = strings[i]
        local j = 1
        while j <= #prefix and j <= #str and prefix:sub(j, j) == str:sub(j, j) do
            j = j + 1
        end
        prefix = prefix:sub(1, j - 1)
    end
    return prefix
end

local function tryAutocomplete()
    local command = console.cmd:sub(3) -- remove the "> " prefix
    local cmd = {}
    -- split command into parts
    for part in command:gmatch("%S+") do
        table.insert(cmd, part)
    end
    if #cmd == 0 then
        -- no command typed, do nothing (no completions possible)
        logger:trace("No command typed")
        return nil
    end
    local completions = {}
    if #cmd == 1 then
        -- only one part, try to autocomplete the command
        -- find all commands that start with the typed string, then complete the characters until the next character is not a match
        for name, _ in pairs(_REGISTERED_COMMANDS) do
            if name:find(cmd[1], 1, true) == 1 then -- name starts with cmd[1]
                table.insert(completions, name)
            end
        end
    else
        -- more than one part, try to autocomplete the arguments
        local commandName = cmd[1]
        local command = _REGISTERED_COMMANDS[commandName]
        if command then
            completions = command.autocomplete(cmd[#cmd]) or {}
        end
    end
    logger:trace("Autocomplete matches: " .. #completions .. " " .. table.concat(completions, ", "))
    if #completions == 0 then
        -- no completions found
        return nil
    elseif #completions == 1 then
        return completions[1]
    else
        -- complete until the common prefix of all matches
        return longestCommonPrefix(completions)
    end
end

local function getLineColor(line)
    if string.match(line, "INFO") then
        sendDebugMessage("INFO")
        return 0, 0.9, 1
    end
    if string.match(line, "WARN") then
        return 1, 0.5, 0
    end
    if string.match(line, "ERROR") then
        return 1, 0, 0
    end
    if string.match(line, "DEBUG") then
        return 0.16, 0, 1
    end
    if string.match(line, "TRACE") then
        return 1, 1, 1
    end
    return 1, 1, 1

end

local function getTextToDisplay()
    local text = {}
    for i = 1, MAX_LINES do
        local index = #ALL_MESSAGES - i + START_LINE_OFFSET
        if index < 1 then
            break
        end
        table.insert(text, ALL_MESSAGES[index])
    end
    return text
end

local function typeKey(key_name)
    if key_name == "escape" then
        toggleConsole()
        return
    end
    if key_name == "delete" then
        console.cmd = "> "
        return
    end
    if string.match(key_name, "f[0-9]+") then
        -- ignore function keys
        return
    end
    if key_name == "left" or key_name == "right" then
        -- ignore arrow keys
        return
    end
    if key_name == "up" then
        console.start_line_offset = console.start_line_offset - 1
        return
    end
    if key_name == "down" then
        console.start_line_offset = console.start_line_offset + 1
        return
    end
    if key_name == "home" or key_name == "end" then
        -- ignore home and end keys
        -- TODO: should scroll console all the way up/down in the future
        return
    end
    if key_name == "pageup" or key_name == "pagedown" then
        -- ignore page up and page down keys
        -- TODO: should scroll console up/down in the future
        return
    end
    if key_name == "insert" then
        -- ignore insert key
        return
    end
    if key_name == "tab" then
        local completion = tryAutocomplete()
        if completion then
            -- get the last part of the console command
            local lastPart = console.cmd:match("%S+$")
            if lastPart == nil then -- cmd ends with a space, so we stop the completion
                return
            end
            -- then replace the whole last part with the autocompleted command
            console.cmd = console.cmd:sub(1, #console.cmd - #lastPart) .. completion
        end
        return
    end
    if key_name == "capslock" then
        console.modifiers.capslock = not console.modifiers.capslock
        return
    end
    if key_name == "scrolllock" then
        console.modifiers.scrolllock = not console.modifiers.scrolllock
        return
    end
    if key_name == "numlock" then
        console.modifiers.numlock = not console.modifiers.numlock
        return
    end
    if key_name == "lalt" or key_name == "ralt" then
        console.modifiers.alt = true
        return
    end
    if key_name == "lctrl" or key_name == "rctrl" then
        console.modifiers.ctrl = true
        return
    end
    if key_name == "lshift" or key_name == "rshift" then
        console.modifiers.shift = true
        return
    end
    if key_name == "lgui" or key_name == "rgui" then
        -- windows key / meta / cmd key (on macos)
        console.modifiers.meta = true
        return
    end
    if key_name == "backspace" then
        if #console.cmd > 2 then
            local byteoffset = utf8.offset(console.cmd, -1)
            if byteoffset then
                -- remove the last UTF-8 character.
                -- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
                console.cmd = string.sub(console.cmd, 1, byteoffset - 1)
            end
        end
        return
    end
    if key_name == "return" or key_name == "kpenter" then
        logger:print(console.cmd)
        logger:trace("Command sent: " .. console.cmd:sub(3))
        local cmdName = console.cmd:sub(3)
        cmdName = cmdName:match("%S+")
        local args = {}
        local argString = console.cmd:sub(3 + #cmdName + 1)
        if argString then
            for arg in argString:gmatch("%S+") do
                table.insert(args, arg)
            end
        end

        for _, mod in ipairs(mods) do
            if mod.on_command_sent then
                mod.on_command_sent(cmdName, args)
            end
        end
        console.cmd = "> "
        return
    end
end

local function onKeyPressed(key_name)
    if key_name == "f2" then
        toggleConsole()
        return true
    end
    if console.is_open then
        typeKey(key_name)
        return true
    end

    if key_name == "f4" then
        G.DEBUG = not G.DEBUG
        if G.DEBUG then
            logger:info("Debug mode enabled")
        else
            logger:info("Debug mode disabled")
        end
    end
    return false
end

local function onKeyReleased(key_name)
    if key_name == "lalt" or key_name == "ralt" then
        console.modifiers.alt = false
        return false
    end
    if key_name == "lctrl" or key_name == "rctrl" then
        console.modifiers.ctrl = false
        return false
    end
    if key_name == "lshift" or key_name == "rshift" then
        console.modifiers.shift = false
        return false
    end
    if key_name == "lgui" or key_name == "rgui" then
        console.modifiers.meta = false
        return false
    end
    return false
end

local function onPostRender()
    if console.is_open then
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        for i, line in ipairs(ALL_MESSAGES) do
            r, g, b = getLineColor(line)
            love.graphics.setColor(r, g, b, 1)
            love.graphics.print(line, 10, 10 + i * 20)
        end
        love.graphics.setColor(1, 1, 1, 1) -- white
        love.graphics.print(console.cmd, 10, love.graphics.getHeight() - 30)
    end
end

table.insert(mods,
        {
            mod_id = "dev_console",
            name = "Dev Console",
            version = "0.2.0",
            enabled = true,
            on_enable = function()
                console.max_lines = love.graphics.getHeight() / LINE_HEIGHT
                logger:debug("Dev Console enabled")

                registerCommand(
                    "help",
                    function()
                        logger:print("Available commands:")
                        for name, cmd in pairs(_REGISTERED_COMMANDS) do
                            if cmd.desc then
                                logger:print(name .. ": " .. cmd.desc)
                            end
                        end
                    end,
                    "Prints a list of available commands",
                    function(current_arg)
                        local completions = {}
                        for name, _ in pairs(_REGISTERED_COMMANDS) do
                            if name:find(current_arg, 1, true) == 1 then
                                table.insert(completions, name)
                            end
                        end
                        return completions
                    end,
                    "Usage: help <command>"
                )

                registerCommand(
                    "clear",
                    function()
                        ALL_MESSAGES = {}
                    end,
                    "Clear the console"
                )

                registerCommand(
                    "exit",
                    function()
                        toggleConsole()
                    end,
                    "Close the console"
                )

                registerCommand(
                    "give",
                    function()
                        logger:print("Give command not implemented yet")
                    end,
                    "Give an item to the player"
                )

                registerCommand(
                    "money",
                    function(args)
                        if args[1] and args[2] then
                            local amount = tonumber(args[2])
                            if amount then
                                if args[1] == "add" then
                                    ease_dollars(amount, true)
                                    logger:info("Added " .. amount .. " money to the player")
                                elseif args[1] == "remove" then
                                    ease_dollars(-amount, true)
                                    logger:info("Removed " .. amount .. " money from the player")
                                elseif args[1] == "set" then
                                    local currentMoney = G.GAME.dollars
                                    local diff = amount - currentMoney
                                    ease_dollars(diff, true)
                                    logger:info("Set player money to " .. amount)
                                else
                                    logger:error("Invalid operation, use add, remove or set")
                                end
                            else
                                logger:error("Invalid amount")
                            end
                        else
                            logger:warn("Usage: money <add/remove/set> <amount>")
                        end
                    end,
                    "Change the player's money"
                )

                registerCommand(
                    "discards",
                    function(args)
                        if args[1] and args[2] then
                            local amount = tonumber(args[2])
                            if amount then
                                if args[1] == "add" then
                                    ease_discard(amount, true)
                                    logger:info("Added " .. amount .. " discards to the player")
                                elseif args[1] == "remove" then
                                    ease_discard(-amount, true)
                                    logger:info("Removed " .. amount .. " discards from the player")
                                elseif args[1] == "set" then
                                    local currentDiscards = G.GAME.current_round.discards_left
                                    local diff = amount - currentDiscards
                                    ease_discard(diff, true)
                                    logger:info("Set player discards to " .. amount)
                                else
                                    logger:error("Invalid operation, use add, remove or set")
                                end
                            else
                                logger:error("Invalid amount")
                            end
                        else
                            logger:warn("Usage: discards <add/remove/set> <amount>")
                        end
                    end,
                    "Change the player's discards"
                )

                registerCommand(
                    "hands",
                    function(args)
                        if args[1] and args[2] then
                            local amount = tonumber(args[2])
                            if amount then
                                if args[1] == "add" then
                                    ease_hands_played(amount, true)
                                    logger:info("Added " .. amount .. " hands to the player")
                                elseif args[1] == "remove" then
                                    ease_hands_played(-amount, true)
                                    logger:info("Removed " .. amount .. " hands from the player")
                                elseif args[1] == "set" then
                                    local currentHands = G.GAME.current_round.hands_left
                                    local diff = amount - currentHands
                                    ease_hands_played(diff, true)
                                    logger:info("Set player hands to " .. amount)
                                else
                                    logger:error("Invalid operation, use add, remove or set")
                                end
                            else
                                logger:error("Invalid amount")
                            end
                        else
                            logger:warn("Usage: hands <add/remove/set> <amount>")
                        end
                    end,
                    "Change the player's remaining hands"
                )

            end,
            on_disable = function()
            end,
            on_key_pressed = onKeyPressed,
            on_post_render = onPostRender,
            on_key_released = onKeyReleased,
            on_mouse_pressed = function(x, y, button, touches)
                if console.is_open then
                    return true  -- Do not press buttons through the console, this cancels the event
                end
            end,
            on_mouse_released = function(x, y, button)
                if console.is_open then
                    return true -- Do not release buttons through the console, this cancels the event
                end
            end,
            on_command_sent = function(command, args)
                if _REGISTERED_COMMANDS[command] then
                    _REGISTERED_COMMANDS[command].call(args)
                else
                    logger:error("Command not found: " .. command)
                end
            end,
        }
)
