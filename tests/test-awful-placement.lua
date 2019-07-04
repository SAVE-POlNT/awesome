local awful = require("awful")
local gears = require("gears")
local beautiful = require("beautiful")
local test_client = require("_client")
local runner = require("_runner")

-- This test makes some assumptions about the no_overlap behavior which may not
-- be correct if the screen is in the portrait orientation.
if mouse.screen.workarea.height >= mouse.screen.workarea.width then
    print("This test does not work with the portrait screen orientation.")
    runner.run_steps { function() return true end }
    return
end

local tests = {}

local tb_height = gears.math.round(beautiful.get_font_height() * 1.5)
local border_width = beautiful.border_width

local class = "test-awful-placement"
local rule = {
    rule = {
        class = class
    },
    properties = {
        floating = true,
        placement = awful.placement.no_overlap + awful.placement.no_offscreen
    }
}
table.insert(awful.rules.rules, rule)

local function check_geometry(c, x, y, width, height)
    local g = c:geometry()
    if g.x ~= x or g.y ~= y or g.width ~= width or g.height ~= height then
        assert(false, string.format("(%d, %d, %d, %d) ~= (%d, %d, %d, %d)",
            g.x, g.y, g.width, g.height, x, y, width, height))
    end
end

local function default_test(c, geometry)
    check_geometry(c, geometry.expected_x, geometry.expected_y,
        geometry.expected_width  or geometry.width,
        geometry.expected_height or (geometry.height + tb_height))
    return true
end

local client_data = {}
local function add_client(args)
    local data = {}
    table.insert(client_data, data)
    local client_index = #client_data
    table.insert(tests, function(count)
        local name = string.format("client%010d", client_index)
        if count <= 1 then
            data.prev_client_count = #client.get()
            local geometry = args.geometry(mouse.screen.workarea)
            test_client(class, name, nil, nil, nil, {
                size = {
                    width = geometry.width,
                    height = geometry.height
                }
            })
            data.geometry = geometry
            return nil
        elseif #client.get() > data.prev_client_count then
            local c = data.c
            if not c then
                c = client.get()[1]
                assert(c.name == name)
                data.c = c
            end
            local test = args.test or default_test
            return test(c, data.geometry)
        end
    end)
end

-- Repeat testing 3 times.
for _, _ in ipairs{1, 2, 3} do

    -- The first 100x100 window should be placed at the top left corner.
    add_client {
        geometry = function(wa)
            return {
                width       = 100,
                height      = 100,
                expected_x  = wa.x,
                expected_y  = wa.y
            }
        end
    }

    -- Remember the first client data for the current iteration.
    local first_client_data = client_data[#client_data]

    -- The second 100x100 window should be placed to the right of the first
    -- window.  Note that this assumption fails if the screen is in the portrait
    -- orientation (e.g., the test succeeds with a 600x703 screen and fails with
    -- 600x704).
    add_client {
        geometry = function(wa)
            return {
                width       = 100,
                height      = 100,
                expected_x  = wa.x + 100 + 2*border_width,
                expected_y  = wa.y
            }
        end
    }

    -- Hide last client.
    do
        local data = client_data[#client_data]
        table.insert(tests, function()
            data.c.hidden = true
            return true
        end)
    end

    -- Another 100x100 client should be placed to the right of the first client
    -- (the hidden client should be ignored during placement).
    add_client {
        geometry = function(wa)
            return {
                width       = 100,
                height      = 100,
                expected_x  = wa.x + 100 + 2*border_width,
                expected_y  = wa.y
            }
        end
    }

    -- Minimize last client.
    do
        local data = client_data[#client_data]
        table.insert(tests, function()
            data.c.minimized = true
            return true
        end)
    end

    -- Another 100x100 client should be placed to the right of the first client
    -- (the minimized client should be ignored during placement).
    add_client {
        geometry = function(wa)
            return {
                width       = 100,
                height      = 100,
                expected_x  = wa.x + 100 + 2*border_width,
                expected_y  = wa.y
            }
        end
    }

    -- Hide last client, and make the first client sticky.
    do
        local data = client_data[#client_data]
        table.insert(tests, function()
            data.c.hidden = true
            first_client_data.c.sticky = true
            return true
        end)
    end

    -- Another 100x100 client should be placed to the right of the first client
    -- (the sticky client should be taken into account during placement).
    add_client {
        geometry = function(wa)
            return {
                width       = 100,
                height      = 100,
                expected_x  = wa.x + 100 + 2*border_width,
                expected_y  = wa.y
            }
        end
    }

    -- Hide last client, and put the first client on the tag 9 (because the
    -- first client is sticky, it should remain visible).
    do
        local data = client_data[#client_data]
        table.insert(tests, function()
            data.c.hidden = true
            first_client_data.c:tags{ root.tags()[9] }
            return true
        end)
    end

    -- Another 100x100 client should be placed to the right of the first client
    -- (the sticky client should be taken into account during placement even if
    -- that client seems to be on an unselected tag).
    add_client {
        geometry = function(wa)
            return {
                width       = 100,
                height      = 100,
                expected_x  = wa.x + 100 + 2*border_width,
                expected_y  = wa.y
            }
        end
    }

    -- The wide window should be placed below the two 100x100 windows.
    add_client {
        geometry = function(wa)
            return {
                width       = wa.width - 50,
                height      = 100,
                expected_x  = wa.x,
                expected_y  = wa.y + tb_height + 2*border_width + 100
            }
        end
    }

    -- The first large window which does not completely fit in any free area
    -- should be placed at the bottom left corner (no_overlap should place it
    -- below the wide window, and then no_offscreen should shift it up so that
    -- it would be completely inside the workarea).
    add_client {
        geometry = function(wa)
            return {
                width       = wa.width - 10,
                height      = wa.height - 50,
                expected_x  = wa.x,
                expected_y  = wa.y + 50 - 2*border_width - tb_height
            }
        end
    }

    -- The second large window should be placed at the top right corner.
    add_client {
        geometry = function(wa)
            return {
                width       = wa.width - 10,
                height      = wa.height - 50,
                expected_x  = wa.x + 10 - 2*border_width,
                expected_y  = wa.y
            }
        end
    }

    -- The third large window should be placed at the bottom right corner.
    add_client {
        geometry = function(wa)
            return {
                width       = wa.width - 10,
                height      = wa.height - 50,
                expected_x  = wa.x + 10 - 2*border_width,
                expected_y  = wa.y + 50 - 2*border_width - tb_height
            }
        end
    }

    -- The fourth large window should be placed at the top left corner (the
    -- whole workarea is occupied now).
    add_client {
        geometry = function(wa)
            return {
                width       = wa.width - 50,
                height      = wa.height - 50,
                expected_x  = wa.x,
                expected_y  = wa.y
            }
        end
    }

    -- Kill test clients to prepare for the next iteration.
    table.insert(tests, function(count)
        if count <= 1 then
            for _, data in ipairs(client_data) do
                if data.c then
                    data.c:kill()
                    data.c = nil
                end
            end
        end
        if #client.get() == 0 then
            return true
        end
    end)

end

runner.run_steps(tests)

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
