--[[----------------------------------------------------------------------------

  Application Name:
  StripGroove

  Summary:
  Detecting edges in profile measuring grooves.

  Description:
  In this Sample edges of profile, extracted from a heightmap, are detected.
  Furthermore a groove is detected and measured for its width and depth.

  How to run:
  Starting this sample is possible either by running the app (F5) or
  debugging (F7+F10). Setting breakpoint on the first row inside the 'main'
  function allows debugging step-by-step after 'Engine.OnStarted' event.
  Results can be seen in the image as well as the point cloud viewer on the DevicePage.
  Restarting the Sample may be necessary to show the profiles after loading the webpage.
  To run this Sample a device with SICK Algorithm API and AppEngine >= V2.5.0 is
  required. For example SIM4000 with latest firmware. Alternatively the Emulator
  on AppStudio 2.3 or higher can be used.

  More Information:
  Tutorial "Algorithms - Profile - FirstSteps".

------------------------------------------------------------------------------]]
local helper = require 'helpers'

local DELAY = 2000 -- ms between each type for demonstration purpose

-- Parameters
local GREEN = {0, 200, 0}
local BLUE = {59, 156, 208}
local ORANGE = {242, 148, 0}
local WHITE = {255, 255, 255}
local MM_TO_PROCESS = 10 --10mm slices

-- Create the views
local v2D = View.create()
v2D:setID('Viewer2D')
local v3D = View.create()
v3D:setID('Viewer3D')

local function viewHeightMap()
  -- Load the data
  local data = Object.load('resources/image_9.json')
  local heightMap = data[1]

  -- Extract the properties of the heightMap
  local minZ, maxZ = Image.getMinMax(heightMap)
  local zRange = maxZ - minZ
  local pixelSizeX, pixelSizeY = Image.getPixelSize(heightMap)
  local heightMapW, heightMapH = Image.getSize(heightMap)
  local stepsize = math.ceil(MM_TO_PROCESS / pixelSizeY)


  local deco3D = View.ImageDecoration.create()
  deco3D:setRange(heightMap:getMin(), heightMap:getMax() / 1.01)

  -- Visualize the heightMap
  v3D:clear()
  v3D:addHeightmap(heightMap, deco3D)
  v3D:present()

  --Create a 2D white background
  local background = Shape.createRectangle(Point.create(0, (maxZ + minZ) / 2),
                                           heightMapW * pixelSizeX + 150, zRange + 150)
  local textDeco1 = helper.getTextDeco(-15, 100, 10)

  -------------------------------------------------
  -- Aggregate a number of profiles together ------
  -------------------------------------------------

  local profilesToAggregate = {}
  for j = 0, heightMapH, stepsize do
      profilesToAggregate[#profilesToAggregate + 1] =  heightMap:extractRowProfile(j)
  end
  local frameProfile = Profile.aggregate(profilesToAggregate, 'MEAN')
  v2D:clear()
  v2D:addShape(background, helper.getDeco(WHITE))
  v2D:addShape(helper.profileToPolylines(frameProfile), helper.getDeco(BLUE))
  v2D:addText('Profile', textDeco1)
  v2D:present()
  Script.sleep(DELAY)

  -------------------------------------------------
  -- Fix missing data -----------------------------
  -------------------------------------------------
  frameProfile = frameProfile:blur(7)
  frameProfile = frameProfile:median(3)
  frameProfile:setValidFlagsEnabled(false)

  local textDeco2 = helper.getTextDeco(-50, 100, 10)
  v2D:clear()
  v2D:addShape(background, helper.getDeco(WHITE))
  v2D:addShape(helper.profileToPolylines(frameProfile), helper.getDeco(BLUE))
  v2D:addText('Missing data fixed', textDeco2)
  v2D:present()
  Script.sleep(DELAY)

  -------------------------------------------------
  -- Calculate second derivative and detect edges -
  -------------------------------------------------

  local secondDerivative = frameProfile:gaussDerivative(45, 'SECOND')
  secondDerivative = secondDerivative:multiplyConstant(50)

  local extremas = secondDerivative:findLocalExtrema('MAX', 15, 0.5)
  local edges = {extremas[1], extremas[#extremas]}

  local textDeco3 = helper.getTextDeco(-60, 100, 10)
  v2D:clear()
  v2D:addShape(background, helper.getDeco(WHITE))
  v2D:addShape(helper.profileToPolylines(frameProfile), helper.getDeco(BLUE))
  v2D:add(helper.profileToPolylines(secondDerivative), helper.getDeco(GREEN)) -- display second derivative
  v2D:addText('Second Gauss derivative', textDeco3)
  v2D:present()
  Script.sleep(DELAY)

  -------------------------------------------------
  -- Detected Edges and postprocess -------
  -------------------------------------------------
  local extremaLines = {}
  for i, extrema in pairs(edges) do
    local xExtrema = frameProfile:getCoordinate(extrema):getX()
    extremaLines[i] = Shape.createLineSegment(Point.create(xExtrema, minZ), Point.create(xExtrema, maxZ))
  end

  --Visualization
  local textDeco4 = helper.getTextDeco(-30, 100, 10)
  v2D:clear()
  v2D:addShape(background, helper.getDeco(WHITE))
  v2D:addShape(helper.profileToPolylines(frameProfile), helper.getDeco(BLUE))
  v2D:addShape(extremaLines, helper.getDeco(ORANGE))
  v2D:addText('Edges', textDeco4)
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
    local xSegment = frameProfile:getCoordinate(grooveSegment):getX()
    xCoordinates[i] = xSegment
    grooveLines[i] = Shape.createLineSegment(Point.create(xSegment, minZ), Point.create(xSegment, maxZ))
  end

  -- Calculate the distance between the edges of the groove
  local point1 = Profile.getCoordinate(frameProfile, groove[2])
  local point2 = Profile.getCoordinate(frameProfile, groove[1])
  local distanceX = point1:getX() - point2:getX()

  --Visualization

  local arrow = Shape.createLineSegment(Point.create(xCoordinates[1], maxZ+5), Point.create(xCoordinates[2], maxZ+5))
  local arrow2 = Shape.createLineSegment(Point.create(xCoordinates[1], maxZ+7),Point.create(xCoordinates[1], maxZ+3))
  local arrow3 = Shape.createLineSegment(Point.create(xCoordinates[2], maxZ+7),Point.create(xCoordinates[2], maxZ+3))
  local arrow4 = Shape.createLineSegment(Point.create(xCoordinates[2]+4, maxZ), Point.create(xCoordinates[2]+4, min))
  local arrow5 = Shape.createLineSegment(Point.create(xCoordinates[2]+3, maxZ), Point.create(xCoordinates[2]+5, maxZ))
  local arrow6 = Shape.createLineSegment(Point.create(xCoordinates[2]+3, min), Point.create(xCoordinates[2]+5, min))
  local arrowDeco = View.ShapeDecoration.create()
  arrowDeco:setLineColor(0, 255, 0, 150)
  arrowDeco:setLineWidth(1)

  local textDeco5 = helper.getTextDeco(-30, 100, 10)
  local textDeco6 = helper.getTextDeco(xCoordinates[1], maxZ + 9, 3)
  local textDeco7 = helper.getTextDeco(xCoordinates[2] + 6, (maxZ + min) / 2, 3)
  v2D:clear()
  v2D:addShape(background, helper.getDeco(WHITE))
  v2D:addShape(helper.profileToPolylines(frameProfile), helper.getDeco(BLUE))
  v2D:addShape(grooveLines, helper.getDeco(ORANGE))
  v2D:addText('Groove Edges', textDeco5)
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
