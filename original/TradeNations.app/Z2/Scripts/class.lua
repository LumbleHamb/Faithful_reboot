--[[---------------------------------------------------------------------------

    Short and simple implementation of classes for Lua.

    Features inheritance, default member fields and constructors.

---------------------------------------------------------------------------]]--

print "Loaded class"

function table.copy( aTable )
    local copy = {}
    for key, value in pairs(aTable) do
        copy[key] = value
    end
    return copy
end

-------------------------------------------------------------------------------

local function __init() end

-------------------------------------------------------------------------------

local function __free() end

-------------------------------------------------------------------------------

local function __extends( sub, super )
    if not super then
        print "[!] Attempt to extend without specifying a super class."
        return
    end

    getmetatable( sub ).__index = super
    -- Allows chaining of extends() after class definition
    return sub
end

-------------------------------------------------------------------------------

local function __locknewindex( object, key, value )
    print("[!] Attempt to add new member '" .. key .. "' to an object.")
end

-------------------------------------------------------------------------------

local function __new( class, args )
    if not class then
        print "[!] Attempt to create instance of invalid class."
        return nil
    end

    local instance = table.copy( class.__defaults )

    -- Recurse up the class hierarchy
    local super = getmetatable(class).__index
    while super ~= nil do
        -- Copy the default values, preferring more-derived defaults
        for key, value in pairs(super.__defaults) do
            if instance[key] == nil then
                instance[key] = value
            end
        end
        super = getmetatable(super).__index
    end

    -- Create an empty args table if it's not there
    args = args or {}
    -- Copy over any member initializers in args
    for key, value in pairs(args) do
        if instance[key] ~= nil then
            instance[key] = value
            args[key] = nil
        end
    end

    setmetatable( instance, { __newindex = __locknewindex, __index = class } )
    instance:init( args )
    return instance

end

-------------------------------------------------------------------------------

function class( defaults )

    local newClass = {
        init        = __init,
        free        = __free,
        extends     = __extends,
        __defaults  = defaults or {}
    }

    -- Enable C++-style constructor invocation
    return setmetatable( newClass, { __call = __new } )

end

-------------------------------------------------------------------------------
