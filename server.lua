local function dbg(...)
    if Config.Debug then
        print('[cx-adminlogger]', ...)
    end
end

local function isStaff(src)
    if src == 0 then return true end
    for _, ace in ipairs(Config.StaffAces or {}) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end
    return false
end

local function isWhitelisted(cmd)
    if not Config.LogCommands or #Config.LogCommands == 0 then
        return true
    end
    cmd = (cmd or ''):lower()
    for _, v in ipairs(Config.LogCommands) do
        if cmd == tostring(v):lower() then return true end
    end
    return false
end

local function getIds(src)
    local ids = { license='N/A', discord='N/A', steam='N/A', ip='N/A' }

    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:find('license:') then ids.license = id
        elseif id:find('discord:') then ids.discord = id
        elseif id:find('steam:') then ids.steam = id
        end
    end

    local ep = GetPlayerEndpoint(src)
    if ep and ep ~= '' then ids.ip = ep end
    return ids
end

local function mention(discordId)
    if not discordId or discordId == 'N/A' then return 'N/A' end
    return '<@' .. discordId:gsub('discord:', '') .. '>'
end

local function shortId(id)
    if not id or id == 'N/A' then return 'N/A' end
    if #id <= 18 then return id end
    return id:sub(1, 18) .. '…'
end

local function safeCodeBlock(s)
    s = tostring(s or '')
    s = s:gsub('```', 'ˋˋˋ') -- prevent breaking embeds
    if #s > 900 then
        s = s:sub(1, 900) .. '…'
    end
    return s
end

local function premiumEmbed(src, cmdName, rawText, extraFields)
    local isConsole = (src == 0)
    local pname = isConsole and 'CONSOLE / RCON' or (GetPlayerName(src) or 'Unknown')
    local ids = isConsole
        and { license = 'N/A', discord = 'N/A', steam = 'N/A', ip = 'N/A' }
        or getIds(src)

    local discordTag = mention(ids.discord)

    local cmdShown = safeCodeBlock(rawText or cmdName or 'unknown')
    if #cmdShown > 950 then
        cmdShown = cmdShown:sub(1, 950) .. '…'
    end

    local fields = {
        {
            name = '🧾 Command',
            value = ('```%s```'):format(cmdShown),
            inline = false
        },
        {
            name = '👤 Executor',
            value = (
                '**%s**\n' ..
                '• **Source:** `%s`\n' ..
                '• **Discord:** %s'
            ):format(pname, isConsole and '0 (Console)' or tostring(src), discordTag),
            inline = true
        },
        {
            name = '🪪 Identifiers',
            value = (
                '• **License:** `%s`\n' ..
                '• **Steam:** `%s`\n' ..
                '• **IP:** `%s`'
            ):format(ids.license, ids.steam, ids.ip),
            inline = true
        },

    }

    if type(extraFields) == 'table' then
        for _, f in ipairs(extraFields) do
            if type(f) == 'table' and f.name and f.value then
                local v = tostring(f.value)
                v = safeCodeBlock(v)
                if #v > 950 then v = v:sub(1, 950) .. '…' end

                table.insert(fields, {
                    name = tostring(f.name),
                    value = v,
                    inline = (f.inline == true)
                })
            end
        end
    end

    local nowUTC = os.date('!%Y-%m-%d %H:%M:%S')
    local header = ('`%s` • %s'):format(cmdName or 'command', isConsole and 'System' or ' ')

    return {
        username = 'CX Admin Logger',
        avatar_url = 'https://dbl-discord.usercontent.prism.gg/avatars/720351927581278219/7ac935300e9bc3edcbc2de1b91c597b1.png', -- optional: replace with your own
        embeds = {{
            title = 'New Admin Command Executed',
            description = header,
            color = 0x5865F2,
            fields = fields,
            footer = {
                text = ('%s UTC • Made by Cxsper'):format(nowUTC)
            },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }}
    }
end


local function postDiscord(payload)
    if not Config.Webhook or Config.Webhook == '' then
        dbg('No webhook configured')
        return false
    end

    PerformHttpRequest(Config.Webhook, function(status, body)
        dbg('Discord status:', status)
        if status ~= 204 and status ~= 200 then
            dbg('Discord body:', body or 'nil')
        end
    end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })

    return true
end

-- exports['cx-adminlogger']:Log(source, 'noclip', '/noclip true')
exports('Log', function(src, cmdName, rawText)
    cmdName = tostring(cmdName or ''):lower()
    rawText = tostring(rawText or ('/' .. cmdName))
    if cmdName == '' then return false end
    if not isStaff(src) then return false end
    if not isWhitelisted(cmdName) then return false end

    dbg(('LOG %s: %s'):format(src, rawText))
    return postDiscord(premiumEmbed(src, cmdName, rawText, nil))
end)

-- exports['cx-adminlogger']:LogWithFields(source, 'giveitem', '/giveitem 12 water 10', { ... })
exports('LogWithFields', function(src, cmdName, rawText, extraFields)
    cmdName = tostring(cmdName or ''):lower()
    rawText = tostring(rawText or ('/' .. cmdName))
    if cmdName == '' then return false end
    if not isStaff(src) then return false end
    if not isWhitelisted(cmdName) then return false end

    dbg(('LOG %s: %s'):format(src, rawText))
    return postDiscord(premiumEmbed(src, cmdName, rawText, extraFields))
end)

RegisterCommand('cmdlogtest', function(src)
    if not isStaff(src) then return end
    exports['cx-adminlogger']:Log(src, 'cmdlogtest', '/cmdlogtest (webhook test)')
end, false)

dbg('Loaded. Run /cmdlogtest as staff to verify.')
