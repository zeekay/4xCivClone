@Tile = class Tile extends cc.Sprite
  ctor: (@options) ->
    @spatialHash = @options.spatialHash
    if @spatialHash?
      @spatialHash.addNode(@)
    @initWithTexture(@options.buffer)
  update: (dt) ->
    if @spatialHash?
      bin = @spatialHash.getBinFromNode(@)
      @setVisible(bin? && bin.active)
