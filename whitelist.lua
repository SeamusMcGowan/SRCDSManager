local whitelist = {
	["00000000000000000"] = true, --Add pre-whitelisted IDs here (owners, admins, etc)
}

local tempWhitelist = {}

function addToWhitelist(id)
	tempWhitelist[id] = true
end

function removeFromWhitelist(id)
	tempWhitelist[id] = nil
end

function isWhitelisted(id)
	return whitelist[id] or tempWhitelist[id]
end

hook.Add("CheckPassword", "Whitelist_Password", function(id, _, _, _, name)
	if (!isWhitelisted(id)) then 
		return false, "Not whitelisted!"
	end
end)