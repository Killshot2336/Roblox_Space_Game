--!strict
-- Resolves ArtConfig IDs to rbxasset URLs and optionally swaps Parts for MeshParts.
local ArtConfig = require(script.Parent.Parent.Config.ArtConfig)

local ArtResolve = {}

export type MeshEntry = {
	MeshId: number,
	TextureId: number,
	Scale: Vector3?,
}

local function idToContent(prefix: string, id: number): string?
	if type(id) ~= "number" or id <= 0 then
		return nil
	end
	return prefix .. "://" .. tostring(id)
end

function ArtResolve.MeshContent(meshKey: string): string?
	local entry = (ArtConfig.Meshes :: any)[meshKey]
	if type(entry) ~= "table" then
		return nil
	end
	return idToContent("rbxassetid", entry.MeshId)
end

function ArtResolve.TextureContent(textureKey: string): string?
	local entry = (ArtConfig.Textures :: any)[textureKey]
	if type(entry) ~= "table" then
		return nil
	end
	return idToContent("rbxassetid", entry.TextureId)
end

function ArtResolve.DecalContent(decalKey: string): string?
	local entry = (ArtConfig.Decals :: any)[decalKey]
	if type(entry) ~= "table" then
		return nil
	end
	return idToContent("rbxassetid", entry.DecalId)
end

function ArtResolve.UiImage(group: string, key: string): string
	local bucket = (ArtConfig.UI :: any)[group]
	local entry = if type(bucket) == "table" then bucket[key] else nil
	if type(entry) == "table" and type(entry.AssetId) == "number" and entry.AssetId > 0 then
		return "rbxassetid://" .. tostring(entry.AssetId)
	end
	return ArtConfig.UI.FallbackImage
end

function ArtResolve.HasUploadedMesh(meshKey: string): boolean
	local entry = (ArtConfig.Meshes :: any)[meshKey]
	return type(entry) == "table" and type(entry.MeshId) == "number" and entry.MeshId > 0
end

-- Replaces a Part with a MeshPart when MeshId is set; otherwise leaves procedural Part.
function ArtResolve.ApplyMeshPart(part: Part, meshKey: string, parent: Instance?): MeshPart?
	if not ArtResolve.HasUploadedMesh(meshKey) then
		return nil
	end
	local entry = (ArtConfig.Meshes :: any)[meshKey] :: MeshEntry
	local meshUrl = ArtResolve.MeshContent(meshKey)
	if not meshUrl then
		return nil
	end
	local meshPart = Instance.new("MeshPart")
	meshPart.Name = part.Name
	meshPart.Size = part.Size
	meshPart.CFrame = part.CFrame
	meshPart.Anchored = part.Anchored
	meshPart.CanCollide = part.CanCollide
	meshPart.CanQuery = part.CanQuery
	meshPart.CanTouch = part.CanTouch
	meshPart.CastShadow = part.CastShadow
	meshPart.Color = part.Color
	meshPart.Material = part.Material
	meshPart.Transparency = part.Transparency
	meshPart.MeshId = meshUrl
	if type(entry.TextureId) == "number" and entry.TextureId > 0 then
		meshPart.TextureID = "rbxassetid://" .. tostring(entry.TextureId)
	end
	local scale = entry.Scale
	if scale then
		meshPart.Size = Vector3.new(part.Size.X * scale.X, part.Size.Y * scale.Y, part.Size.Z * scale.Z)
	end
	for name, value in part:GetAttributes() do
		meshPart:SetAttribute(name, value)
	end
	meshPart.Parent = parent or part.Parent
	part:Destroy()
	return meshPart
end

return ArtResolve
