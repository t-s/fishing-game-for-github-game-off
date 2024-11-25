function love.conf(t)
    t.title = "Fishing Game"        -- The title of the window
    t.version = "11.4"              -- The LÖVE version this game was made for
    t.window.width = 800           -- Game's screen width
    t.window.height = 600          -- Game's screen height
    t.window.resizable = false     -- Let's keep it fixed size for now
    
    -- For debugging
    t.console = true
end
