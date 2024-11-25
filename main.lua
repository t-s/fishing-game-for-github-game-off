function love.load()
    -- Window settings
    love.window.setMode(800, 600)
    
    -- Game state
    gameState = {
        -- Water dimensions (now starting from 60% down)
        waterHeight = love.graphics.getHeight() * 0.4, -- reduced height since it starts lower
        waterY = love.graphics.getHeight() * 0.6, -- water starts 60% down the screen
        
        -- Platform dimensions
        platformWidth = 100,
        platformHeight = 50,
        
        -- Fisherman dimensions
        fishermanWidth = 30,
        fishermanHeight = 60,
        
        -- Fishing line properties
        isCasting = false,
        castStartX = 0,
        castStartY = 0,
        castEndX = 0,
        castEndY = 0,
        
        -- Line animation properties
        isAnimating = false,
        castTime = 0,
        castDuration = 1, -- seconds for cast animation
        initialVelocityX = 0,
        initialVelocityY = 0,
        gravity = 500, -- pixels per second squared
        linePoints = {}, -- stores points for line curve
        finalLinePoints = nil, -- stores final line position
        
        -- Colors
        waterColor = {0, 0.5, 1, 1}, -- Blue water
        skyColor = {0.5, 0.8, 1, 1}, -- Light blue sky
        platformColor = {0.6, 0.4, 0.2, 1}, -- Brown platform
        fishermanColor = {0, 0, 0, 1} -- Black silhouette
    }
    
    -- Calculate platform position (right side, at about halfway down)
    gameState.platformX = love.graphics.getWidth() - gameState.platformWidth - 20
    gameState.platformY = love.graphics.getHeight() * 0.5 -- Platform at 50% of screen height
    
    -- Calculate fisherman position (on platform)
    gameState.fishermanX = gameState.platformX + 20
    gameState.fishermanY = gameState.platformY - gameState.fishermanHeight
    
    -- Starting point of the line (fishing rod tip position)
    gameState.rodTipX = gameState.fishermanX + gameState.fishermanWidth/2
    gameState.rodTipY = gameState.fishermanY + 10
end

function calculateLinePoints(startX, startY, velocityX, velocityY, time)
    local points = {}
    local steps = 40 -- increased number of points for smoother curve
    local dt = time / steps
    local hasHitWater = false
    local waterHitX = 0
    
    for i = 0, steps do
        local t = i * dt
        local x = startX + velocityX * t
        local y = startY + velocityY * t + 0.5 * gameState.gravity * t * t
        
        -- If we've hit the water and haven't recorded the hit point
        if y >= gameState.waterY and not hasHitWater then
            -- Calculate exact water intersection point
            local tWater = (-velocityY + math.sqrt(velocityY^2 - 2 * gameState.gravity * (startY - gameState.waterY))) / gameState.gravity
            waterHitX = startX + velocityX * tWater
            hasHitWater = true
        end
        
        -- If we've hit the water, maintain the water level Y position
        if hasHitWater then
            -- Draw a straight line in the water from the hit point
            local waterLineLength = 20 -- length of line segment in water
            table.insert(points, waterHitX)
            table.insert(points, gameState.waterY)
            table.insert(points, waterHitX - waterLineLength) -- extend slightly left in water
            table.insert(points, gameState.waterY + 10) -- slightly down in water
            break
        else
            table.insert(points, x)
            table.insert(points, y)
        end
    end
    
    return points
end

function love.update(dt)
    if gameState.isCasting then
        local mouseX, mouseY = love.mouse.getPosition()
        -- Calculate casting vector
        local dx = mouseX - gameState.castStartX
        local dy = mouseY - gameState.castStartY
        local speed = math.sqrt(dx * dx + dy * dy)
        
        if speed > 0 then  -- Prevent division by zero
            -- Store the casting direction for use when released
            gameState.castDirection = {
                x = -dx / speed, -- Negative because we cast in opposite direction of drag
                y = -dy / speed
            }
            
            -- Preview trajectory
            local previewVelocityX = gameState.castDirection.x * speed * 2
            local previewVelocityY = gameState.castDirection.y * speed * 2
            gameState.linePoints = calculateLinePoints(
                gameState.rodTipX,
                gameState.rodTipY,
                previewVelocityX,
                previewVelocityY,
                1.0  -- Increased preview time
            )
        end
    elseif gameState.isAnimating then
        gameState.castTime = gameState.castTime + dt
        
        -- Calculate current line position
        gameState.linePoints = calculateLinePoints(
            gameState.rodTipX,
            gameState.rodTipY,
            gameState.initialVelocityX,
            gameState.initialVelocityY,
            gameState.castTime
        )
        
        -- Check if line has hit water (last Y position is at water level)
        local lastY = gameState.linePoints[#gameState.linePoints]
        if lastY >= gameState.waterY then
            gameState.isAnimating = false
            -- Store final line position
            gameState.finalLinePoints = gameState.linePoints
        end
    elseif gameState.finalLinePoints then
        -- Keep drawing the final line position
        gameState.linePoints = gameState.finalLinePoints
    end
end

function love.draw()
    -- Draw sky
    love.graphics.setColor(gameState.skyColor)
    love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), gameState.waterY)
    
    -- Draw water
    love.graphics.setColor(gameState.waterColor)
    love.graphics.rectangle('fill', 0, gameState.waterY, 
        love.graphics.getWidth(), gameState.waterHeight)
    
    -- Draw platform
    love.graphics.setColor(gameState.platformColor)
    love.graphics.rectangle('fill', gameState.platformX, gameState.platformY,
        gameState.platformWidth, gameState.platformHeight)
    
    -- Draw fisherman
    love.graphics.setColor(gameState.fishermanColor)
    love.graphics.rectangle('fill', gameState.fishermanX, gameState.fishermanY,
        gameState.fishermanWidth, gameState.fishermanHeight)
    
    -- Draw fishing line
    if #gameState.linePoints > 0 then
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.line(gameState.linePoints)
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    if button == 1 then  -- Left mouse button
        gameState.isCasting = true
        gameState.castStartX = x
        gameState.castStartY = y
        gameState.linePoints = {}
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    if button == 1 and gameState.isCasting then  -- Left mouse button
        gameState.isCasting = false
        
        -- Calculate initial velocity based on drag distance and direction
        local speed = math.sqrt(
            (x - gameState.castStartX)^2 + 
            (y - gameState.castStartY)^2
        )
        
        -- Set initial velocities for the cast
        gameState.initialVelocityX = gameState.castDirection.x * speed * 2
        gameState.initialVelocityY = gameState.castDirection.y * speed * 2
        
        -- Start animation
        gameState.isAnimating = true
        gameState.castTime = 0
        gameState.finalLinePoints = nil -- Clear any previous final line
    end
end
