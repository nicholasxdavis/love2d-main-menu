local app = require("src.menu.app")

function love.load()
    app.load()
end

function love.resize(w, h)
    app.resize()
end

function love.update(dt)
    app.update(dt)
end

function love.draw()
    app.draw()
end

function love.keypressed(key, scancode, isrepeat)
    app.keypressed(key)
end

function love.mousemoved(x, y, dx, dy, istouch)
    app.mousemoved(x, y, dx, dy)
end

function love.mousepressed(x, y, button, istouch, presses)
    app.mousepressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
    app.mousereleased(x, y, button, istouch, presses)
end

function love.quit()
    app.quit()
end
