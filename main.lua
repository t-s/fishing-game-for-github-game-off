function love.load()
    -- Window settings
    love.window.setMode(800, 600)
    
    -- Set default font to a larger size
    gameState = {
        font = love.graphics.newFont(20), -- Create a font for the numbers
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
        
        -- Sinking line properties
        isSinking = false,
        sinkStartTime = 0,
        sinkingSpeed = 50, -- pixels per second
        waterHitX = 0,
        sinkDepth = 0,
        lineFrozen = false, -- New property to track if line should stop sinking
        
        -- Colors
        waterColor = {0, 0.5, 1, 1}, -- Blue water
        skyColor = {0.5, 0.8, 1, 1}, -- Light blue sky
        platformColor = {0.6, 0.4, 0.2, 1}, -- Brown platform
        fishermanColor = {0, 0, 0, 1}, -- Black silhouette
        
        -- Floating squares properties
        squares = {},
        squareSize = 40,
        numberTimer = 0,
        numberUpdateInterval = 1, -- Update numbers every second
        squareColor = {0.8, 0.8, 0.8, 1}, -- Light gray squares
        
        -- Line-square collision
        lineHitSquare = false,
        
        -- Die animation properties
        showDie = false,
        dieNumber = 1,
        dieSize = 150, -- Large die size
        dieUpdateTimer = 0,
        dieUpdateInterval = 0.1, -- Update die number every 0.1 seconds
        dieColor = {1, 1, 1, 1}, -- White die
        dieOutlineColor = {0, 0, 0, 1}, -- Black outline
        dieTextColor = {0, 0, 0, 1}, -- Black text
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
    
    -- Create initial squares
    local numSquares = 8 -- Number of squares to create
    local waterWidth = love.graphics.getWidth()
    local spacing = waterWidth / numSquares
    
    for i = 1, numSquares do
        table.insert(gameState.squares, {
            x = spacing * (i - 0.5), -- Evenly space squares across water
            y = gameState.waterY + math.random(50, gameState.waterHeight - 50), -- Random height in water
            number = math.random(1, 20), -- Random initial number between 1 and 20
            bobOffset = math.random() * math.pi * 2, -- Random bobbing offset
            bobSpeed = 0.8 + math.random() * 0.4, -- Extremely fast bobbing speed
            baseY = 0, -- Store initial Y position
            frozen = false, -- Track if number should stop changing
            finalY = 0, -- Store final Y position
        })
    end
    
    -- Set initial base Y positions
    for _, square in ipairs(gameState.squares) do
        square.baseY = gameState.waterY + math.random(50, gameState.waterHeight - 50)
    end
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
            
            -- Store water hit position for sinking animation
            if not gameState.isSinking then
                gameState.waterHitX = waterHitX
                gameState.isSinking = true
                gameState.sinkStartTime = love.timer.getTime()
                gameState.sinkDepth = 0
            end
        end
        
        -- If we've hit the water, draw the sinking line
        if hasHitWater then
            -- Calculate current sink depth only if line is not frozen
            if gameState.isSinking and not gameState.lineFrozen then
                local sinkTime = love.timer.getTime() - gameState.sinkStartTime
                gameState.sinkDepth = math.min(
                    gameState.sinkingSpeed * sinkTime,
                    gameState.waterHeight - 20 -- Stop 20 pixels from bottom
                )
            end
            
            -- Draw the line from water surface to current depth
            table.insert(points, waterHitX)
            table.insert(points, gameState.waterY)
            table.insert(points, waterHitX)
            table.insert(points, gameState.waterY + gameState.sinkDepth)
            break
        else
            table.insert(points, x)
            table.insert(points, y)
        end
    end
    
    return points
end

function checkLineSquareCollision(lineX, lineY, square)
    -- Check if line point is within square bounds
    local halfSize = gameState.squareSize / 2
    return lineX >= square.x - halfSize and
           lineX <= square.x + halfSize and
           lineY >= square.y - halfSize and
           lineY <= square.y + halfSize
end

function love.update(dt)
    -- Update number timer
    gameState.numberTimer = gameState.numberTimer + dt
    
    -- Update numbers every second
    if gameState.numberTimer >= gameState.numberUpdateInterval then
        gameState.numberTimer = gameState.numberTimer - gameState.numberUpdateInterval
        -- Update all square numbers except those hit by the line
        for _, square in ipairs(gameState.squares) do
            if not square.frozen then
                square.number = math.random(1, 20)
            end
        end
    end
    
    -- Update square bobbing motion
    for _, square in ipairs(gameState.squares) do
        if not square.frozen then
            -- Only update position if square is not frozen
            -- Use stored baseY for more stable bobbing
            square.y = square.baseY + math.sin(love.timer.getTime() * square.bobSpeed + square.bobOffset) * 25 -- Extreme amplitude
            
            -- Add secondary wave motion for more chaos
            square.y = square.y + math.cos(love.timer.getTime() * (square.bobSpeed * 0.7) + square.bobOffset * 1.5) * 10
        else
            -- If square is frozen, set its position to the final position
            square.y = square.finalY
        end
        
        -- Check for line collision if line is in water and not already frozen
        if gameState.isSinking and not square.frozen and not gameState.lineFrozen then
            if checkLineSquareCollision(gameState.waterHitX, gameState.waterY + gameState.sinkDepth, square) then
                square.frozen = true -- Freeze the square's number and position
                gameState.lineFrozen = true -- Stop the line from sinking further
                -- Store the final position of the square
                square.finalY = square.y
                -- Start die animation
                gameState.showDie = true
                gameState.dieNumber = math.random(1, 20)
                print("Hit square with number: " .. square.number) -- Debug output
            end
        end
    end
    
    -- Update rolling die animation
    if gameState.showDie then
        gameState.dieUpdateTimer = gameState.dieUpdateTimer + dt
        if gameState.dieUpdateTimer >= gameState.dieUpdateInterval then
            gameState.dieUpdateTimer = gameState.dieUpdateTimer - gameState.dieUpdateInterval
            gameState.dieNumber = math.random(1, 20)
        end
    end
    
    -- Original casting logic
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
    elseif gameState.isAnimating or gameState.isSinking then
        -- Continue updating line points for sinking animation
        gameState.linePoints = calculateLinePoints(
            gameState.rodTipX,
            gameState.rodTipY,
            gameState.initialVelocityX,
            gameState.initialVelocityY,
            gameState.castTime
        )
        
        if gameState.isAnimating then
            gameState.castTime = gameState.castTime + dt
        end
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
    
    -- Draw squares
    love.graphics.setFont(gameState.font)
    for _, square in ipairs(gameState.squares) do
        -- Draw square
        love.graphics.setColor(gameState.squareColor)
        love.graphics.rectangle('fill', 
            square.x - gameState.squareSize/2, 
            square.y - gameState.squareSize/2, 
            gameState.squareSize, 
            gameState.squareSize)
            
        -- Draw number
        love.graphics.setColor(0, 0, 0, 1) -- Black text
        local number = tostring(square.number)
        local textW = gameState.font:getWidth(number)
        local textH = gameState.font:getHeight()
        love.graphics.print(number, 
            square.x - textW/2, 
            square.y - textH/2)
    end
    
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
    
    -- Draw the die if it's showing
    if gameState.showDie then
        -- Draw semi-transparent background overlay
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        
        -- Calculate die position (center of screen)
        local screenCenterX = love.graphics.getWidth() / 2
        local screenCenterY = love.graphics.getHeight() / 2
        
        -- Draw die background (white square with black outline)
        love.graphics.setColor(gameState.dieColor)
        love.graphics.rectangle("fill", 
            screenCenterX - gameState.dieSize/2,
            screenCenterY - gameState.dieSize/2,
            gameState.dieSize,
            gameState.dieSize,
            10, -- rounded corners
            10
        )
        
        -- Draw die outline
        love.graphics.setColor(gameState.dieOutlineColor)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line",
            screenCenterX - gameState.dieSize/2,
            screenCenterY - gameState.dieSize/2,
            gameState.dieSize,
            gameState.dieSize,
            10, -- rounded corners
            10
        )
        
        -- Draw die number
        love.graphics.setColor(gameState.dieTextColor)
        local font = love.graphics.newFont(gameState.dieSize/2) -- Large font size
        love.graphics.setFont(font)
        local text = tostring(gameState.dieNumber)
        local textW = font:getWidth(text)
        local textH = font:getHeight()
        love.graphics.print(
            text,
            screenCenterX - textW/2,
            screenCenterY - textH/2
        )
        
        -- Reset font
        love.graphics.setFont(love.graphics.newFont(14))
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

function love.mousepressed(x, y, button, istouch, presses)
    if button == 1 then  -- Left mouse button
        if gameState.showDie then
            -- Stop die animation when clicked
            gameState.showDie = false
            gameState.dieUpdateTimer = 0
        elseif not gameState.isCasting then
            -- Start casting only if we're not showing the die
            gameState.isCasting = true
            gameState.castStartX = x
            gameState.castStartY = y
            gameState.linePoints = {}
        end
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    if button == 1 and gameState.isCasting then  -- Left mouse button
        gameState.isCasting = false
        
        -- Reset sinking state
        gameState.isSinking = false
        gameState.sinkDepth = 0
        gameState.lineFrozen = false -- Reset line frozen state
        gameState.showDie = false -- Make sure die is hidden for new cast
        
        -- Reset all squares' frozen state for new cast
        for _, square in ipairs(gameState.squares) do
            square.frozen = false
        end
        
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
    end
end
