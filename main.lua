-- Main for Love 2D Maze
-- Written by Rob Probin July 2018, in the Lake District, UK.
-- Copyright (c) 2018 Rob Probin
require('utils')
require('strict')

-- @todo items:
-- * Collision detect with walls (to 0.1 to wall)
-- * Fix step left and right
-- * Other things in maze? (round smiley facces? caves monsters?)


-- sizes in meters
local wall_width = 3.0
local wall_height = 2.0
local player_height = 1.2
local clip_z_depth = 0.01
local view_scale = 2.1

-- player vars
local pos_x = 1 -- 5
local pos_z = 1 -- -1
local direction = 0 -- 180

---[[
local maze = [[
+--+--+--+--+==+
|        |  :  :
+--+--+  +--+  +
|        |  |  |
+  +  +--+  +  +
|              |
+--+--+--+--+--+
]]
--]]

--[[
local maze = [[
+--+--+  +  +  +
                
+  +  +  +  +  +
                
+  +  +  +  +  +
                
+  +  +  +  +  +
]]
--]]

local bin_maze = {}
local maze_points = {}      -- Indexes 1,2,3 are original x,y,z. Indexes 4,5 xp, yp translated, rotated, perspective
--local maze_vertex = {}
local wall_faces = {}   -- contains list of edges that make up the face
local display_2d_polys = {}

function add_bin_maze_wall(x, y, direction)
    if bin_maze[y] == nil then
        bin_maze[y] = { [x] = direction }
    else
        local v = bin_maze[y][x]
        if v then
            v = v + direction
        else
            v = direction
        end
        bin_maze[y][x] = v
    end
end

function get_shared_point(x, z, direction, level)
    --print(x, z, direction, level)
    local y1 = 0
    if level == "top" then
        y1 = wall_height
    end
    -- convert from x/z maze position to 3d position
    local x1 = x * wall_width
    local z1 = z * wall_width
    if direction == "nw" then
        x1 = x1 - (wall_width/2)
        z1 = z1 - (wall_width/2)
    elseif direction == "ne" then
        x1 = x1 + (wall_width/2)
        z1 = z1 - (wall_width/2)
    elseif direction == "sw" then
        x1 = x1 - (wall_width/2)
        z1 = z1 + (wall_width/2)
    else -- "se"
        x1 = x1 + (wall_width/2)
        z1 = z1 + (wall_width/2)
    end
    
    --print(#maze_points, x1, y1, z1)
    for k, vertex in ipairs(maze_points) do
        local x2, y2, z2 = unpack(vertex)
        --print("search", vertex, x2, y2, z2)   
        if x1 == x2 and y1 == y2 and z1 == z2 then
            --print("Shared", x1, y1, z1)
            return vertex
        end
    end
    
    local new_vertex = { x1, y1, z1, ["walls"] = {}  }
    --print("new", x1, y1, z1)
    table.insert(maze_points, new_vertex)
    return new_vertex
end

function add_3d_wall(x, z, direction, attribute)
    -- NOTE: 3d domain uses Z as depth into scene, x and z as coordinates into the plane
    -- walls have 4 points
    local p1, p2, p3, p4
    if direction == 1 then
        p1 = get_shared_point(x, z, "nw", "top")
        p2 = get_shared_point(x, z, "ne", "top")
        p3 = get_shared_point(x, z, "ne" , "bottom")
        p4 = get_shared_point(x, z, "nw" , "bottom")
    elseif direction == 2 then
        p1 = get_shared_point(x, z, "ne", "top")
        p2 = get_shared_point(x, z, "se" , "top")
        p3 = get_shared_point(x, z, "se", "bottom")
        p4 = get_shared_point(x, z, "ne" , "bottom")
    elseif direction == 4 then
        p1 = get_shared_point(x, z, "se", "top")
        p2 = get_shared_point(x, z, "sw", "top")
        p3 = get_shared_point(x, z, "sw" , "bottom")
        p4 = get_shared_point(x, z, "se" , "bottom")
    elseif direction == 8 then
        p1 = get_shared_point(x, z, "sw", "top")
        p2 = get_shared_point(x, z, "nw", "top")
        p3 = get_shared_point(x, z, "nw" , "bottom")
        p4 = get_shared_point(x, z, "sw" , "bottom")
    else
        error("Unknown direction " .. tostring(direction))
    end

    local wall = { p1, p2, p3, p4, ["zclip"] = 0, attr=attribute }
    
    -- add a back reference to the wall
    table.insert(p1.walls, wall)
    table.insert(p2.walls, wall)
    table.insert(p3.walls, wall)
    table.insert(p4.walls, wall)
    table.insert(wall_faces, wall)
end

function add_wall(x, y, direction)
    add_bin_maze_wall(x, y, direction)
    --add_3d_wall(x, y ,direction)
end

function add_north_south_wall(x, y, attr)
    add_wall(x, y, 1)
    add_wall(x, y-1, 4)
    
    attr = attr or "-"
    add_3d_wall(x, y ,1, attr)
end


function add_east_west_wall(x, y, attr)
    add_wall(x, y, 8)
    add_wall(x-1, y, 2)
    
    attr = attr or "|"
    add_3d_wall(x, y ,8, attr)
end

function generic_line_parser(line, y, match_table)
    local x = 1
    for segment in line:gmatch("..?.?") do
        --print(">"..segment.."<")
        local f = match_table[segment]
        if f then
            f(x, y)
        else
            error(string.format("Didn't understand segment >%s< (length %d) in line >%s<", segment, #segment, line))
        end        
        x = x + 1
    end
end

function convert_north_line(line, y)
    generic_line_parser(line, y, { 
            ["+--"] = add_north_south_wall, 
            ["+=="] = function(x, y) add_north_south_wall(x, y, ":") end, 
            ["+  "] = function() end, 
            ["+"] = function() end
        })        
end

function convert_east_line(line, y)
    generic_line_parser(line, y, { 
            ["|  "] = add_east_west_wall, 
            ["|"] = add_east_west_wall, 
            [":  "] = function(x, y) add_east_west_wall(x, y, ":") end, 
            [":"] = function(x, y) add_east_west_wall(x, y, ":") end, 
            ["   "] = function() end,
            [" "] = function() end
        })
end

function convert_walls_to_coords()
    --print("*" .. string.format("%q", maze) .. "*")
    --print("*" .. maze .. "*")
    local north_wall_flag = true
    local size = nil
    local y = 1
    for l in maze:gmatch("[^\r\n]+") do
      if size then
        if size ~= #l then
          error("maze line size problem", size, l)
        end
      else
        size = #l
      end
      --if size then
      --  print("maze line length problem")
      --  error()
      --end

      --print("*" .. string.format("%q", l) .. "*")
      if north_wall_flag then
        convert_north_line(l, y)
      else
        convert_east_line(l, y)
        y = y + 1
      end
      north_wall_flag = not north_wall_flag
    end
end

local focal_length = 1
local screen_offset_x = 1
local screen_offset_y = 1
    
function perspective_projection(x1, y1, z1)
    -- perspective projection
    local xp = focal_length * x1 / z1
    local yp = focal_length * y1 / z1
    
    --print("persp.", xp, yp)
    
    -- transform for screen center
    xp = xp + screen_offset_x
    yp = - yp + screen_offset_y
    
    --print("screen transform", xp, yp)

    return xp, yp
end


function translate_rotate_perspective_projection(point_list, playerx, playery, playerz, ry)
    -- using combining the operations into a 4x4 matrix and applying that 
    -- is the fastest. However, since we are only translating in 3 directions, 
    -- rotating in 1 direction then we use discrete equations.
    
    ry = (ry / 180) * math.pi
    local cosA = math.cos(ry)
    local sinA = math.sin(ry)

    focal_length = love.graphics.getWidth() / view_scale

    -- wall is about 1/2 screen width???
    --local screen_scale = love.graphics.getWidth() / view_scale
    screen_offset_x = love.graphics.getWidth() / 2
    screen_offset_y = love.graphics.getHeight() / 2
    
    -- no backface culling because these wall 2d planes are actually sheets with two sides (3d)
    for k, vertex in ipairs(point_list) do
        local x1, y1, z1 = unpack(vertex)
        --print("base", x1, y1, z1)
        -- translation to player position
        x1 = x1 - playerx
        y1 = y1 - playery
        z1 = z1 - playerz
        
        --print("translated", x1, y1, z1)

        -- rotation around player https://en.wikipedia.org/wiki/Rotation_%28mathematics%29
        local x1_new = x1 * cosA - z1 * sinA
        local z1_new = x1 * sinA + z1 * cosA
        x1 = x1_new
        z1 = z1_new
        --print("rotated", x1, y1, z1)
        
        -- scale from meters to pixels
        --x1 = x1 * screen_scale
        --y1 = y1 * screen_scale
        --z1 = z1 * screen_scale
        --print("scaled", x1, y1, z1)
        
        local xp
        local yp
        local clip_required = false
        if z1 < clip_z_depth then
            clip_required = true
            
            for k,v in ipairs(vertex["walls"]) do
                v.zclip = v.zclip + 1
            end
            
        else
            xp, yp = perspective_projection(x1, y1, z1)
        end
    
        vertex.xp = xp
        vertex.yp = yp
        vertex.clip = clip_required
        vertex.z = z1_new
        -- for debug
        vertex.x = x1_new
        vertex.y = y1
    end
end


--[[
function create_display_polys()
    for k,wall in ipairs(wall_faces) do
        local x1, y1 = wall[1][4], wall[1][5]
        local x2, y2 = wall[2][4], wall[2][5]
        local x3, y3 = wall[3][4], wall[3][5]
        local x4, y4 = wall[4][4], wall[4][5]
    end
end
--]]

function find_clip_z_depth_intersection_point(vertex1, vertex2)
    local x1, y1, z1 = vertex1.x, vertex1.y, vertex1.z
    local x2, y2, z2 = vertex2.x, vertex2.y, vertex2.z
    
    -- General equation of a line in 2d:
    --   y = mx + c
    --  Where m is the slope and c is the y intercept.
    -- 
    -- 
    -- In our 3D case, we are interested in two specific cases, from the equation of a line.
    -- y = slope_yz * z + cy
    -- x = slope_xz * z + cx
    -- 
    -- where we define the z as the clip point.
    -- 
    -- The slope in these cases is:
    
    local slope_yz = (y2 - y1) / (z2 - z1)
    local slope_xz = (x2 - x1) / (z2 - z1)
    
    -- NOTE: We know z2, z1 are not the same point (i.e. z2 - z1 = 0) because otherwise the whole line would have been clipped)
    -- 
    -- The intersect in these cases is (we can use either point), using the equation above:
    
    local cy = y1 - slope_yz * z1
    local cx = x1 - slope_xz * z1
    
    -- So at z = clip_z_depth the entire equation looks like:
    
    local y = slope_yz * clip_z_depth + cy
    local x = slope_xz * clip_z_depth + cx

    return x, y, clip_z_depth
end

function print_wall_coords(wall, type_)
    print(type_)
    
    for k,wallv in ipairs(wall) do
        print(k, ":", wallv.x, wallv.y, wallv.z)
    end
end

function draw_wall(wall)
    -- Clipping for Z
    -- clipping https://en.wikipedia.org/wiki/Clipping_(computer_graphics)
    -- https://stackoverflow.com/questions/7604322/clip-matrix-for-3d-perspective-projection
    -- https://en.wikipedia.org/wiki/Cohen%E2%80%93Sutherland_algorithm
    local magic=0
    local x1, y1, clip1 = wall[1].xp, wall[1].yp, wall[1].clip
    local x2, y2, clip2 = wall[2].xp, wall[2].yp, wall[2].clip
    local x3, y3, clip3 = wall[3].xp, wall[3].yp, wall[3].clip
    local x4, y4, clip4 = wall[4].xp, wall[4].yp, wall[4].clip

    if wall.zclip == 4 then
        return
    elseif wall.zclip == 0 then
        -- no clipping required
    elseif wall.zclip == 2 then
        
        local new_point_list = {}
        -- because of geometry, it must be two consecutive points that need clipping.
        if clip1 then
            if clip4 then
                -- two new points are on line 1-2 and 3-4                
                local x, y, z = find_clip_z_depth_intersection_point(wall[1], wall[2])
                x1, y1 = perspective_projection(x, y, z)
                x, y, z = find_clip_z_depth_intersection_point(wall[3], wall[4])
                x4, y4 = perspective_projection(x, y, z)
                
                magic=1
            elseif clip2 then
                -- two new points are on line 4-1 and 2-3                
                local x, y, z = find_clip_z_depth_intersection_point(wall[4], wall[1])
                x1, y1 = perspective_projection(x, y, z)
                x, y, z = find_clip_z_depth_intersection_point(wall[2], wall[3])
                x2, y2 = perspective_projection(x, y, z)
                
                magic=2
            else
                error("Error clip Geometry is 1 and 3")
            end
        elseif clip3 then
            if clip2 then
                -- two new points are on line 3-4 and 1-2
                local x, y, z = find_clip_z_depth_intersection_point(wall[1], wall[2])
                x2, y2 = perspective_projection(x, y, z)
                x, y, z = find_clip_z_depth_intersection_point(wall[3], wall[4])
                x3, y3 = perspective_projection(x, y, z)                
                
                magic=3
            elseif clip4 then
                -- two new points are on line 2-3 and 4-1
                local x, y, z = find_clip_z_depth_intersection_point(wall[2], wall[3])
                x3, y3 = perspective_projection(x, y, z)
                x, y, z = find_clip_z_depth_intersection_point(wall[4], wall[1])
                x4, y4 = perspective_projection(x, y, z)
                
                magic=4
            else
                error("Error clip Geometry is 3 and 1") -- even on error cases this shouldn't happen
            end
        else
            error("Error clip Geometry is 2 and 4")
        end
    
        --print("clip type", magic)
        --os.exit(1)
    elseif wall.zclip ~= 0 then
        error("As yet unsupported wall zclip number " .. tostring(wall.zclip))
    end

    local red = 200
    local green = 150
    local blue = 150
    local alpha = 255
    --local alpha = 100
    
    if wall.attr == "|" then
        blue = 160
    elseif wall.attr == ":" then
        red = 150
        green = 150
        blue = 200
    end
    
    --[[
    if magic == 1 then
        red = 0
    elseif magic == 2 then
        red = 255
        blue = 0
        green = 0
    elseif magic == 3 then
        red = 0
        blue = 0
        green = 255
    elseif magic == 4 then
        red = 255
        blue = 0
        green = 255
    end
    --]]
    
    --print(x1, y1, x2, y2, x3, y3, x4, y4) 
    love.graphics.setColor( red, green, blue, alpha)
    love.graphics.polygon('fill', x1, y1, x2, y2, x3, y3, x4, y4)
    
    local red = 0
    local green = 0
    local blue = 0
    love.graphics.setColor( red, green, blue)
    love.graphics.polygon('line', x1, y1, x2, y2, x3, y3, x4, y4)
end

function wall_z_compare(wall1, wall2)
    local average_z1 = wall1[1].z + wall1[2].z + wall1[3].z + wall1[4].z
    local average_z2 = wall2[1].z + wall2[2].z + wall2[3].z + wall2[4].z
    return average_z1 > average_z2
end

function draw_maze()
    -- Need to resolve in to z depth (for painters algorithm) or use depth buffer
    -- or some other method of sorting (E.g. print based on maze position)
    
    -- We currently use painter Algorithm
    table.sort(wall_faces, wall_z_compare)
    for k,wall in ipairs(wall_faces) do
        draw_wall(wall)
    end
end

function clear_walls_zclip()
    for k,v in ipairs(wall_faces) do
        v.zclip = 0
    end
end

function love.load()
    local red = 200
    local green = 200
    local blue = 200

    love.graphics.setBackgroundColor( red, green, blue )
    convert_walls_to_coords()
end


--[[
function north_wall(x, y, direction)
    ix = math.trunc(x)
    iy = math.trunc(y)
end
--]]


function love.draw()
    clear_walls_zclip()
    local x1 = pos_x * wall_width
    local z1 = pos_z * wall_width
    translate_rotate_perspective_projection(maze_points, x1, player_height, z1, direction)
    draw_maze()
    
    local major, minor, revision, codename = love.getVersion()
    local str = string.format("%d.%d.%d %s", major, minor, revision, codename)
    love.graphics.print("Hello World! "..str, 400, 300)
    
    str = string.format("X=%.1f Z=%.1f Dir=%d", pos_x, pos_z, direction)
    love.graphics.print(str, 400, 320)
    
    love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
    
    --print_table(bin_maze)
    --love.event.quit()
end

local keys = {}
local rotation_angle_per_sec_in_degrees = 90
local move_per_second_in_maze_cells = 3

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "w" then
        keys['forward'] = true
    elseif key == "s" then
        keys['backward'] = true
    elseif key == "a" then
        keys['left'] = true
    elseif key == "d" then
        keys['right'] = true
    elseif key == "q" then
        keys['step_left'] = true
    elseif key == "e" then
        keys['step_right'] = true
    end
end

function love.keyreleased(key)
    if key == "w" then
        keys['forward'] = false
    elseif key == "s" then
        keys['backward'] = false
    elseif key == "a" then
        keys['left'] = false
    elseif key == "d" then
        keys['right'] = false
    elseif key == "q" then
        keys['step_left'] = false
    elseif key == "e" then
        keys['step_right'] = false
    end
end

function step_if_legal(new_x, new_z)
    local x_size = math.abs(new_x - pos_x)
    local z_size = math.abs(new_z - pos_z)
    if (x_size * x_size + z_size * z_size) > 1 then
        -- trying to step more than one cell is not allowed`
    end
    -- use cohens-sutherland clipping, or step based?
    pos_x = new_x
    pos_z = new_z
end

function love.update(dt)
    local move = move_per_second_in_maze_cells * dt
    local ry = (direction / 180) * math.pi
    local moveZ = move * math.cos(ry)
    local moveX = move * math.sin(ry)
    
    if keys['forward'] and not keys['backward'] then
        -- step_if_legal(pos_x, pos_z + move)
        step_if_legal(pos_x + moveX, pos_z + moveZ)
    end
    if keys['backward'] and not keys['forward'] then    
        -- step_if_legal(pos_x, pos_z - move)
        step_if_legal(pos_x - moveX, pos_z - moveZ)
    end
    if keys['step_left'] and not keys['step_right'] then
        step_if_legal(pos_x - moveZ, pos_z - moveX)
    end
    if keys['step_right'] and not keys['step_left'] then    
        step_if_legal(pos_x + moveZ, pos_z + moveX)
    end
    if keys['left'] and not keys['right'] then
        direction = direction - (rotation_angle_per_sec_in_degrees * dt)
        if direction < 0 then
            direction = direction + 360
        end
    end
    if keys['right'] and not keys['left'] then
        direction = direction + (rotation_angle_per_sec_in_degrees * dt)
        if direction >= 360 then
            direction = direction - 360
        end
    end
end

