--!strict
-- Validate.luau — pure payload validators for the RemoteService pipeline.
-- Plain values in, ErrorCode? out: nil = valid. No game services, no
-- yields — safe to require from both sides of the boundary. Handlers call
-- these inside their own bodies (architecture's registration example);
-- the pipeline never validates on a handler's behalf.

local Types = require(script.Parent.Types)

local Validate = {}

-- noArgs rejects any client-supplied argument. RequestSnapshot carries no
-- payload by design, so any argument is forged traffic, not a shape
-- variant. select("#", ...) counts explicit nils — FireServer(nil) is
-- rejected too.
function Validate.noArgs(...: any): Types.ErrorCode?
	if select("#", ...) > 0 then
		return "INVALID_PAYLOAD"
	end
	return nil
end

return Validate
