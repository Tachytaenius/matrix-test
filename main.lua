local vec3 = require("lib.mathsies").vec3
local quat = require("lib.mathsies").quat
local mat4 = require("lib.mathsies").mat4

local consts = require("consts")

local loadObj = require("loadObj")

local tau = math.pi * 2

local controllingDemonstration

local overviewNear, overviewFar
local overviewCamera

local demonstrationNear, demonstrationFar
local demonstrationCamera

local canvasWidth, canvsHeight
local overviewCanvas, povCanvas

local meshShader, lineShader
local cubeMesh, teapotMesh, lineMesh, terrainMesh

local time, animationStartTime, animatingBackwards, lerpI, objects

local gridCellCount

local function line(from, to)
	lineShader:send("origin", {vec3.components(from)})
	lineShader:send("lineVector", {vec3.components(to - from)})
	love.graphics.draw(lineMesh)
end

local function lerp(a, b, i)
	return a + (b - a) * i
end

function love.load()
	overviewNear, overviewFar = 0.01, 100000
	overviewCamera = {
		verticalFov = math.rad(70),
		position = vec3(-3, 0, -2),
		orientation = quat.fromAxisAngle(vec3(0, tau / 8, 0))
	}

	demonstrationNear, demonstrationFar = 0.1, 2
	demonstrationCamera = {
		verticalFov = math.rad(70),
		position = vec3(0, 0, 0),
		orientation = quat()
	}

	meshShader = love.graphics.newShader("shaders/mesh.glsl")
	lineShader = love.graphics.newShader("shaders/line.glsl")

	cubeMesh = loadObj("meshes/cube.obj")
	teapotMesh = loadObj("meshes/teapot.obj")
	lineMesh = love.graphics.newMesh(consts.vertexFormat, {
		{1,1,1, 0,0,0}, {0,0,0, 0,0,0}, {0,0,0, 0,0,0}
	}, "triangles")
	-- The terrain obj was huge so I've left it out
	-- terrainMesh = loadObj("meshes/terrain.obj")

	canvasWidth = love.graphics.getWidth() / 2
	canvsHeight = love.graphics.getHeight()
	overviewCanvas = love.graphics.newCanvas(canvasWidth, canvsHeight)
	povCanvas = love.graphics.newCanvas(canvasWidth, canvsHeight)

	time = 0
	lerpI = 0
	animationStartTime = nil
	animatingBackwards = false

	gridCellCount = 6

	objects = {
		-- {
		-- 	position = vec3(),
		-- 	orientation = quat(),
		-- 	scale = 1,
		-- 	mesh = terrainMesh
		-- },

		{
			position = vec3(-0.1, 0.0, 0.7),
			orientation = quat.fromAxisAngle(vec3(0.3, 0.9, 0.3)),
			scale = 0.2,
			mesh = cubeMesh
		},
		{
			position = vec3(0.4, -0.3, 0.75),
			orientation = quat.fromAxisAngle(vec3(0.25)),
			scale = 0.5,
			mesh = teapotMesh
		},
		{
			position = vec3(-0.2, -0.3, 1.75),
			orientation = quat.fromAxisAngle(vec3(0.25)),
			scale = 0.5,
			mesh = teapotMesh
		},
		{
			position = vec3(-0.8, 0.5, 1.25),
			orientation = quat.fromAxisAngle(vec3(4, -3, -1)),
			scale = 0.5,
			mesh = teapotMesh
		},

		{
			position = vec3(0.5, -0.3, -1.5),
			orientation = quat.fromAxisAngle(vec3(0.5, 1, 1)),
			scale = 0.5,
			mesh = teapotMesh
		}
	}
end

function love.update(dt)
	controllingDemonstration = love.keyboard.isDown("lctrl")
	local object = controllingDemonstration and demonstrationCamera or overviewCamera

	local speed = love.keyboard.isDown("lshift") and 20 or 2
	local translation = vec3()
	if love.keyboard.isDown("w") then translation.z = translation.z + speed end
	if love.keyboard.isDown("s") then translation.z = translation.z - speed end
	if love.keyboard.isDown("a") then translation.x = translation.x - speed end
	if love.keyboard.isDown("d") then translation.x = translation.x + speed end
	if love.keyboard.isDown("q") then translation.y = translation.y - speed end
	if love.keyboard.isDown("e") then translation.y = translation.y + speed end
	object.position = object.position + vec3.rotate(translation, object.orientation) * dt

	local angularSpeed = tau / 4
	local rotation = vec3()
	if love.keyboard.isDown("j") then rotation.y = rotation.y - angularSpeed end
	if love.keyboard.isDown("l") then rotation.y = rotation.y + angularSpeed end
	if love.keyboard.isDown("i") then rotation.x = rotation.x - angularSpeed end
	if love.keyboard.isDown("k") then rotation.x = rotation.x + angularSpeed end
	if love.keyboard.isDown("u") then rotation.z = rotation.z + angularSpeed end
	if love.keyboard.isDown("o") then rotation.z = rotation.z - angularSpeed end
	object.orientation = quat.normalise(object.orientation * quat.fromAxisAngle(rotation * dt))

	local fovChangeRate = 1
	local fovChange = 0
	if love.keyboard.isDown("r") then fovChange = fovChange + fovChangeRate end
	if love.keyboard.isDown("f") then fovChange = fovChange - fovChangeRate end
	object.verticalFov = object.verticalFov + fovChange * dt

	-- Huh?
	if love.keyboard.isDown("space") then
		animationStartTime = animationStartTime or time
		lerpI = 1 - (math.cos(((time - animationStartTime) * 0.5)) * 0.5 + 0.5)
		if animatingBackwards then
			lerpI = 1 - lerpI
		end
	else
		if animationStartTime then
			animatingBackwards = (((time - animationStartTime) * 0.5) - tau / 4) % tau < tau / 2 ~= animatingBackwards
		end
		animationStartTime = nil
		lerpI = math.floor(lerpI + 0.5) -- Round
	end

	time = time + dt
end

function love.draw()
	love.graphics.setDepthMode("lequal", true)

	local demonstrationProjectionMatrix = mat4.perspectiveLeftHanded(
		povCanvas:getWidth() / povCanvas:getHeight(),
		demonstrationCamera.verticalFov,
		demonstrationFar,
		demonstrationNear
	)
	local demonstrationCameraMatrix = mat4.camera(
		demonstrationCamera.position,
		demonstrationCamera.orientation
	)

	-- Draw overview

	love.graphics.setCanvas({overviewCanvas, depth = true})
	love.graphics.clear()

	local overviewProjectionMatrix = mat4.perspectiveLeftHanded(
		overviewCanvas:getWidth() / overviewCanvas:getHeight(),
		overviewCamera.verticalFov,
		overviewFar,
		overviewNear
	)
	local overviewCameraMatrix = mat4.camera(
		overviewCamera.position,
		overviewCamera.orientation
	)

	-- Drawing wireframes...
	love.graphics.setWireframe(true)
	lineShader:send("worldToScreen", {mat4.components(overviewProjectionMatrix * overviewCameraMatrix)})
	love.graphics.setShader(lineShader)

	-- Draw clip space cube
	love.graphics.setColor(1, 0, 0)
	line(vec3(-1, -1, -1), vec3( 1, -1, -1))
	line(vec3(-1, -1,  1), vec3( 1, -1,  1))
	line(vec3(-1,  1, -1), vec3( 1,  1, -1))
	line(vec3(-1,  1,  1), vec3( 1,  1,  1))
	line(vec3(-1, -1, -1), vec3(-1,  1, -1))
	line(vec3(-1, -1,  1), vec3(-1,  1,  1))
	line(vec3( 1, -1, -1), vec3( 1,  1, -1))
	line(vec3( 1, -1,  1), vec3( 1,  1,  1))
	line(vec3(-1, -1, -1), vec3(-1, -1,  1))
	line(vec3(-1,  1, -1), vec3(-1,  1,  1))
	line(vec3( 1, -1, -1), vec3( 1, -1,  1))
	line(vec3( 1,  1, -1), vec3( 1,  1,  1))
	-- Draw grid on bottom of clip space cube
	local leftForwards = vec3(-1, -1, 1)
	local leftBackwards = vec3(-1, -1, -1)
	local rightForwards = vec3(1, -1, 1)
	local rightBackwards = vec3(1, -1, -1)
	for i = 0, gridCellCount - 1 do
		local lerpI = i / gridCellCount
		local back = lerp(leftBackwards, rightBackwards, lerpI)
		local front = lerp(leftForwards, rightForwards, lerpI)
		line(back, front)
		local left = lerp(leftBackwards, leftForwards, lerpI)
		local right = lerp(rightBackwards, rightForwards, lerpI)
		line(left, right)
	end

	-- Draw view frustum
	love.graphics.setColor(0, 1, 0)
	local modelToWorld1 = mat4()
	local modelToWorld2 = mat4.inverse(demonstrationProjectionMatrix * demonstrationCameraMatrix) * modelToWorld1
	local function modelToWorldLerped(v)
		return lerp(modelToWorld1 * v, modelToWorld2 * v, 1 - lerpI)
	end
	line(modelToWorldLerped(vec3(-1, -1, -1)), modelToWorldLerped(vec3( 1, -1, -1)))
	line(modelToWorldLerped(vec3(-1, -1,  1)), modelToWorldLerped(vec3( 1, -1,  1)))
	line(modelToWorldLerped(vec3(-1,  1, -1)), modelToWorldLerped(vec3( 1,  1, -1)))
	line(modelToWorldLerped(vec3(-1,  1,  1)), modelToWorldLerped(vec3( 1,  1,  1)))
	line(modelToWorldLerped(vec3(-1, -1, -1)), modelToWorldLerped(vec3(-1,  1, -1)))
	line(modelToWorldLerped(vec3(-1, -1,  1)), modelToWorldLerped(vec3(-1,  1,  1)))
	line(modelToWorldLerped(vec3( 1, -1, -1)), modelToWorldLerped(vec3( 1,  1, -1)))
	line(modelToWorldLerped(vec3( 1, -1,  1)), modelToWorldLerped(vec3( 1,  1,  1)))
	line(modelToWorldLerped(vec3(-1, -1, -1)), modelToWorldLerped(vec3(-1, -1,  1)))
	line(modelToWorldLerped(vec3(-1,  1, -1)), modelToWorldLerped(vec3(-1,  1,  1)))
	line(modelToWorldLerped(vec3( 1, -1, -1)), modelToWorldLerped(vec3( 1, -1,  1)))
	line(modelToWorldLerped(vec3( 1,  1, -1)), modelToWorldLerped(vec3( 1,  1,  1)))
	local leftForwards = modelToWorldLerped(vec3(-1, -1, 1))
	local leftBackwards = modelToWorldLerped(vec3(-1, -1, -1))
	local rightForwards = modelToWorldLerped(vec3(1, -1, 1))
	local rightBackwards = modelToWorldLerped(vec3(1, -1, -1))
	for i = 0, gridCellCount - 1 do
		local lerpI = i / gridCellCount
		local back = lerp(leftBackwards, rightBackwards, lerpI)
		local front = lerp(leftForwards, rightForwards, lerpI)
		line(back, front)
		local left = lerp(leftBackwards, leftForwards, lerpI)
		local right = lerp(rightBackwards, rightForwards, lerpI)
		line(left, right)
	end

	love.graphics.setColor(1, 1, 1)
	love.graphics.setWireframe(false)
	love.graphics.setShader(meshShader)

	-- Draw objects
	meshShader:send("world1VsWorld2Lerp", lerpI)
	meshShader:send("worldLerpedToScreen", {mat4.components(
		overviewProjectionMatrix * overviewCameraMatrix
	)})
	meshShader:send("world1ToWorld2", {mat4.components(
		demonstrationProjectionMatrix * demonstrationCameraMatrix
	)})
	for _, object in ipairs(objects) do
		meshShader:send("modelToWorld1", {mat4.components(
			mat4.transform(object.position, object.orientation, object.scale))
		})
		love.graphics.draw(object.mesh)
	end

	-- Draw POV

	love.graphics.setCanvas({povCanvas, depth = true})
	love.graphics.clear()

	-- Draw objects
	meshShader:send("world1VsWorld2Lerp", lerpI)
	meshShader:send("worldLerpedToScreen", {mat4.components(
		mat4()
	)})
	meshShader:send("world1ToWorld2", {mat4.components(
		demonstrationProjectionMatrix * demonstrationCameraMatrix
	)})
	for _, object in ipairs(objects) do
		meshShader:send("modelToWorld1", {mat4.components(
			mat4.transform(object.position, object.orientation, object.scale))
		})
		love.graphics.draw(object.mesh)
	end

	-- Compose canvases together
	love.graphics.setCanvas()
	love.graphics.setShader()
	love.graphics.draw(overviewCanvas, 0, overviewCanvas:getHeight(), 0, 1, -1)
	love.graphics.draw(povCanvas, overviewCanvas:getWidth(), povCanvas:getHeight(), 0, 1, -1)
	love.graphics.line(love.graphics.getWidth() / 2, 0, love.graphics.getWidth() / 2, love.graphics.getHeight())
	love.graphics.print(
		"WASDQE: Translate\n" ..
		"IJKLUO: Rotate\n" ..
		"Space (hold): Animate\n" ..
		"Lshift: Move fast\n" ..
		"Lctrl: Control green matrix\n\n" ..
		"Lerp: " .. math.floor(lerpI * 100 + 0.5) .. "%\n"
	)
end
