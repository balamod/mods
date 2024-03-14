local math = require 'math'

local logger = getLogger("dev_console")

_CONSOLE_OPEN = false
_CONSOLE_CMD = "> "
LINE_HEIGHT = 20
MAX_LINES = love.graphics.getHeight() / LINE_HEIGHT
START_LINE_OFFSET = 1
SHIFT_MODIFIER = false
CTRL_MODIFIER = false
ALT_MODIFIER = false
META_MODIFIER = false

local function toggleConsole()
    _CONSOLE_OPEN = not _CONSOLE_OPEN
end

local commands = {}

function registerCommand(name, callback, description)
    commands[name] = {
        call = callback,
        desc = description
    }
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
    if key_name == "space" then
        _CONSOLE_CMD = _CONSOLE_CMD .. " "
        return
    end
    if key_name == "delete" then
        _CONSOLE_CMD = "> "
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
        START_LINE_OFFSET = START_LINE_OFFSET - 1
        return
    end
    if key_name == "down" then
        START_LINE_OFFSET = START_LINE_OFFSET + 1
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
        -- ignore tab key
        -- TODO: maybe autocomplete in the future?
        return
    end
    if key_name == "capslock" then
        -- ignore caps lock key
        return
    end
    if key_name == "scrolllock" then
        -- ignore scroll lock key
        return
    end
    if key_name == "numlock" then
        -- ignore num lock key
        return
    end
    if key_name == "printscreen" then
        -- ignore print screen key
        return
    end
    if key_name == "pause" then
        -- ignore pause key
        return
    end
    if key_name == "lalt" or key_name == "ralt" then
        ALT_MODIFIER = true
        return
    end
    if key_name == "lctrl" or key_name == "rctrl" then
        CTRL_MODIFIER = true
        return
    end
    if key_name == "lshift" or key_name == "rshift" then
        SHIFT_MODIFIER = true
        return
    end
    if key_name == "lgui" or key_name == "rgui" then
        -- windows key / meta / cmd key (on macos)
        META_MODIFIER = true
        return
    end
    if key_name == "backspace" then
        if #_CONSOLE_CMD > 2 then
            _CONSOLE_CMD = _CONSOLE_CMD:sub(1, #_CONSOLE_CMD - 1)
        end
    elseif key_name == "return" then
        logger:print(_CONSOLE_CMD)
        local cmdName = _CONSOLE_CMD:sub(3)
        cmdName = cmdName:match("%S+")
        local args = {}
        local argString = _CONSOLE_CMD:sub(3 + #cmdName + 1)
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
        _CONSOLE_CMD = "> "
    else
        if SHIFT_MODIFIER then
            key_name = string.upper(key_name)
        end
        _CONSOLE_CMD = _CONSOLE_CMD .. key_name
    end
end

local function onKeyPressed(key_name)
    if key_name == "f2" then
        toggleConsole()
        return true
    end
    if _CONSOLE_OPEN then
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
        ALT_MODIFIER = false
        return false
    end
    if key_name == "lctrl" or key_name == "rctrl" then
        CTRL_MODIFIER = false
        return false
    end
    if key_name == "lshift" or key_name == "rshift" then
        SHIFT_MODIFIER = false
        return false
    end
    if key_name == "lgui" or key_name == "rgui" then
        META_MODIFIER = false
        return false
    end
    return false
end

local function onPostRender()
    if _CONSOLE_OPEN then
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        for i, line in ipairs(ALL_MESSAGES) do
            r, g, b = getLineColor(line)
            love.graphics.setColor(r, g, b, 1)
            love.graphics.print(line, 10, 10 + i * 20)
        end
        love.graphics.setColor(1, 1, 1, 1) -- white
        love.graphics.print(_CONSOLE_CMD, 10, love.graphics.getHeight() - 30)
    end
end

table.insert(mods,
        {
            mod_id = "dev_console",
            name = "Dev Console",
            version = "0.1.0",
            enabled = true,
            on_enable = function()
                MAX_LINES = love.graphics.getHeight() / LINE_HEIGHT
                logger:debug("Dev Console enabled")
                registerCommand(
                        "help",
                        function()
                            logger:print("Available commands:")
                            for name, cmd in pairs(commands) do
                                if cmd.desc then
                                    logger:print(name .. ": " .. cmd.desc)
                                end
                            end
                        end,
                        "Prints a list of available commands"
                )

                registerCommand(
                        "clear",
                        function()
                            ALL_MESSAGES = {}
                        end,
                        "Clear the console")

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
            end,
            on_disable = function()
            end,
            on_key_pressed = onKeyPressed,
            on_post_render = onPostRender,
            on_key_released = onKeyReleased,
            on_command_sent = function(command, args)
                if commands[command] then
                    commands[command].call(args)
                else
                    logger:error("Command not found: " .. command)
                end
            end,
        }
)
