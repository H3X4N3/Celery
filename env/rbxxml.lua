function getrbxproperties()
    local raw = game:HttpGet("https://raw.githubusercontent.com/thedoomed/Celery/main/RbxApi");
    local rbxapi = {};
    local t;
    local at = 1;
    local function nextkeyword()
        local keyword = "";
        -- due to some strange crap magic we cant parse
        -- out every occurence of '\r' character
        while (raw:sub(at, at) ~= ' ' and raw:sub(at, at) ~= '\n') do
            keyword = keyword .. raw:sub(at, at);
            at = at + 1;
        end
        return keyword;
    end
    while at < string.len(raw) do
        if (raw:sub(at, at + 6) == "\\Class ") then
            at = at + 7;
            local name = nextkeyword();
            
            t = {};
            t.Name = name;
            t.Type = "Class";
            t.BaseClass = name;
            
            at = at + 1;
            if (raw:sub(at, at) == ':') then
                at = at + 2;
                local inheritedclass = "";
                while (raw:sub(at, at) ~= ' ' and raw:sub(at, at) ~= '\n' and raw:sub(at, at) ~= '\r') do
                    inheritedclass = inheritedclass .. raw:sub(at, at);
                    at = at + 1;
                end
                t.BaseClass = inheritedclass;
                local x = t;
                while x.BaseClass ~= x.Name and rbxapi[x.BaseClass] do
                    for k,v in pairs(rbxapi[x.BaseClass]) do
                        if (v.Type == "Property") then
                            -- warn("Adding " .. v.Name .. " to rbxapi['" .. name .. "']");
                            t[k] = v;
                        end
                    end
                    x = rbxapi[x.BaseClass];
                end
            end
            
            rbxapi[name] = t;
            --print("rbxapi['" .. name .. "'] = ", rbxapi[name]);
        elseif (raw:sub(at, at + 5) == "\\Enum ") then
            at = at + 6;
            local name = "";
            while (raw:sub(at, at) ~= ' ' and raw:sub(at, at) ~= '\n' and raw:sub(at, at) ~= '\r') do
                name = name .. raw:sub(at, at);
                at = at + 1;
            end
            
            t = {};
            t.Name = name;
            t.Type = "EnumItem";
            t.RawType = "EnumItem";
            
            rbxapi[name] = t;
        end
        if (t and raw:sub(at, at + 9) == "\\EnumItem ") then
            if type(t.Name) == "string" then 
                at = at + 10;
                at = at + string.len(t.Name);
                local enumname = nextkeyword();
                
                local e = {};
                e.Name = enumname;
                e.Type = "EnumItem";
                e.RawType = "EnumItem";
                
                t[enumname] = e;
            end
        end
        if (t and raw:sub(at, at + 9) == "\\Property ") then
            if type(t.Name) == "string" then
                at = at + 10;
                local propertytype = nextkeyword();
                --               V-------->V
                -- \Property bool Instance.RobloxLocked [PluginSecurity]
                -- skip the current name to get to the property name

                at = at + string.len(t.Name) + 2;
                local propertyname = nextkeyword();
                
                local p = {};
                p.Type = "Property";
                p.Name = propertyname;
                p.RawType = propertytype;
                
                t[propertyname] = p;
            end
        end
        at = at + 1;
    end
    
    return rbxapi;
end

function getproperties(object)
    local rbxapi = getrbxproperties();
    return rbxapi[object.ClassName];
end

function saveinstance(first)
    local rbxapi = getrbxproperties();
    local header = '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n    <External>null</External>\n    <External>nil</External>\n';
    local cacheduids = {};
    
    -- create a randomized id per instance
    local function generatesuid(instance)
        for i = 1, #cacheduids do
            if cacheduids[i].Instance == instance then
                return cacheduids[i].SUID;
            end
        end
        local suid = "RBX";
        for i = 1,32 do
            suid = suid .. string.char(0x30 + math.random(0,9));
        end
        table.insert(cacheduids, {["Instance"] = instance, ["SUID"] = suid});
        return suid;
    end
    
    local function serialize(object, depth)
        if (object.ClassName == "DataModel") then
            local xml = "";
            local scan = {"Workspace", "Lighting", "Players", "ReplicatedFirst", "ReplicatedStorage", "StarterGui", "StarterPack", "StarterPlayer"}; 
            for i = 1,#scan do
                local service = game:GetService(scan[i]);
                if service then
                    print("Indexing DataModel --> '" .. service.Name .. "'...");
                    pcall(function() xml = xml .. serialize(service, depth) end);
                else
                    warn("DataModel --> '" .. service.Name .. "' not found!");
                end
            end
            return xml;
        end
        
        if (object.Parent) then
            if (object.Parent.ClassName == "DataModel") then
                local folder = Instance.new("Folder");
                folder.Name = object.Name;
                for _,v in pairs(object:GetChildren()) do
                    pcall(function()
                        v.Archivable = true;
                        v:Clone().Parent = folder; 
                    end);
                end
                object = folder;
            end
        end

        local properties = rbxapi[object.ClassName];
        local xml = string.rep(' ', depth * 4);
        local suid = generatesuid(object);
        
        xml = xml .. "<Item class=\"" .. object.ClassName .. "\" referent=\"" .. suid .. "\">\n";
        depth = depth + 1;
        xml = xml .. string.rep(' ', depth * 4);
        xml = xml .. "<Properties>\n";
        depth = depth + 1;
        xml = xml .. string.rep(' ', depth * 4);
        xml = xml .. "<BinaryString name=\"AttributesSerialize\"></BinaryString>\n";
        xml = xml .. string.rep(' ', depth * 4);
        
        for k,v in pairs(properties) do
            local prop = nil;
            local proptype = properties[k].RawType;
            local rawproptype = proptype;
            local propname = k;
            pcall(function()
                prop = object[propname];
            end);
            if not prop then
                -- splice out any possible '\r' characters
                -- at the end since if we couldnt above
                pcall(function()
                    propname = propname:sub(1, string.len(propname) - 1);
                    rawproptype = propname;
                    prop = object[propname];
                end);
            end
            if prop and proptype then
                if proptype == "BrickColor" then
                    --proptype = "Color3uint8"; -- 'BrickColor' is deprecated
                    --propname = "Color3uint8";
                    --rawproptype = "Color3uint8";
                elseif proptype == "Object" then
                    proptype = "Ref";
                    rawproptype = "Ref";
                elseif propname == "Color" then
                    proptype = "Color3";
                    rawproptype = "Color3";
                elseif rbxapi[proptype] then
                    if rbxapi[proptype].RawType == "EnumItem" then
                        -- enums found in the api get handled differently
                        proptype = "EnumItem";
                    end
                end
                
                xml = xml .. "<" .. rawproptype .. " name=\"" .. propname .. "\">";
                
                if (proptype == "Vector2") then
                    xml = xml .. "<X>" ..tostring(prop.X).. "</X><Y>" ..tostring(prop.Y).. "</Y>";
                elseif (proptype == "Vector3") then
                    xml = xml .. "<X>" ..tostring(prop.X).. "</X><Y>" ..tostring(prop.Y).. "</Y><Z>" ..tostring(prop.Z).. "</Z>";
                elseif (proptype == "Color3") then
                    xml = xml .. "<R>" ..tostring(prop.R).. "</R><G>" ..tostring(prop.G).. "</G><B>" ..tostring(prop.B).. "</B>";
                elseif (proptype == "Color3uint8") then
                    local rgbavalue = bit32.bor(bit32.bor(bit32.bor(bit32.lshift(0xFF, 24), bit32.lshift(0xFF * prop.r, 16)), bit32.lshift(0xFF * prop.g, 8)), 0xFF * prop.b);
                    xml = xml .. tostring(rgbavalue);
                elseif (proptype == "BrickColor") then
                    xml = xml .. tostring(prop.Number)
                elseif (proptype == "Content") then
                    xml = xml .. "<url>" ..tostring(prop).. "</url>";
                elseif (proptype == "Ref") then
                    if prop == object then
                        xml = xml .. suid;
                    else
                        local refsuid = generatesuid(prop);
                        if refsuid ~= nil then
                            xml = xml .. refsuid;
                        end
                    end
                elseif (proptype == "EnumItem") then
                    xml = xml .. tostring(prop.Value);
                elseif (proptype == "CoordinateFrame") then
                    xml = xml .. "<X>" ..tostring(prop.X).. "</X><Y>" ..tostring(prop.Y).. "</Y><Z>" ..tostring(prop.Z).. "</Z>";
                    --xml = xml .. "<R00>" .. tostring(prop.RightVector.x) .. "</R00>";
                    --xml = xml .. "<R01>" .. tostring(prop.RightVector.y) .. "</R01>";
                    --xml = xml .. "<R02>" .. tostring(prop.RightVector.z) .. "</R02>";
                    --xml = xml .. "<R10>" .. tostring(prop.UpVector.x) .. "</R10>";
                    --xml = xml .. "<R11>" .. tostring(prop.UpVector.y) .. "</R11>";
                    --xml = xml .. "<R12>" .. tostring(prop.UpVector.z) .. "</R12>";
                    --xml = xml .. "<R20>" .. tostring(prop.LookVector.x) .. "</R20>";
                    --xml = xml .. "<R21>" .. tostring(prop.LookVector.y) .. "</R21>";
                    --xml = xml .. "<R22>" .. tostring(prop.LookVector.z) .. "</R22>";
                    xml = xml .. "<R00>1</R00>";
                    xml = xml .. "<R01>0</R01>";
                    xml = xml .. "<R02>0</R02>";
                    xml = xml .. "<R10>0</R10>";
                    xml = xml .. "<R11>1</R11>";
                    xml = xml .. "<R12>0</R12>";
                    xml = xml .. "<R20>0</R20>";
                    xml = xml .. "<R21>0</R21>";
                    xml = xml .. "<R22>1</R22>";
                elseif (proptype == "Faces") then
                    xml = xml .. "<Bottom>" .. tostring(prop.Bottom) .. "</Bottom>";
                    xml = xml .. "<Top>" .. tostring(prop.Top) .. "</Top>";
                    xml = xml .. "<Left>" .. tostring(prop.Left) .. "</Left>";
                    xml = xml .. "<Right>" .. tostring(prop.Right) .. "</Right>";
                    xml = xml .. "<Back>" .. tostring(prop.Back) .. "</Back>";
                    xml = xml .. "<Front>" .. tostring(prop.Front) .. "</Front>";
                else -- token, string, int, float, etc. just use tostring
                    xml = xml .. tostring(prop);
                end
                
                xml = xml .. "</" .. rawproptype .. ">\n";
                xml = xml .. string.rep(' ', depth * 4);
            end
        end
        
        xml = xml .. "<BinaryString name=\"Tags\"></BinaryString>\n";
        depth = depth - 1;
        xml = xml .. string.rep(' ', depth * 4);
        xml = xml .. "</Properties>\n";
        
        -- serialize the instance's children
        for _,v in ipairs(object:GetChildren()) do
            pcall(function() xml = xml .. serialize(v, depth) end);
        end
        
        depth = depth - 1;
        xml = xml .. string.rep(' ', depth * 4);
        xml = xml .. "</Item>\n";
        return xml;
    end
    
    local xml = serialize(first, 1);
    xml = header .. xml .. '</roblox>';
    
    return xml;
end

function saveplace()
    return saveinstance(game);
end

savegame = saveplace;
