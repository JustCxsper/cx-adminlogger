# cx-adminlogger


**cx-adminlogger** is a lightweight, export-based staff/admin command logger for FiveM. It sends clean, premium Discord embeds whenever staff commands are executed.

Designed for Qbox / ox_lib, but works with any framework or resource that uses RegisterCommand or lib.addCommand.

The logger can be triggered anywhere using exports. This resource does **NOT** hook or override anything globally. Instead, you explicitly log commands where they matter, giving you full control and zero surprises.

---

## Overview

FiveM does not provide a reliable global event that fires for every command executed across all resources. Because of this limitation, cx-adminlogger is intentionally built around exports.

This design means:
- You decide which commands get logged
- You decide where logging happens
- Nothing breaks
- Nothing double-logs
- Works perfectly with admin menus, inventory scripts, and custom tools

If a command is important, you log it. If it isn't, you don't.

---

## Features

- Clean, premium Discord embeds
- Staff-only logging via ACE permissions
- Works with RegisterCommand and lib.addCommand
- Optional command whitelist
- Simple and readable exports
- No overrides
- No hooks
- Production-safe

---

## Installation

1. Place the resource into your server resources folder:
   ```
   resources/cx-adminlogger
   ```

2. Start it early in your server.cfg BEFORE other resources:
   ```cfg
   ensure cx-adminlogger
   ```
   Starting it early ensures other scripts can safely call its exports.

---

> IMPORTANT: Make sure your staff are actually assigned to groups using add_principal or txAdmin.
---

## Configuration

Open config.lua and configure the logger.

### Discord Webhook
```lua
Config.Webhook = 'YOUR_DISCORD_WEBHOOK_URL'
```

### Staff ACE Nodes
```lua
Config.StaffAces = { 'admin', 'mod', 'support' }
```

### Optional Whitelist
Leave empty to log everything passed to the exports.
```lua
Config.LogCommands = {}
```

### Debug Output
```lua
Config.Debug = true
```

## How cx-adminlogger Works

cx-adminlogger exposes exports that other resources can call.

When you call an export:

1. The logger checks if the player is staff
2. It checks the optional whitelist
3. It sends a Discord embed
4. The command continues normally

If the player is NOT staff, nothing is logged.

---

## Available Exports

cx-adminlogger provides two main exports for logging commands. Choose the one that fits your needs based on how much detail you want in the Discord embed.

### 1. Basic Logging: `Log`

Purpose: Use this for simple command logging where you only need the command text in the Discord embed.

When to use: Ideal for commands without additional context like targets or amounts (e.g., /noclip, /godmode).

Export Call:
```lua
exports['cx-adminlogger']:Log(source, commandName, rawText)
```

Parameters:

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| source | number | The server ID of the player executing the command | 1 |
| commandName | string | A lowercase identifier for whitelist checks | 'noclip' |
| rawText | string | The full command text displayed in Discord | '/noclip' |

Example:
```lua
-- Logging a simple noclip command
exports['cx-adminlogger']:Log(source, 'noclip', '/noclip')
```

Discord Embed Result: A clean embed showing the command /noclip executed by the staff member.

### 2. Advanced Logging: `LogWithFields`

**cx-adminlogger** supports logging commands with additional context using "extra fields".

Extra fields are small pieces of structured information that appear inside the Discord embed. They are used to make logs easier to read, understand, and audit later.

Think of extra fields as answering these questions:
- **Who** was affected?
- **What** was affected?
- **How much**?
- **Why**?

#### What Are Extra Fields?

Extra fields are key → value pairs that appear inside the Discord embed.

Instead of only logging:
```
/giveitem 12 water 10
```

You can log:
- **Target:** 12
- **Item:** water
- **Amount:** 10

This makes logs readable at a glance and removes the need to manually parse commands.

#### When Should You Use Extra Fields?

Use extra fields when a command:
- Targets another player
- Gives or removes items
- Changes money, jobs, or permissions
- Needs audit clarity later

Do NOT use extra fields when:
- The command is a simple toggle
- The command only affects the executor
- There are no meaningful arguments

Examples:
- /noclip → no extra fields
- /admin → no extra fields
- /giveitem → use extra fields
- /bring → use extra fields
- /setjob → use extra fields

#### How the Export Works

cx-adminlogger provides an export specifically for logging with extra fields.

Call this export from any server-side script:

```lua
exports['cx-adminlogger']:LogWithFields(source, commandName, rawText, extraFields)
```

**Parameters:**

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `source` | number | The player who executed the command | `1` |
| `commandName` | string | A lowercase identifier for the command (used for whitelist checks) | `'giveitem'` |
| `rawText` | string | The full command as it was typed. This is what shows in the main "Command" section of the embed | `'/giveitem 12 water 10'` |
| `extraFields` | table | A table containing one or more field objects | See below |

#### What an Extra Field Looks Like

Each extra field is a table with three values:

- **`name`**: What the value represents (shown as the label in Discord)
- **`value`**: The actual value you want to display
- **`inline`**: `true` = fields sit next to each other, `false` = field takes full width

**Example field:**
```lua
{
  name = 'Target',
  value = '12',
  inline = true
}
```

#### Full Example

```lua
exports['cx-adminlogger']:LogWithFields(
  source,
  'giveitem',
  '/giveitem 12 water 10',
  {
    { name = 'Target', value = '12', inline = true },
    { name = 'Item', value = 'water', inline = true },
    { name = 'Amount', value = '10', inline = true }
  }
)
```

This produces a Discord embed that clearly shows:
- The command that was run
- Who ran it
- Who was targeted
- What item was involved
- How many were given

#### Inline vs Non-Inline Fields

- Use inline = true for:
  - Player IDs
  - Item names
  - Amounts
  - Short values

- Use inline = false for:
  - Reasons
  - Notes
  - Long text
  - Descriptions

**Example of a non-inline field:**
```lua
{
  name = 'Reason',
  value = 'Abuse of admin commands during active scenario',
  inline = false
}
```

#### Rule of Thumb

If the command affects something else, use extra fields. If it only affects the executor, basic logging is enough.

Extra fields exist to make logs readable, auditable, and professional — not noisy.

---

## Examples

### Example: QBX AdminMenu

qbx_adminmenu registers commands using lib.addCommand.

#### Step 1: Add a helper function near the top of the file.

```lua
local function logAdminCmd(source, cmdName, raw, args)
  local text = raw and raw ~= '' and '/' .. raw or '/' .. cmdName

  if (not raw or raw == '') and type(args) == 'table' and #args > 0 then
    text = '/' .. cmdName .. ' ' .. table.concat(args, ' ')
  end

  exports['cx-adminlogger']:Log(source, cmdName, text)
end
```

#### Step 2: Use it inside a command.

```lua
lib.addCommand('noclip', {
  help = 'Toggle NoClip',
  restricted = config.noclip
}, function(source, args, raw)
  logAdminCmd(source, 'noclip', raw, args)
  TriggerClientEvent('qbx_admin:client:ToggleNoClip', source)
end)
```

The command works exactly the same. It is now logged.

### Example: OX Inventory

ox_inventory also uses lib.addCommand, often for admin-only commands.

#### Helper Function

```lua
local function LogCmd(source, raw, fallbackCmd, args)
  local text

  if type(raw) == 'string' and raw ~= '' then
    text = '/' .. raw
  else
    if type(args) == 'table' and #args > 0 then
      text = '/' .. fallbackCmd .. ' ' .. table.concat(args, ' ')
    else
      text = '/' .. fallbackCmd
    end
  end

  local cmdName = fallbackCmd
  if type(raw) == 'string' and raw ~= '' then
    cmdName = raw:match('^(%S+)') or fallbackCmd
  end

  exports['cx-adminlogger']:Log(source, cmdName, text)
end
```

#### Usage

```lua
lib.addCommand({'additem', 'giveitem'}, {
  restricted = 'group.admin'
}, function(source, args, raw)
  LogCmd(source, raw, 'giveitem', args)
  -- existing ox_inventory logic
end)
```

### Example: qbx_medical

qbx_medical also uses lib.addCommand, often for admin-only commands.

#### Helper Function

Add this helper near the top of qbx_medical’s server file:

```lua
local function logAdminCmd(source, cmdName, raw, args)
    local text = raw and raw ~= '' and ('/' .. raw) or ('/' .. cmdName)

    if (not raw or raw == '') and type(args) == 'table' and #args > 0 then
        text = ('/%s %s'):format(cmdName, table.concat(args, ' '))
    end

    exports['cx-adminlogger']:Log(source, cmdName, text)
end
```

#### Usage

**/revive Command**
```lua
lib.addCommand('revive', {
    help = locale('info.revive_player_a'),
    restricted = 'group.admin',
    params = {
        { name = 'id', help = locale('info.player_id'), type = 'playerId', optional = true },
    }
}, function(source, args, raw)
    logAdminCmd(source, 'revive', raw, args)

    if not args.id then args.id = source end
    local player = exports.qbx_core:GetPlayer(tonumber(args.id))
    if not player then
        exports.qbx_core:Notify(source, locale('error.not_online'), 'error')
        return
    end

    revivePlayer(args.id)
end)
```

**/kill Command**
```lua
lib.addCommand('kill', {
    help = locale('info.kill'),
    restricted = 'group.admin',
    params = {
        { name = 'id', help = locale('info.player_id'), type = 'playerId', optional = true },
    }
}, function(source, args, raw)
    logAdminCmd(source, 'kill', raw, args)

    if not args.id then args.id = source end
    local player = exports.qbx_core:GetPlayer(tonumber(args.id))
    if not player then
        exports.qbx_core:Notify(source, locale('error.not_online'), 'error')
        return
    end

    lib.callback.await('qbx_medical:client:killPlayer', args.id)
end)
```

**/aheal Command**
```lua
lib.addCommand('aheal', {
    help = locale('info.heal_player_a'),
    restricted = 'group.admin',
    params = {
        { name = 'id', help = locale('info.player_id'), type = 'playerId', optional = true },
    }
}, function(source, args, raw)
    logAdminCmd(source, 'aheal', raw, args)

    if not args.id then args.id = source end
    local player = exports.qbx_core:GetPlayer(tonumber(args.id))
    if not player then
        exports.qbx_core:Notify(source, locale('error.not_online'), 'error')
        return
    end

    heal(args.id)
end)
```

---

## Command Whitelisting (Optional)

If you only want certain commands logged, edit `config.lua`.

```lua
Config.LogCommands = {
  'admin',
  'noclip',
  'giveitem',
  'removeitem',
  'setitem',
  'clearinv'
}
```

If this list is empty, everything passed to the exports is logged (staff-only).

---

## Testing

In-game, as a staff member, run:

```
/cmdlogtest
```

If configured correctly, a Discord embed will appear instantly.

---


