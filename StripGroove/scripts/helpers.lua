local function getTextDeco(posX, posY, s)
  local textDeco = View.TextDecoration.create()
  textDeco:setSize(s)
  textDeco:setColor(0, 0, 0)
  textDeco:setPosition(posX, posY)
  return textDeco
end

local function getDeco(rgba, lineWidth, pointSize, fillAlpha)

  if not rgba[4] then rgba[4] = 255 end

  local deco = View.ShapeDecoration.create()
  deco:setLineColor(rgba[1], rgba[2], rgba[3], rgba[4])
  deco:setFillColor(rgba[1], rgba[2], rgba[3], fillAlpha)
  if lineWidth then deco:setLineWidth(lineWidth) end
  if pointSize then deco:setPointSize(pointSize) end
  return deco
end

local function getX(coordinate)
  if type(coordinate) == 'userdata' then
    return coordinate:getX()
  else
    return coordinate
  end
end

local function profileToPolylines(profile, closed, spaceBetweenPoints, offset)
  if not profile then return {} end
  offset = offset or getX(Profile.getCoordinate(profile, 0))
  closed = closed or false
  if not spaceBetweenPoints then
    if Profile.getSize(profile) > 1 then
      spaceBetweenPoints = getX(Profile.getCoordinate(profile, 1)) - getX(Profile.getCoordinate(profile, 0))
    else
      spaceBetweenPoints = 1
    end
  end

  local values, _, validFlags = profile:toVector()

  local polylines = {}
  local pointBuff = {}

  if Profile.getValidFlagsEnabled(profile) then
    for i, value in pairs(values) do
      if validFlags[i] == 0 then
        -- commulate Buffer to polyline
        if #pointBuff > 0 then
          polylines[#polylines + 1] = Shape.createPolyline(pointBuff, closed)
          pointBuff = {} --clear buffer
        end
      else
        local x = offset + i * spaceBetweenPoints
        pointBuff[#pointBuff + 1] = Point.create(x, value)
      end
    end
  else --don't care about valid flags
    for i, value in pairs(values) do
      local x = offset + i * spaceBetweenPoints
      pointBuff[#pointBuff + 1] = Point.create(x, value)
    end
  end

  if #pointBuff > 0 then
    polylines[#polylines + 1] = Shape.createPolyline(pointBuff, closed)
  end

  return polylines
end

local helper = {}
helper.getDeco = getDeco
helper.profileToPolylines = profileToPolylines
helper.getTextDeco = getTextDeco
return helper