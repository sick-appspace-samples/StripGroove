
local helper = require 'helpers'

local DELAY = 2000 -- ms between each type for demonstration purpose

-- Parameters
local GREEN = {0, 200, 0}
local BLUE = {59, 156, 208}
local ORANGE = {242, 148, 0}
local MM_TO_PROCESS = 10 --10mm slices

-- Create the views
local v2D = View.create()
local v3D = View.create()
v3D:setID('Viewer3D')

local function viewHeightMap()
  -- Load the data
  local data = Object.load('resources/image_9.json')
  local heightMap = data[1]

  -- Extract the properties of the heightMap
  local minZ, maxZ = Image.getMinMax(heightMap)
  local _, pixelSizeY = Image.getPixelSize(heightMap)
  local _, heightMapH = Image.getSize(heightMap)
  local origin = Image.getOrigin(heightMap)

  local stepsize = math.ceil(MM_TO_PROCESS / pixelSizeY)


  local deco3D = View.ImageDecoration.create()
  deco3D:setRange(heightMap:getMin(), heightMap:getMax() / 1.01)

  local grDeco = helper.getGraphDeco(BLUE, maxZ)

  -- Visualize the heightMap
  v3D:clear()
  v3D:addHeightmap(heightMap, deco3D)
  v3D:present()

  -------------------------------------------------
  -- Aggregate a number of profiles together ------
  -------------------------------------------------

  local profilesToAggregate = {}
  for j = 0, heightMapH, stepsize do
      profilesToAggregate[#profilesToAggregate + 1] =  heightMap:extractRowProfile(j)
  end
  local frameProfile = Profile.aggregate(profilesToAggregate, 'MEAN')
  frameProfile = Profile.convertCoordinateType(frameProfile, 'IMPLICIT_1D')
  local _, delta = Profile.getImplicitCoordinates(frameProfile)
  Profile.setImplicitCoordinates(frameProfile, origin:getX(), delta)

  v2D:clear()
  grDeco:setTitle('Profile')
  v2D:addProfile(frameProfile, grDeco)
  v2D:present()
  Script.sleep(DELAY)

  -------------------------------------------------
  -- Fix missing data -----------------------------
  -------------------------------------------------
  frameProfile = frameProfile:blur(7)
  frameProfile = frameProfile:median(3)
  frameProfile:setValidFlagsEnabled(false)

  v2D:clear()
  grDeco:setTitle('Missing data fixed')
  v2D:addProfile(frameProfile, grDeco)
  v2D:present()
  Script.sleep(DELAY)

  -------------------------------------------------
  -- Calculate second derivative and detect edges -
  -------------------------------------------------

  local secondDerivative = frameProfile:gaussDerivative(45, 'SECOND')
  secondDerivative = secondDerivative:multiplyConstant(50)

  local extremas = secondDerivative:findLocalExtrema('MAX', 15, 0.5)
  local edges = {extremas[1], extremas[#extremas]}

  v2D:clear()
  grDeco:setTitle('Second Gauss derivative')
  local id = v2D:addProfile(frameProfile, grDeco)
  v2D:addProfile(secondDerivative, helper.getGraphDeco(GREEN, maxZ), nil, id) -- display second derivative
  v2D:present()
  Script.sleep(DELAY)

  -------------------------------------------------
  -- Detected Edges and postprocess -------
  -------------------------------------------------
  local extremaLines = {}
  for i, extrema in pairs(edges) do
    local xExtrema = frameProfile:getCoordinate(extrema)
    extremaLines[i] = Shape.createLineSegment(Point.create(xExtrema, minZ), Point.create(xExtrema, maxZ))
  end

  --Visualization
  v2D:clear()
  grDeco:setTitle('Edges')
  v2D:addProfile(frameProfile, grDeco)
  v2D:addShape(extremaLines, helper.getDeco(ORANGE))
  v2D:present()
  Script.sleep(DELAY)

  -- Define a profile without edges and find the edges of the groove
  local profile_noEdges = frameProfile:crop(extremas[1]+10, extremas[#extremas]-10)
  local min = profile_noEdges:getMin()

  -- Calculate the depth of the groove
  local distanceY = maxZ - min

  local groove = extremas
  table.remove(groove, 1)
  table.remove(groove, #extremas)

  local grooveLines = {}
  local xCoordinates = {}
  for i, grooveSegment in pairs(groove) do
    local xSegment = frameProfile:getCoordinate(grooveSegment)
    xCoordinates[i] = xSegment
    grooveLines[i] = Shape.createLineSegment(Point.create(xSegment, minZ), Point.create(xSegment, maxZ))
  end

  -- Calculate the distance between the edges of the groove
  local point1 = Profile.getCoordinate(frameProfile, groove[2])
  local point2 = Profile.getCoordinate(frameProfile, groove[1])
  local distanceX = point1 - point2

  --Visualization

  local arrow = Shape.createLineSegment(Point.create(xCoordinates[1], maxZ+5), Point.create(xCoordinates[2], maxZ+5))
  local arrow2 = Shape.createLineSegment(Point.create(xCoordinates[1], maxZ+7),Point.create(xCoordinates[1], maxZ+3))
  local arrow3 = Shape.createLineSegment(Point.create(xCoordinates[2], maxZ+7),Point.create(xCoordinates[2], maxZ+3))
  local arrow4 = Shape.createLineSegment(Point.create(xCoordinates[2]+4, maxZ), Point.create(xCoordinates[2]+4, min))
  local arrow5 = Shape.createLineSegment(Point.create(xCoordinates[2]+3, maxZ), Point.create(xCoordinates[2]+5, maxZ))
  local arrow6 = Shape.createLineSegment(Point.create(xCoordinates[2]+3, min), Point.create(xCoordinates[2]+5, min))
  local arrowDeco = View.ShapeDecoration.create()
  arrowDeco:setLineColor(0, 255, 0, 150):setLineWidth(1)

  local textDeco6 = helper.getTextDeco(xCoordinates[1], maxZ + 9, 3)
  local textDeco7 = helper.getTextDeco(xCoordinates[2] + 6, (maxZ + min) / 2, 3)
  v2D:clear()
  grDeco:setTitle('Groove Edges')
  v2D:addProfile(frameProfile, grDeco)
  v2D:addShape(grooveLines, helper.getDeco(ORANGE))
  v2D:present()
  Script.sleep(DELAY)

  v2D:addShape(arrow, arrowDeco)
  v2D:addShape(arrow2, arrowDeco)
  v2D:addShape(arrow3, arrowDeco)
  v2D:addShape(arrow4, arrowDeco)
  v2D:addShape(arrow5, arrowDeco)
  v2D:addShape(arrow6, arrowDeco)
  v2D:addText('d= ' .. math.floor(distanceX) .. 'mm', textDeco6)
  v2D:addText('d= ' .. math.floor(distanceY) .. 'mm', textDeco7)
  v2D:present()

  print('App finished.')
end

Script.register('Engine.OnStarted', viewHeightMap)
