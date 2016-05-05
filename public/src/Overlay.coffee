@Overlay = class Overlay extends cc.Sprite
	ctor: (options = @options)->
		# Size in pixels
		@tileSize 	= options.tileSize

		# Screen Size in pixels
		screenSize	= options.screenSize

		overlayCanvas = $('<canvas />')[0]
		overlayCanvas.width = Math.ceil(screenSize.width / @tileSize.width) * @tileSize.width + @tileSize.width + @tileSize.width
		overlayCanvas.height = Math.ceil(screenSize.height / @tileSize.height) * @tileSize.height + @tileSize.height + @tileSize.height
		ctx = overlayCanvas.getContext('2d')

		ctx.webkitImageSmoothingEnabled = false
		ctx.mozImageSmoothingEnabled = false
		ctx.imageSmoothingEnabled = false
		ctx.oImageSmoothingEnabled = false

		ctx.beginPath()
		ctx.strokeStyle = 'rgba(0,0,0,0.4)'
		ctx.lineWidth = 2
		for x in [0...overlayCanvas.width] by @tileSize.width
			ctx.moveTo(x, 0)
			ctx.lineTo(x, overlayCanvas.height)

		for y in [0...overlayCanvas.height] by @tileSize.height
			ctx.moveTo(0, y)
			ctx.lineTo(overlayCanvas.width, y)
		ctx.stroke()

		@initWithTexture(overlayCanvas)

		# Screen Size in pixels
		@parentSprite = options.parentSprite
		@parentSprite.addChild(@)

	update: (dt)->
		position = @parentSprite.getPosition()
		@setPosition(new cc.Point(-position.x + (position.x%@tileSize.width), -position.y + (position.y%@tileSize.height)))
