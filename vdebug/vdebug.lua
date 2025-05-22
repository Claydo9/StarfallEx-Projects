--@name vdebug
--@author Claydo
--@shared


vdebug = {}
vdebug.__renderStack = {}


-- Function for easy storage of X-Y coordinates.
local function Vector2( x, y )
   return { ["x"] = x, ["y"] = y } 
end


-- Function that takes renderStruct arguments and returns a formatted table. 
-- Tables are formatted by splitting them in half between functions and arguments and then returning a table of all functions and arguments seperately.
local function renderStruct( ... )
    local args = { ... }
    local pairing = math.floor( #args / 2 )
    
    local pairA = {}
    local pairB = {}

    for i = 1, pairing do
        if type( args[i] ) == nil then error( "Struct pairing failure." ) end
        if type( args[i+pairing] ) == nil then args[i+pairing] = 0 end
        table.insert( pairA, args[i] ) 
        table.insert( pairB, args[i+pairing] )
    end
    
    if #args % 2 > 0 then 
        for i = 1, #args - pairing * 2 do
            table.insert( pairB, args[i] )
        end
    end

    return {
        ["funcs"] = pairA,
        ["args"] = pairB
    }
end


-- Adds render instructions to the stack directly or by replication if required.
local function replicateStruct( struct )
    if CLIENT then
        table.insert( vdebug.__renderStack, struct )
    else
        vdebug.networkAddToRenderStack( struct )
    end
end

-- Optional function to create and automatically link a HUD to the chip executing.
function vdebug.initHUD()
    if CLIENT then
        net.start( "vdebug_init_hud" )
        net.send()
    else
        vdebug.__initHUD()
    end
end

if CLIENT then
    if hasPermission( "render.drawhud", player() ) or player() == owner() then enableHud( player(), true ) end

    -- Tries to pop the viewMatrix safely.
    local function tryPopMatrix()
        pcall( render.popViewMatrix )
    end

    -- Returns automatically unpacked arguments if function args are supplied in table form.
    local function autoUnpackArgs( args )
        if type( args ) == "table" then
            return unpack( args )
        else
            return args
        end
    end
  
    -- Exceptions for using 2D render functions in 3D context.
    local render2DExceptions = {
        "setcolor",
        "setfont"
    }


    -- Returns whether a function is listed as a 2D rendering exception, which allows specific 2D functions to be run in the 3D context.
    local function is2DException( func )
        for i, v in pairs( render2DExceptions ) do
            if func:find( v ) then return true end
        end
    
        return false
    end

    hook.add( "DrawHUD", "vdebug_hud_draw", function()
        -- Handling of the 3D rendering instructions, including excepted 2D functions like setColor and setFont.

        render.pushViewMatrix( { type = "3D" } )

        local RenderStack2D = {}

        for i, v in ipairs( vdebug.__renderStack ) do
            for idx, func in ipairs( v.funcs ) do

                if type( func ) == "string" then
                    if not string.lower( func ):find( "3d" ) and not is2DException( string.lower( func ) ) then table.insert( RenderStack2D, v ) continue end
                    if string.lower( func ):find( "vdebug.clientdefs." ) then
                        local exploded = string.explode( ".", func )
                        local callStr = exploded[#exploded]

                        vdebug.clientDefs[callStr]( autoUnpackArgs( v.args[idx] ) )
                        continue
                    end
    
                    render[func]( autoUnpackArgs( v.args[idx] ) )
                elseif type( func ) == "function" then
                    func( autoUnpackArgs( v.args[idx] ) )
                end
            end
        end

        -- Handling of 2D rendering excluding the excepted 2D functions like setColor and setFont.

        tryPopMatrix()

        for i, v in ipairs( RenderStack2D ) do
          for idx, func in ipairs( v.funcs ) do
                if type( func ) == "string" then
                    if string.lower( func ):find( "3d" ) then continue end
                    if string.lower( func ):find( "vdebug.clientdefs." ) then
                        local exploded = string.explode( ".", func )
                        local callStr = exploded[#exploded]

                        vdebug.clientDefs[callStr]( autoUnpackArgs( v.args[idx] ) )
                        continue
                    end
    
                    render[func]( autoUnpackArgs( v.args[idx] ) )
                elseif type( func ) == "function" then
                    func( autoUnpackArgs( v.args[idx] ) )
                end
            end
        end
    end )


    net.receive( "vdebug_add_to_render_queue", function()
        table.insert( vdebug.__renderStack, net.readTable() )
    end )

    net.receive( "vdebug_pop_render_stack", function()
        table.remove( vdebug.__renderStack, #vdebug.__renderStack )
    end )

    net.receive( "vdebug_purge_render_stack", function()
        table.empty( vdebug.__renderStack )
    end )

    -- Client special definitions
    -- Special definitions are debug drawing instructions that needed to be its own function instead of a pre-defined render function.
    -- Special definitions should be used by supplying the full table path of the function as a string in your regular instruction function. E.G. vdebug.cross() / vdebug.clientDefs.cross

    vdebug.clientDefs = {}
    
    function vdebug.clientDefs.cross( pos, size )
        local screenPos = pos:toScreen()

        local line1Start = Vector2( screenPos.x - size / 2, screenPos.y - size / 2 )
        local line1End = Vector2( screenPos.x + size / 2, screenPos.y + size / 2 )

        local line2Start = Vector2( screenPos.x - size / 2, screenPos.y + size / 2 )
        local line2End = Vector2( screenPos.x + size / 2, screenPos.y - size/ 2 )

        render.drawLine( line1Start.x, line1Start.y, line1End.x, line1End.y )
        render.drawLine( line2Start.x, line2Start.y, line2End.x, line2End.y )
    end

    function vdebug.clientDefs.text( pos, text, visDistance )
        if pos:getDistance( player():getPos() ) > visDistance then return end

        local screenPos = pos:toScreen()

        render.drawSimpleTextOutlined( screenPos.x, screenPos.y, text, 1, Color( 0, 0, 0 ), TEXT_ALIGN.CENTER, TEXT_ALIGN.CENTER )
    end

end


if SERVER then
    local clientInitialized = false

    -- This method of awaiting client init before sending render instructions is not ideal.
    hook.add( "ClientInitialized", "vdebug_client_init", function( p )
        if p == owner() then
            clientInitialized = true
        end
    end )

    -- Sends a net message with render instructions to be added to the client render stack.
    function vdebug.networkAddToRenderStack( struct )
        if not clientInitialized then timer.simple( 0.1, function() vdebug.networkAddToRenderStack( struct ) end ) return end

        net.start( "vdebug_add_to_render_queue" )
        net.writeTable( struct )
        net.send( find.allPlayers() )
    end

    function vdebug.__initHUD()
        if not prop.canSpawn() then timer.simple( 0.1, vdebug.__initHUD ) return end

        local comps = chip():getLinkedComponents()

        for i, v in pairs( comps ) do
            if not isValid( v ) then continue end
            if v:getClass() == "starfall_hud" then return end
        end

        local hud = prop.createComponent( chip():getPos() + Vector( 0, 0, chip():obbSize().z ), Angle( 0, 0, 0 ), "starfall_hud", "models/bull/dynamicbuttonsf.mdl", true )
        hud:linkComponent( chip() )
    end; net.receive( "vdebug_init_hud", vdebug.__initHUD )
end


-- Pops the last render instruction from the render stack.
function vdebug.popRenderStack()
    if CLIENT then
        table.remove( vdebug.__renderStack, #vdebug.__renderStack )
    else
        net.start( "vdebug_pop_render_stack" )
        net.send( find.allPlayers() )
    end
end


-- Purges the entire render stack.
function vdebug.purgeRenderStack()
    if CLIENT then
        table.empty( vdebug.__renderStack )
    else
        net.start( "vdebug_purge_render_stack" )
        net.send( find.allPlayers() )
    end
end

-- Definitions
-- Functions can be defined here for the library, call "renderStruct" to structure your render instructions for sending to the draw function. -
-- Generally you want to have your instructions in pairs of 2, one function, and one argument (table or single value.)
-- For functions that have un-equal function-argument ratios look at vdebug.cross / vdebug.clientDefs.cross.

function vdebug.wireframeBox( pos, angle, mins, maxs, ignorez, color )
    local struct = renderStruct( "setColor", "draw3DWireframeBox", color, { pos, angle, mins, maxs, ignorez } )

    replicateStruct( struct )
end

function vdebug.line( startP, endP, writeZ, color )
    local struct = renderStruct( "setColor", "draw3DLine", color, { startP, endP, writeZ } )

    replicateStruct( struct )
end

function vdebug.box( pos, angle, mins, maxs, color )
    local struct = renderStruct( "setColor", "draw3DBox", color, { pos, angle, mins, maxs } )

    replicateStruct( struct )
end

function vdebug.cross( pos, size, color )
    local struct = {
        ["funcs"] = {
            "setColor",
            "vdebug.clientDefs.cross"
        },
        ["args"] = {
            color,
            { pos, size }
        }
    }
    replicateStruct( struct )
end

function vdebug.triangle( v1, v2, v3, color )
    local struct = renderStruct( "setColor", "draw3DTriangle", color, { v1, v2, v3 } )

    replicateStruct( struct )
end

function vdebug.wireframeSphere( pos, radius, longSteps , latSteps, writez, color )
    local struct = renderStruct( "setColor", "draw3DWireframeSphere", color, { pos, radius, longSteps, latSteps, writez } )

    replicateStruct( struct )
end

function vdebug.sphere( pos, radius, longSteps, latSteps, writez, color )
   local struct = renderStruct( "setColor", "draw3DSphere", color, { pos, radius, longSteps, latSteps, writez } )

    replicateStruct( struct )
end

function vdebug.text( pos, text, color, visDistance )
    if type( visDistance ) == "nil" then visDistance = 300 end

    local struct = {
        ["funcs"] = {
            "setColor",
            "setFont",
            "vdebug.clientDefs.text"
        },
        ["args"] = {
            color,
            "ChatFont",
            { pos, text, visDistance }
        }
    }

    replicateStruct( struct )
end
