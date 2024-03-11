LOGGERS = {}
ALL_MESSAGES = {}

function createLogger(name)
    return {
        name=name,
        messages={},
        log=function(self, level, ...)
            local args = {...}
            local text = ""
            for i, v in ipairs(args) do
                text = text .. tostring(v) .. " "
            end
            local formattedMessage = string.format("[%s] - %s :: %s", self.name, level, text)
            table.insert(self.messages, formattedMessage)
            table.insert(ALL_MESSAGES, formattedMessage)
        end,
        info=function(self, ...)
            self:log("INFO", ...)
        end,
        warn=function(self, ...)
            self:log("WARN", ...)
        end,
        error=function(self, ...)
            self:log("ERROR", ...)
        end,
        debug=function(self, ...)
            self:log("DEBUG", ...)
        end,
        trace=function(self, ...)
            self:log("TRACE", ...)
        end,
        print=function(self, message)
            table.insert(self.messages, message)
            table.insert(ALL_MESSAGES, message)
        end,
    }
end

function getLogger(name)
    if LOGGERS[name] then
        return LOGGERS[name]
    else
        local logger = createLogger(name)
        LOGGERS[name] = logger
        return logger
    end
end
