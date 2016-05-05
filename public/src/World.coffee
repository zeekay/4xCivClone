sharedSpriteFrameCache = cc.SpriteFrameCache.getInstance()

class GeographyGenerator
	constructor: (options = @options)->
	run: (world)->

class GeologyGenerator extends GeographyGenerator
	constructor: (options = @options)->
		$.extend(@,
				landCount: 1
				oceanPlateCount: 1
				fractionSubduction: 0.3
				fractionLand: 0.3
				hasEqualLand: true,
			options)

	run: (world)->
		tileMapSize	= world.tileMapSize
		geographicTileMap = world.geographicTileMap

		candidateLists = []
		randoms = []
		for i in [0...@landPlateCount]
			x = Math.floor(tileMapSize.width * Math.random())
			y = Math.floor(tileMapSize.height * Math.random())

			candidateList = candidateLists[i] = [new cc.Point(x, y)]
			randomSlots = (Math.random()*10)
			randomSlots*=randomSlots*randomSlots*randomSlots*randomSlots
			for j in [0...randomSlots]
				randoms.push(i)

		landCount = 0
		totalTileCount = tileMapSize.width * tileMapSize.height
		requiredLandCount = totalTileCount * @fractionLand

		while landCount <= requiredLandCount
			id = randoms[Math.floor(randoms.length * Math.random())]
			candidateList = candidateLists[id]

			if candidateList.length > 0
				i = Math.floor(candidateList.length * Math.random())
				point = candidateList.splice(i, 1)[0]
				x = point.x
				y = point.y

				geographicTile = geographicTileMap[x][y]
				if !geographicTile.landPlateIds[id]
					geographicTile.landPlateIds[id] = true
					geographicTile.landPlateIds.length++
					geographicTile.elevation += 1 + Math.sqrt(Math.random() * 1.2)
					points = []
					if geographicTile.landPlateIds.length <= 1
						landCount++
						points = [[x-1, y],[x, y-1],[x+1, y],[x, y+1]]
					else
						geographicTile.elevation += Math.sqrt(Math.random() * 2)
						direction = Math.floor(4 * Math.random())
						if direction == 0
							points.push([x-1, y])
						else if direction == 1
							points.push([x, y-1])
						else if direction == 2
							points.push([x+1, y])
						else if direction == 3
							points.push([x, y+1])
					@addToCandidates(candidateList, geographicTileMap, tileMapSize, points)

		oceanPlateCount = @oceanPlateCount
		requiredSubductionCount = @fractionSubduction * totalTileCount

		candidateList = []
		while oceanPlateCount > 0
			x = Math.floor(tileMapSize.width * Math.random())
			y = Math.floor(tileMapSize.height * Math.random())
			geographicTile = geographicTileMap[x][y]
			if geographicTileMap[x][y].elevation == 0
				candidateList.push(new cc.Point(x, y))
				oceanPlateCount--

		subductionCount = 0
		while subductionCount <= requiredSubductionCount && candidateList.length > 0
			i = Math.floor(candidateList.length * Math.random())
			point = candidateList.splice(i, 1)[0]
			x = point.x
			y = point.y

			geographicTile = geographicTileMap[x][y]

			if geographicTile.subduction == false
				if geographicTile.landPlateIds.length == 0
					geographicTile.subduction = true
					subductionCount+=1
					@addToCandidates(candidateList, geographicTileMap, tileMapSize,
						[
							[x-1, y]
							[x, y-1]
							[x+1, y]
							[x, y+1]
							[x-2, y]
							[x-1, y-1]
							[x, y-2]
							[x+1, y-1]
							[x+2, y]
							[x+1, y+1]
							[x, y+2]
						],
					2)
				else
					geographicTile.elevation += Math.sqrt(Math.random() * 2)

	addToCandidates: (candidateList, geographicTileMap, tileMapSize, points, heightTolerance)->
		heightTolerance = 1000 if !heightTolerance?
		for point in points
			x = point[0]
			y = point[1]
			x = (x+tileMapSize.width)%tileMapSize.width
			if y >= 0 && y < tileMapSize.height && geographicTileMap[x] && geographicTileMap[x][y].elevation <= heightTolerance
				candidateList.push(new cc.Point(x, (y+tileMapSize.height)%tileMapSize.height))

class ClimateGenerator extends GeographyGenerator
	constructor: (options = @options) ->
		$.extend(@,
				minTemperature: -50
				maxTemperature: 100
				minRainfall: 0
				maxRainfall: 100
				rainfallReductionRate: 4,
			options)

		@temperatureRange = @maxTemperature - @minTemperature
		@rainfallRange = @maxRainfall - @minRainfall

		@rainfallReductionRateDiagonal = @rainfallReductionRate * Math.SQRT2
		@mountainRainfallReductionRate = @rainfallReductionRate * 10
		@mountainRainfallReductionRateDiagonal = @rainfallReductionRateDiagonal * 10
		@surroundingRainfallReductionRate = @rainfallReductionRate * 5

	run: (world)->
		tileMapSize	= world.tileMapSize
		geographicTileMap = world.geographicTileMap

		halfPi = Math.PI/2
		halfHeight1 = tileMapSize.height/2
		halfHeight2 = Math.floor(halfHeight1)
		if halfHeight1 == halfHeight2
			halfHeight1 -= 1
		else
			halfHeight1 = halfHeight2

		halfPiRatio = halfPi/halfHeight2

		for x in [0...tileMapSize.width]
			for y in [0...halfHeight1+1]
				temperature = @temperatureRange * Math.cos(halfPiRatio * y) + @minTemperature
				geographicTileMap[x][halfHeight1 - y].temperature = temperature
				geographicTileMap[x][halfHeight2 + y].temperature = temperature

		Async.series(
			()=>
				@hadleyCells(tileMapSize, geographicTileMap, halfHeight1, halfHeight2)
			()=>
				@rainfall(tileMapSize, geographicTileMap)
			()=>
				@temperatureModeration(tileMapSize, geographicTileMap))

	hadleyCells: (tileMapSize, geographicTileMap, halfHeight1, halfHeight2)->
		degree30 = Math.floor(Math.sin(Math.PI/6) * halfHeight2)
		degree60 = Math.floor(Math.sin(Math.PI/3) * halfHeight2)

		for x in [0...tileMapSize.width]
			for y in [0...degree30]
				geographicTileMap[x][halfHeight1 - y].windDirection = 9
				geographicTileMap[x][halfHeight2 + y].windDirection = 3
			for y in [degree30...degree60]
				geographicTileMap[x][halfHeight1 - y].windDirection = 1
				geographicTileMap[x][halfHeight2 + y].windDirection = 7
			for y in [degree60...halfHeight1+1]
				geographicTileMap[x][halfHeight1 - y].windDirection = 9
				geographicTileMap[x][halfHeight2 + y].windDirection = 3

	rainfall: (tileMapSize, geographicTileMap)->
		candidateList = []
		for x in [0...tileMapSize.width]
			for y in [0...tileMapSize.height]
				if geographicTileMap[x][y].elevation == 0
					candidateList.push(new cc.Point(x,y))

		for candidate in candidateList
			x = candidate.x
			y = candidate.y
			rainfall = @maxRainfall
			geographicTile = geographicTileMap[x][y]
			i = 1
			while rainfall > 0
				break if !geographicTile?
				rainfall -= @mountainRainfallReductionRateDiagonal if geographicTile.elevation > 4
				geographicTile.rainfall = Math.max(rainfall, geographicTile.rainfall)
				if geographicTile.windDirection == 9
					x = (x - 1 + tileMapSize.width) % tileMapSize.width
					y++
				else if geographicTile.windDirection == 3
					x = (x - 1 + tileMapSize.width) % tileMapSize.width
					y--
				else if geographicTile.windDirection == 1
					x = (x + 1) % tileMapSize.width
					y--
				else if geographicTile.windDirection == 7
					x = (x + 1) % tileMapSize.width
					y++
				else
					throw new Error("this shouldn't happen")
				rainfall -= @rainfallReductionRateDiagonal
				geographicTile = geographicTileMap[x][y]
				i++
			geographicTile.rainfall = Math.max(rainfall, geographicTile.rainfall) if geographicTile?

		for i in [0...2]
			for x in [0...tileMapSize.width]
				for y in [0...tileMapSize.height]
					@diffuseRainfall(tileMapSize, geographicTileMap, x, y)
			for x in [tileMapSize.width-1...-1]
				for y in [0...tileMapSize.height]
					@diffuseRainfall(tileMapSize, geographicTileMap, x, y)
			for x in [tileMapSize.width-1...-1]
				for y in [tileMapSize.height-1...-1]
					@diffuseRainfall(tileMapSize, geographicTileMap, x, y)
			for x in [0...tileMapSize.width]
				for y in [0...tileMapSize.height]
					@diffuseRainfall(tileMapSize, geographicTileMap, x, y)

			for x in [0...tileMapSize.width]
				for y in [0...tileMapSize.height]
					geographicTile = geographicTileMap[x][y]
					percentDeviation = Math.random() * .2 + .9
					geographicTile.rainfall *= percentDeviation
					percentDeviation = Math.random() * .2 + .9
					geographicTile.temperature *= percentDeviation

	temperatureModeration: (tileMapSize, geographicTileMap)->
		for x in [0...tileMapSize.width]
			for y in [0...tileMapSize.height]
				geographicTileMap[x][y].temperature += (geographicTileMap[x][y].rainfall * @temperatureRange)/1000 + @minTemperature/10

	diffuseRainfall: (tileMapSize, geographicTileMap, x, y)->
		geographicTile = geographicTileMap[x][y]
		referenceRainfall2 = 0
		referenceRainfall3 = 0
		referenceRainfall4 = 0
		if geographicTile.elevation <= 4
			if geographicTile.windDirection == 1
				referenceRainfall1 = geographicTileMap[(x - 1 + tileMapSize.width) % tileMapSize.width][y].rainfall - @rainfallReductionRate
				referenceRainfall2 = geographicTileMap[(x - 1 + tileMapSize.width) % tileMapSize.width][y+1].rainfall - @rainfallReductionRateDiagonal if y+1 < tileMapSize.height
				referenceRainfall3 = geographicTileMap[x][y-1].rainfall - @surroundingRainfallReductionRate if y-1 > 0
				referenceRainfall4 = geographicTileMap[x][y+1].rainfall - @surroundingRainfallReductionRate if y+1 < tileMapSize.height
			else if geographicTile.windDirection == 7
				referenceRainfall1 = geographicTileMap[(x - 1 + tileMapSize.width) % tileMapSize.width][y].rainfall - @rainfallReductionRate
				referenceRainfall2 = geographicTileMap[(x - 1 + tileMapSize.width) % tileMapSize.width][y-1].rainfall - @rainfallReductionRateDiagonal if y-1 > 0
				referenceRainfall3 = geographicTileMap[x][y-1].rainfall - @surroundingRainfallReductionRate if y-1 > 0
				referenceRainfall4 = geographicTileMap[x][y+1].rainfall - @surroundingRainfallReductionRate if y+1 < tileMapSize.height
			else if geographicTile.windDirection == 3
				referenceRainfall1 = geographicTileMap[(x + 1) % tileMapSize.width][y].rainfall - @rainfallReductionRate
				referenceRainfall2 = geographicTileMap[(x + 1) % tileMapSize.width][y+1].rainfall - @rainfallReductionRateDiagonal if y+1 < tileMapSize.height
				referenceRainfall3 = geographicTileMap[x][y-1].rainfall - @surroundingRainfallReductionRate if y-1 > 0
				referenceRainfall4 = geographicTileMap[x][y+1].rainfall - @surroundingRainfallReductionRate if y+1 < tileMapSize.height
			else if geographicTile.windDirection == 9
				referenceRainfall1 = geographicTileMap[(x + 1) % tileMapSize.width][y].rainfall - @rainfallReductionRate
				referenceRainfall2 = geographicTileMap[(x + 1) % tileMapSize.width][y-1].rainfall - @rainfallReductionRateDiagonal if y-1 > 0
				referenceRainfall3 = geographicTileMap[x][y-1].rainfall - @surroundingRainfallReductionRate if y-1 > 0
				referenceRainfall4 = geographicTileMap[x][y+1].rainfall - @surroundingRainfallReductionRate if y+1 < tileMapSize.height
			geographicTile.rainfall = Math.max(referenceRainfall1, referenceRainfall2, referenceRainfall3, referenceRainfall4, geographicTile.rainfall)
			throw new Error("NAN") if isNaN(geographicTile.rainfall)

class GeographicTile
	constructor: (options = @options)->
		$.extend(@,
			elevation: 0
			temperature: 0
			windDirection: 5
			rainfall: -1
			landPlateIds: length: 0
			subduction: false,
			tileGraphic: null

			# saved graphics list
			tiles: null
			transitions: null
			doodads: null
		options)

class TileGraphic
	constructor: (options = @options)->
		$.extend(@,
			spriteFrames5: []
			spriteFrames8: []
			spriteFrames7: []
			spriteFrames4: []
			spriteFrames1: []
			spriteFrames2: []
			spriteFrames3: []
			spriteFrames6: []
			spriteFrames9: []
			hills:[]
		@options)

loadTiles = (name) ->
	return {
		spriteFrames5: [
			sharedSpriteFrameCache.getSpriteFrame(name + "1")
			sharedSpriteFrameCache.getSpriteFrame(name + "2")
			sharedSpriteFrameCache.getSpriteFrame(name + "3")
			sharedSpriteFrameCache.getSpriteFrame(name + "4")]
		spriteFrames8: [sharedSpriteFrameCache.getSpriteFrame(name + "T1"), sharedSpriteFrameCache.getSpriteFrame(name + "T2")]
		spriteFrames7: [sharedSpriteFrameCache.getSpriteFrame(name + "TL1")]
		spriteFrames4: [sharedSpriteFrameCache.getSpriteFrame(name + "L1"), sharedSpriteFrameCache.getSpriteFrame(name + "L2")]
		spriteFrames1: [sharedSpriteFrameCache.getSpriteFrame(name + "BL1")]
		spriteFrames2: [sharedSpriteFrameCache.getSpriteFrame(name + "B1"), sharedSpriteFrameCache.getSpriteFrame(name + "B2")]
		spriteFrames3: [sharedSpriteFrameCache.getSpriteFrame(name + "BR1")]
		spriteFrames6: [sharedSpriteFrameCache.getSpriteFrame(name + "R1"), sharedSpriteFrameCache.getSpriteFrame(name + "R2")]
		spriteFrames9: [sharedSpriteFrameCache.getSpriteFrame(name + "TR1")]
		hills: [
			sharedSpriteFrameCache.getSpriteFrame(name + "Hill1"),
			sharedSpriteFrameCache.getSpriteFrame(name + "Hill2"),
			sharedSpriteFrameCache.getSpriteFrame(name + "Hill3"),
			sharedSpriteFrameCache.getSpriteFrame(name + "Hill4")]
	}

randomArrayElement = (tiles) ->
	return tiles[Math.floor(tiles.length * Math.random())]

randomOffset = (spriteFrame, tileSize) ->
	rect = spriteFrame.getRect()
	# For Testing Offsets
	#return new cc.Point(0, 0)
	return new cc.Point(Math.floor(Math.random()*(tileSize.width-rect.size.width/3)+rect.size.width/6), Math.floor(Math.random()*(tileSize.height-rect.size.height/3)+rect.size.height/6))

class @World
	constructor: (options = @options)->
		# Size in pixels
		@tileSize 	= options.tileSize

		# World in pixels
		@worldSize 	= options.worldSize

		# Derived
		@tileMapSize = new cc.Size(@worldSize.width/@tileSize.width, @worldSize.height/@tileSize.height)
		@geographicTileMap = []
		for i in [0...@tileMapSize.width]
			@geographicTileMap[i] = []
			for j in [0...@tileMapSize.height]
				@geographicTileMap[i][j] = new GeographicTile()

		# Options for Generators
		generatorOptions =
			tileMapSize: @tileMapSize

		$.extend(generatorOptions, options)

		@geologyGenerator = new GeologyGenerator(generatorOptions)
		@climateGenerator = new ClimateGenerator(generatorOptions)

		Async.series(
			()=>
				@geologyGenerator.run(@)
			()=>
				@climateGenerator.run(@)
			)

	createSprites: (layerSprite, spatialHash)->
		WaterTiles = new TileGraphic(
			spriteFrames5: [sharedSpriteFrameCache.getSpriteFrame("Water1")]
			spriteFrames8: [sharedSpriteFrameCache.getSpriteFrame("BeachT1")]
			spriteFrames7: [sharedSpriteFrameCache.getSpriteFrame("BeachTL1")]
			spriteFrames4: [sharedSpriteFrameCache.getSpriteFrame("BeachL1")]
			spriteFrames1: [sharedSpriteFrameCache.getSpriteFrame("BeachBL1")]
			spriteFrames2: [sharedSpriteFrameCache.getSpriteFrame("BeachB1")]
			spriteFrames3: [sharedSpriteFrameCache.getSpriteFrame("BeachBR1")]
			spriteFrames6: [sharedSpriteFrameCache.getSpriteFrame("BeachR1")]
			spriteFrames9: [sharedSpriteFrameCache.getSpriteFrame("BeachTR1")]
			)

		GrassTiles = new TileGraphic(loadTiles("Grassland"))
		LeechedTiles = new TileGraphic(loadTiles("Leeched"))
		PrairieTiles = new TileGraphic(loadTiles("Prairie"))
		DesertTiles = new TileGraphic(loadTiles("Desert"))
		PlainTiles = new TileGraphic(loadTiles("Plain"))
		TaigaTiles = new TileGraphic(loadTiles("Taiga"))
		PolarTiles = new TileGraphic(loadTiles("Polar"))

		tilePriority = [
			PrairieTiles
			GrassTiles
			TaigaTiles
			DesertTiles
			PlainTiles
			LeechedTiles
			PolarTiles
			WaterTiles
		].reverse()

		grassTuft = sharedSpriteFrameCache.getSpriteFrame("GrassTuft1")
		dryGrassTuft = sharedSpriteFrameCache.getSpriteFrame("GrassTuft2")
		leafyTree = sharedSpriteFrameCache.getSpriteFrame("Tree1")
		pineyTree = sharedSpriteFrameCache.getSpriteFrame("Tree2")
		junglyTree = sharedSpriteFrameCache.getSpriteFrame("Tree3")
		mountain = sharedSpriteFrameCache.getSpriteFrame("Mountain1")
		coldMountain = sharedSpriteFrameCache.getSpriteFrame("Mountain2")
		icyMountain = sharedSpriteFrameCache.getSpriteFrame("Mountain3")
		hut = sharedSpriteFrameCache.getSpriteFrame("Hut1")

		windSW = sharedSpriteFrameCache.getSpriteFrame("SW")
		windSE = sharedSpriteFrameCache.getSpriteFrame("SE")
		windNW = sharedSpriteFrameCache.getSpriteFrame("NW")
		windNE = sharedSpriteFrameCache.getSpriteFrame("NE")

		rain100 = sharedSpriteFrameCache.getSpriteFrame("100")
		rain75 = sharedSpriteFrameCache.getSpriteFrame("75")
		rain50 = sharedSpriteFrameCache.getSpriteFrame("50")
		rain25 = sharedSpriteFrameCache.getSpriteFrame("25")

		for x in [0...@tileMapSize.width]
			for y in [0...@tileMapSize.height]
				geographicTile = @geographicTileMap[x][y]
				if geographicTile.elevation <= 0
					geographicTile.tileGraphic = WaterTiles
				else if geographicTile.elevation <= 4
					rainfall = geographicTile.rainfall
					temperature = geographicTile.temperature

					if geographicTile.temperature > 90
						temperature = "Hot"
					else if geographicTile.temperature > 50
						temperature = "Temperate"
					else if geographicTile.temperature > 20
						temperature = "Cold"
					else
						temperature = "Freezing"

					if geographicTile.rainfall > 80
						rainfall = "Wet"
					else if geographicTile.rainfall > 30
						rainfall = "Moist"
					else
						rainfall = "Dry"

					if temperature == "Hot" && rainfall =="Wet"
						geographicTile.tileGraphic = LeechedTiles
					else if temperature == "Hot" && rainfall =="Moist"
						geographicTile.tileGraphic = PrairieTiles
					else if temperature == "Hot" && rainfall =="Dry"
						geographicTile.tileGraphic = DesertTiles
					else if temperature == "Temperate" && rainfall =="Wet"
						geographicTile.tileGraphic = GrassTiles
					else if temperature == "Temperate" && rainfall =="Moist"
						geographicTile.tileGraphic = GrassTiles
					else if temperature == "Temperate" && rainfall =="Dry"
						geographicTile.tileGraphic = PlainTiles
					else if temperature == "Cold"
						if rainfall == "Dry"
							geographicTile.tileGraphic = DesertTiles
						else
							geographicTile.tileGraphic = TaigaTiles
					else if temperature == "Freezing"
						geographicTile.tileGraphic = PolarTiles
				else
					geographicTile.tileGraphic = null

		for x in [0...@tileMapSize.width]
			for y in [0...@tileMapSize.height]
				geographicTile = @geographicTileMap[x][y]
				if geographicTile.tileGraphic == null
					l = (x-1 + @tileMapSize.width) % @tileMapSize.width
					r = (x+1) % @tileMapSize.width
					t = y-1
					b = y+1

					priority = tilePriority.indexOf(@geographicTileMap[l][y].tileGraphic)
					if @geographicTileMap[x][t]
						newPriority = tilePriority.indexOf(@geographicTileMap[x][t].tileGraphic)
						priority = newPriority if newPriority > priority
					if @geographicTileMap[x][b]
						newPriority = tilePriority.indexOf(@geographicTileMap[x][b].tileGraphic)
						priority = newPriority if newPriority > priority
					newPriority = tilePriority.indexOf(@geographicTileMap[r][y].tileGraphic)
					priority = newPriority if newPriority > priority

					if priority <= 0
						geographicTile.tileGraphic = DesertTiles
					else
						geographicTile.tileGraphic = tilePriority[priority]

		tileSpriteFrameFunction = (x, y, tileMap)=>
			geographicTile = @geographicTileMap[x][y]
			if geographicTile.tiles
				return geographicTile.tiles

			tileGraphic = geographicTile.tileGraphic
			geographicTile.tiles = ret = [randomArrayElement(tileGraphic.spriteFrames5)]

			if false
				if geographicTile.windDirection == 1
					ret.push(windSW)
				else if geographicTile.windDirection == 3
					ret.push(windSE)
				else if geographicTile.windDirection == 7
					ret.push(windNW)
				else if geographicTile.windDirection == 9
					ret.push(windNE)

			if false
				if geographicTile.rainfall > 75
					ret.push(rain100)
				else if geographicTile.rainfall > 50
					ret.push(rain75)
				else if geographicTile.rainfall > 25
					ret.push(rain50)
				else
					ret.push(rain25)

			l = (x-1 + @tileMapSize.width) % @tileMapSize.width
			r = (x+1) % @tileMapSize.width
			t = y-1
			b = y+1

			if geographicTile.elevation == 0
				# Above
				geographicTileT = @geographicTileMap[x][t]
				if geographicTileT
					if geographicTileT.elevation > 0
						ret = ret.concat(
							randomArrayElement(tileGraphic.spriteFrames7),
							randomArrayElement(tileGraphic.spriteFrames9),
							randomArrayElement(tileGraphic.spriteFrames8),
							)
					else
						if @geographicTileMap[l][t].elevation > 0
							ret.push(randomArrayElement(tileGraphic.spriteFrames7))
						if @geographicTileMap[r][t].elevation > 0
							ret.push(randomArrayElement(tileGraphic.spriteFrames9))
				#Below
				geographicTileB = @geographicTileMap[x][b]
				if geographicTileB
					if geographicTileB.elevation > 0
						ret = ret.concat(
							randomArrayElement(tileGraphic.spriteFrames1),
							randomArrayElement(tileGraphic.spriteFrames3),
							randomArrayElement(tileGraphic.spriteFrames2),
							)
					else
						if @geographicTileMap[l][b].elevation > 0
							ret.push(randomArrayElement(tileGraphic.spriteFrames1))
						if @geographicTileMap[r][b].elevation > 0
							ret.push(randomArrayElement(tileGraphic.spriteFrames3))
				#Left
				if @geographicTileMap[l][y].elevation > 0
					ret = ret.concat(
						randomArrayElement(tileGraphic.spriteFrames7),
						randomArrayElement(tileGraphic.spriteFrames1),
						randomArrayElement(tileGraphic.spriteFrames4))
				#Right
				if @geographicTileMap[r][y].elevation > 0
					ret = ret.concat(
						randomArrayElement(tileGraphic.spriteFrames9),
						randomArrayElement(tileGraphic.spriteFrames3),
						randomArrayElement(tileGraphic.spriteFrames6))
			return ret

		transitionSpriteFrameFunction = (x, y, tileMap)=>
			geographicTile = @geographicTileMap[x][y]
			if geographicTile.transitions
				return geographicTile.transitions
			tileGraphic = geographicTile.tileGraphic
			geographicTile.transitions = ret = []

			l = (x-1 + @tileMapSize.width) % @tileMapSize.width
			r = (x+1) % @tileMapSize.width
			t = y-1
			b = y+1

			priority = tilePriority.indexOf(tileGraphic)
			adjacentTile8 = @geographicTileMap[x][t]
			adjacentTile7 = @geographicTileMap[l][t]
			adjacentTile4 = @geographicTileMap[l][y]
			adjacentTile1 = @geographicTileMap[l][b]
			adjacentTile2 = @geographicTileMap[x][b]
			adjacentTile3 = @geographicTileMap[r][b]
			adjacentTile6 = @geographicTileMap[r][y]
			adjacentTile9 = @geographicTileMap[r][t]

			# Above
			has7 = false
			has9 = false
			if adjacentTile8
				adjacentTileGraphic7 = adjacentTile7.tileGraphic if adjacentTile7.elevation > 0
				adjacentTileGraphic9 = adjacentTile9.tileGraphic if adjacentTile9.elevation > 0
				adjacentTileGraphic8 = adjacentTile8.tileGraphic if adjacentTile8.elevation > 0
				if adjacentTileGraphic7 && tilePriority.indexOf(adjacentTileGraphic7) > priority
					has7 = true
					if adjacentTileGraphic8 && tilePriority.indexOf(adjacentTileGraphic8) > tilePriority.indexOf(adjacentTileGraphic7)
						ret.push(randomArrayElement(adjacentTileGraphic8.spriteFrames7))
					else
						ret.push(randomArrayElement(adjacentTileGraphic7.spriteFrames7))
				if adjacentTileGraphic9 && tilePriority.indexOf(adjacentTileGraphic9) > priority
					has9 = true
					if adjacentTileGraphic8 && tilePriority.indexOf(adjacentTileGraphic8) > tilePriority.indexOf(adjacentTileGraphic9)
						ret.push(randomArrayElement(adjacentTileGraphic8.spriteFrames9))
					else
						ret.push(randomArrayElement(adjacentTileGraphic9.spriteFrames9))
				if adjacentTileGraphic8 && tilePriority.indexOf(adjacentTileGraphic8) > priority
					if !has7
						ret.push(randomArrayElement(adjacentTileGraphic8.spriteFrames7))
					if !has9
						ret.push(randomArrayElement(adjacentTileGraphic8.spriteFrames9))
					ret.push(randomArrayElement(adjacentTileGraphic8.spriteFrames8))
			#Below
			has1 = false
			has3 = false
			if adjacentTile2
				adjacentTileGraphic1 = adjacentTile1.tileGraphic if adjacentTile1.elevation > 0
				adjacentTileGraphic3 = adjacentTile3.tileGraphic if adjacentTile3.elevation > 0
				adjacentTileGraphic2 = adjacentTile2.tileGraphic if adjacentTile2.elevation > 0
				if adjacentTileGraphic1 && tilePriority.indexOf(adjacentTileGraphic1) > priority
					has1 = true
					if adjacentTileGraphic2 && tilePriority.indexOf(adjacentTileGraphic2) > tilePriority.indexOf(adjacentTileGraphic1)
						ret.push(randomArrayElement(adjacentTileGraphic2.spriteFrames1))
					else
						ret.push(randomArrayElement(adjacentTileGraphic1.spriteFrames1))
				if adjacentTileGraphic3 && tilePriority.indexOf(adjacentTileGraphic3) > priority
					has3 = true
					if adjacentTileGraphic2 && tilePriority.indexOf(adjacentTileGraphic2) > tilePriority.indexOf(adjacentTileGraphic3)
						ret.push(randomArrayElement(adjacentTileGraphic2.spriteFrames3))
					else
						ret.push(randomArrayElement(adjacentTileGraphic3.spriteFrames3))
				if adjacentTileGraphic2 && tilePriority.indexOf(adjacentTileGraphic2) > priority
					if !has1
						ret.push(randomArrayElement(adjacentTileGraphic2.spriteFrames1))
					if !has3
						ret.push(randomArrayElement(adjacentTileGraphic2.spriteFrames3))
					ret.push(randomArrayElement(adjacentTileGraphic2.spriteFrames2))
			#Left
			if adjacentTile4
				adjacentTileGraphic4 = adjacentTile4.tileGraphic if adjacentTile4.elevation > 0
				if adjacentTileGraphic4 && blah = tilePriority.indexOf(adjacentTileGraphic4) > priority
					if !has7
						ret.push(randomArrayElement(adjacentTileGraphic4.spriteFrames7))
					if !has1
						ret.push(randomArrayElement(adjacentTileGraphic4.spriteFrames1))
					ret.push(randomArrayElement(adjacentTileGraphic4.spriteFrames4))
			#Right
			if adjacentTile6
				adjacentTileGraphic6 = adjacentTile6.tileGraphic if adjacentTile6.elevation > 0
				if adjacentTileGraphic6 && blah = tilePriority.indexOf(adjacentTileGraphic6) > priority
					if !has9
						ret.push(randomArrayElement(adjacentTileGraphic6.spriteFrames9))
					if !has3
						ret.push(randomArrayElement(adjacentTileGraphic6.spriteFrames3))
					ret.push(randomArrayElement(adjacentTileGraphic6.spriteFrames6))

			if geographicTile.elevation > 2 && geographicTile.elevation <= 4
				ret.push(randomArrayElement(tileGraphic.hills))
			return ret

		doodadsSpriteFrameFunction = (x, y, tileMap)=>
			geographicTile = @geographicTileMap[x][y]
			if geographicTile.doodads
				return geographicTile.doodads

			geographicTile.doodads = ret = []

			if geographicTile.temperature > 90
				temperature = "Hot"
				treeCount = 4
				grassCount = 3
			else if geographicTile.temperature > 50
				temperature = "Temperate"
				treeCount = 3
				grassCount = 1
			else if geographicTile.temperature > 20
				temperature = "Cold"
				treeCount = 4
				grassCount = 1
			else
				temperature = "Freezing"
				treeCount = 0
				grassCount = 0

			if geographicTile.rainfall > 80
				rainfall = "Wet"
				treeCount *= 1.5
				grassCount *= 2
			else if geographicTile.rainfall > 30
				rainfall = "Moist"
				grassCount *= 1.5
				treeCount = 0
			else
				rainfall = "Dry"
				treeCount = 0

			if temperature == "Temperate"
				tree = leafyTree
			else if temperature == "Hot"
				tree = junglyTree
			else
				tree = pineyTree

			if geographicTile.elevation > 0
				if geographicTile.elevation <= 2
					if rainfall == "Wet" || rainfall == "Moist"
						for i in [0...grassCount]
							offset = randomOffset(grassTuft, @tileSize)
							ret.push(
								spriteFrame: grassTuft
								x: offset.x
								y: offset.y)
					if rainfall == "Wet" || rainfall == "Moist"
						for i in [0...treeCount]
							offset = randomOffset(tree, @tileSize)
							ret.push(
								spriteFrame: tree
								x: offset.x
								y: offset.y)
					#if rainfall == "Moist" && temperature == "Temperate"
						#ret.push(
						#	spriteFrame: hut
						#	x: @tileSize.width/2
						#	y: Math.floor(@tileSize.height/2))
					if rainfall == "Dry" && temperature == "Temperate"
						for i in [0...grassCount]
							offset = randomOffset(dryGrassTuft, @tileSize)
							ret.push(
								spriteFrame: dryGrassTuft
								x: offset.x
								y: offset.y)
				else if geographicTile.elevation <= 4
					if rainfall == "Wet" || rainfall == "Moist"
						for i in [0...grassCount]
							offset = randomOffset(grassTuft, @tileSize)
							ret.push(
								spriteFrame: grassTuft
								x: offset.x
								y: Math.floor(offset.y - @tileSize.height/8))
						for i in [0...treeCount]
							offset = randomOffset(tree, @tileSize)
							ret.push(
								spriteFrame: tree
								x: offset.x
								y: Math.floor(offset.y - @tileSize.height/8))
				#	for i in [0...1]
				#		offset = randomOffset(hill, @tileSize)
				#		ret.push(
				#			spriteFrame: hill
				#			x: offset.x
				#			y: offset.y)
				else
					offset = randomOffset(mountain, @tileSize)
					if geographicTile.tileGraphic == PolarTiles
						mt = icyMountain
					else if geographicTile.tileGraphic == TaigaTiles || geographicTile.tileGraphic == GrassTiles
						mt = coldMountain
					else
						mt = mountain
					ret.push(
						spriteFrame: mt
						x: offset.x
						y: Math.floor(offset.y/2+@tileSize.height/3))
					offset = randomOffset(mountain, @tileSize)
					ret.push(
						spriteFrame: mt
						x: offset.x
						y: Math.floor(offset.y/2+@tileSize.height/4*3))
			throw new Error("WHAT") if ret[0] && !ret[0].spriteFrame
			return ret

		Background.create(
			tileMap: @geographicTileMap
			tileMapSize: @tileMapSize
			tileSize: @tileSize
			parentSprite: layerSprite
			spatialHash: spatialHash
			tileSpriteFrameFunction: tileSpriteFrameFunction
			transitionSpriteFrameFunction: transitionSpriteFrameFunction
			doodadsSpriteFrameFunction: doodadsSpriteFrameFunction)
