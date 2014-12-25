
TOOL.Category = "Constraints"
TOOL.Name = "#tool.advaxis.name"

TOOL.ClientConVar["forcelimit"] = 0
TOOL.ClientConVar["torquelimit"] = 0
TOOL.ClientConVar["hingefriction"] = 0
TOOL.ClientConVar["nocollide"] = 0

if CLIENT then
    language.Add("tool.advaxis.name", "Advanced Axis")
    language.Add("tool.advaxis.desc", "Creates an axis constraint on an arbitrary axis")
    language.Add("tool.advaxis.0", "Click an object")
    language.Add("tool.advaxis.1", "Click a second object")
    language.Add("tool.advaxis.2", "Primary: Select first axis point\nSecondary: place axis on normal")
    language.Add("tool.advaxis.3", "Select second axis point")
end

function TOOL:BuildAxis()
    -- only server should create the constraint
    if CLIENT then return end

    -- grab cvars
    local forcelimit = self:GetClientNumber("forcelimit", 0)
    local torquelimit = self:GetClientNumber("torquelimit", 0)
    local friction = self:GetClientNumber("hingefriction", 0)
    local nocollide = self:GetClientNumber("nocollide", 0)
    -- compute axis points local to the physics objects (TODO: move to LeftClick/RightClick)
    local lpos1 = self.FirstObject:GetPhysicsObjectNum(self.FirstBone):WorldToLocal(self.FirstAxisPoint)
    local lpos2 = self.SecondObject:GetPhysicsObjectNum(self.SecondBone):WorldToLocal(self.SecondAxisPoint)
    -- create axis constraint
    local axis = constraint.Axis(
        self.FirstObject, self.SecondObject,
        self.FirstBone, self.SecondBone,
        lpos1, lpos2,
        forcelimit, torquelimit, friction, nocollide
    )
    
    -- add it to undo and cleanup
    undo.Create("advaxis")
        undo.AddEntity(axis)
        undo.SetPlayer(self:GetOwner())
    undo.Finish()
    self:GetOwner():AddCleanup("constraints", axis)
    
    -- clear saved info
    self.FirstObject = nil
    self.SecondObject = nil
    self.FirstBone = nil
    self.SecondBone = nil
    self.FirstAxisPoint = nil
    self.SecondAxisPoint = nil
end

function TOOL:LeftClick(tr)
    local stage = self:GetStage()
    if stage == 0 or stage == 1 then
        -- don't constrain players
        if IsValid(tr.Entity) and tr.Entity:IsPlayer() then return false end
        -- can't constrain without a physics object
        if SERVER and !util.IsValidPhysicsObject(tr.Entity, tr.PhysicsBone) then return false end
        if stage == 0 then
            -- save info
            self.FirstObject = tr.Entity
            self.FirstBone = tr.PhysicsBone
        else
            -- can't constrain a bone to itself
            if self.FirstObject == tr.Entity and self.FirstBone == tr.PhysicsBone then return false end
            -- save info
            self.SecondObject = tr.Entity
            self.SecondBone = tr.PhysicsBone
        end
        -- move to next stage
        self:SetStage(stage + 1)
    elseif stage == 2 then
        -- save first axis point and move to final stage
        self.FirstAxisPoint = tr.HitPos
        self:SetStage(3)
    elseif stage == 3 then
        -- save second axis point and build the constraint
        self.SecondAxisPoint = tr.HitPos
        self:BuildAxis()
        self:SetStage(0)
    else
        print("[advaxis] LeftClick(): wtf, stage = " .. stage)
        self:SetStage(0)
    end

    return true
end

function TOOL:RightClick(tr)
    -- don't do anything exept in stage 2
    if self:GetStage() != 2 then return false end
    -- don't do anything if hit data isn't valid
    if !tr.Hit then return false end

    -- save first point
    self.FirstAxisPoint = tr.HitPos
    -- compute second point
    -- TODO: will moving the second point further away make the constraint more stable?
    self.SecondAxisPoint = tr.HitPos + tr.HitNormal
    -- build constraint
    self:BuildAxis()
    self:SetStage(0)

    return true
end

function TOOL:Reload(tr)
    return false
end

function TOOL:Holster()
    -- clear saved info
    self.FirstObject = nil
    self.SecondObject = nil
    self.FirstBone = nil
    self.SecondBone = nil
    self.FirstAxisPoint = nil
    self.SecondAxisPoint = nil
    self:SetStage(0)
end
    