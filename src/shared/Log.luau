--!strict
-- Log.luau — shared structured logging wrapper. Format: plain text,
-- engine Output — `[ServiceName] message {context-table}`.
-- Destination: Roblox Output (`warn` for WARN/ERROR, `print` for INFO).
-- No external service at MVP. Shared-pure: requires no server or client
-- modules, only the engine RunService gate for INFO.
-- [Source: skills/planning-artifacts/game-architecture.md#Logging]

local RunService = game:GetService("RunService")

local Log = {}

function Log.info(context: string, message: string, data: {})
	if RunService:IsStudio() then
		print(("[%s] %s"):format(context, message), data)
	end
end

function Log.warn(context: string, message: string, data: {})
	warn(("[%s] %s"):format(context, message), data)
end

function Log.error(context: string, message: string, data: {})
	warn(("[%s] ERROR %s"):format(context, message), data)
end

return Log
