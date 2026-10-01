--!strict
-- Types.luau — canonical shared type definitions.
-- Story 1.2 scope: minimal v1 profile shape ONLY. No trade types
-- (Story 4.1), no setsCompleted (Epic 3) — those arrive via forward
-- migration, never by pre-creating unused fields.
-- Story 1.4 adds: ErrorCode (the RemoteService rejection taxonomy).

export type ProvenanceEntry = {
	itemDefId: number,
	source: string,
	acquiredAt: number,
}

export type ProfileData = {
	schemaVersion: number,
	vault: { [number]: number },
	provenance: { ProvenanceEntry },
	capacity: number,
}

-- Error codes are UPPER_SNAKE strings by convention. Open alias (not a
-- literal union) so later stories can reject with new codes without
-- editing this module first. Story 1.4 scope: the RATE_LIMITED /
-- NO_ACTIVE_PROFILE / INVALID_PAYLOAD rejection taxonomy.
export type ErrorCode = string

return nil
