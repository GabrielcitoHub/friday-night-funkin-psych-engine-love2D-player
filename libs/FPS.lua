local fps = {}

function fps:getFps()
  return love.timer.getFPS()
end

return fps