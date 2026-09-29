--!strict
-- Types.luau — canonical shared type definitions.
-- Story 1.2 scope: minimal v1 profile shape ONLY. No trade types
-- (Story 4.1), no setsCompleted (Epic 3) — those arrive via forward
-- migration, never by pre-creating unused fields.

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

return nil
