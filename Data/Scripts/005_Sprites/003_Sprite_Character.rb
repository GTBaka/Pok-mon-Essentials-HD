#===============================================================================
#
#===============================================================================
class BushBitmap
  def initialize(bitmap, isTile, depth)
    @bitmaps  = []
    @bitmap   = bitmap
    @isTile   = isTile
    @isBitmap = @bitmap.is_a?(Bitmap)
    @depth    = depth
  end

  def dispose
    @bitmaps.each { |b| b&.dispose }
  end

  def bitmap
    thisBitmap = (@isBitmap) ? @bitmap : @bitmap.bitmap
    current = (@isBitmap) ? 0 : @bitmap.currentIndex
    if !@bitmaps[current]
      if @isTile
        @bitmaps[current] = pbBushDepthTile(thisBitmap, @depth)
      else
        @bitmaps[current] = pbBushDepthBitmap(thisBitmap, @depth)
      end
    end
    return @bitmaps[current]
  end

  def pbBushDepthBitmap(bitmap, depth)
    ret = Bitmap.new(bitmap.width, bitmap.height)
    charheight = ret.height / 4
    cy = charheight - depth - 2
    4.times do |i|
      y = i * charheight
      if cy >= 0
        ret.blt(0, y, bitmap, Rect.new(0, y, ret.width, cy))
        ret.blt(0, y + cy, bitmap, Rect.new(0, y + cy, ret.width, 2), 170)
      end
      ret.blt(0, y + cy + 2, bitmap, Rect.new(0, y + cy + 2, ret.width, 2), 85) if cy + 2 >= 0
    end
    return ret
  end

  def pbBushDepthTile(bitmap, depth)
    ret = Bitmap.new(bitmap.width, bitmap.height)
    charheight = ret.height
    cy = charheight - depth - 2
    y = charheight
    if cy >= 0
      ret.blt(0, y, bitmap, Rect.new(0, y, ret.width, cy))
      ret.blt(0, y + cy, bitmap, Rect.new(0, y + cy, ret.width, 2), 170)
    end
    ret.blt(0, y + cy + 2, bitmap, Rect.new(0, y + cy + 2, ret.width, 2), 85) if cy + 2 >= 0
    return ret
  end
end

#===============================================================================
# Tracks - Modified Footprints (by Mairn)
# Updated by Jony - https://eeveeexpo.com/threads/2608/#post-63146
# Modified by GT_Baka for Pokemon Essentials HD
#===============================================================================
class Sprite_Character < RPG::Sprite
  attr_accessor :character
  attr_accessor :footprints
  attr_accessor :steps
  attr_reader   :follower
  
  # This is the amount the opacity is lowered per frame. It needs to go 256 -> 0,
  # which means setting this to 4 would make each step pair last 64 frames (~1.5s)
  FADE_OUT_SPEED = 2
  
  # Terrain Tags in which tracks can appear on.
  SOFT_TERRAIN = [
    3,  # :Sand
    30, # :Mud
    31, # :Marsh
    32, # :Beach
    44, # :DeepSand
    50, # :Snow,
    53, # :DeepSnow,
    59  # :Cloud
  ]

  # Terrain IDs in which deep tracks can appear.
  DEEP_TERRAIN = [
    :DeepSand,
    :DeepSnow,
    :Marsh
  ]                                               

  # f the event name or graphic name includes any of these strings, it will produce bike tracks.
  BIKE_TRACKS = [
    "biker",
    "cyclist",
    "rolycoly"
  ]

  # A configurable X/Y offset for the step sprites, in case they don't align
  # nicely with the player's graphic.
  WALK_X_OFFSET = 0
  WALK_Y_OFFSET = 0
  
  # A configurable X/Y offset for bike print sprites, in case they don't align
  # nicely with the player's graphic.
  BIKE_X_OFFSET = -8
  BIKE_Y_OFFSET = 0
  
  # If true, both the player AND the follower will create footprints.
  # If false, only the follower will create footprints.
  DUPLICATE_FOOTSTEPS_WITH_FOLLOWER = false
  
  # If the event name or graphic name includes any of these strings, it will not produce tracks.
  NO_TRACKS = [
    "notracks", "no_tracks", "no-tracks", "no.tracks", "!tracks",
    "metapod",
    "kakuna",
    "ekans", "arbok",
    "zubat", "crobat",
    "diglett", "dugtrio",
    "weepinbell", "victreebel",
    "tentacool", "tentacruel",
    "geodude",
    "seel", "dewgong",
    "grimer", "muk",
    "shellder", "cloyster",
    "gastly", "haunter",
    "onix", "steelix",
    "voltorb", "electrode",
    "exeggcute",
    "koffing", "weezing",
    "horsea", "seadra", "kingdra",
    "goldeen", "seaking",
    "jynx",
    "magikarp", "gyarados",
    "lapras",
    "ditto",
    "dratini", "dragonair",
    "chinchou", "lanturn",
    "bellossom",
    "sunkern",
    "misdreavus",
    "unown",
    "pineco", "forretress",
    "dunsparce",
    "qwilfish",
    "slugma", "magcargo",
    "remoraid",
    "mantyke","mantine",
    "pupitar",
    "silcoon", "cascoon",
    "masquerain",
    "gulpin", "swalot",
    "carvanha", "sharpedo",
    "wailmer", "wailord",
    "spoink",
    "seviper",
    "lunatone",
    "solrock",
    "barboach", "whiscash",
    "anorith",
    "feebas", "milotic",
    "castform",
    "shuppet",
    "duskull", "dusknoir",
    "chimecho",
    "glalie", "froslass",
    "spheal", "sealeo", "walrein",
    "clamperl", "huntail", "gorebyss",
    "relicanth",
    "luvdisc",
    "rayquaza",
    "burmy", "wormadam",
    "combee", "vespiquen",
    "drifloon", "drifblim",
    "mismagius",
    "bronzor", "bronzong",
    "carnivine",
    "finneon", "lumineon",
    "magnezone",
    "rotom",
    "giratina_1",
    "cresselia",
    "phione",
    "manaphy",
    "serperior",
    "woobat",
    "tympole",
    "swadloon",
    "whirlipede",
    "cottonee",
    "petilil",
    "basculin",
    "sigilyph",
    "yamask", "cofagrigus",
    "tirtouga",
    "solosis", "duosion", "reuniclus",
    "vanillite", "vanillish", "vanilluxe",
    "escavalier",
    "foongus", "amoonguss",
    "frillish", "jellicent",
    "alomomola",
    "ferroseed",
    "klink", "klang", "klinklang",
    "tynamo", "eelektrik", "eelektross",
    "litwick", "lampent", "chandelure",
    "cryogonal",
    "accelgor",
    "stunfisk",
    "hydreigon",
    "volcarona",
    "tornadus",
    "thundurus",
    "landorus"
  ]
  
  def initialize(viewport, character = nil)
    super(viewport)
    @character    = character
    @oldbushdepth = 0
    @spriteoffset = false
    if !character || character == $game_player || (character.name[/reflection/i] rescue false)
      @reflection = Sprite_Reflection.new(self, viewport)
    end
    @surfbase = Sprite_SurfBase.new(self, viewport) if character == $game_player
    self.zoom_x = TilemapRenderer::ZOOM_X
    self.zoom_y = TilemapRenderer::ZOOM_Y
    if $PokemonGlobal && $PokemonGlobal.respond_to?(:dependentEvents) &&
       $PokemonGlobal.dependentEvents && $PokemonGlobal.dependentEvents.respond_to?(:realEvents) &&
       $PokemonGlobal.dependentEvents.realEvents.is_a?(Array) &&
       $PokemonGlobal.dependentEvents.realEvents.include?(@character)
      @follower = true
    end
    @footprints = []
    @timer = 0
    update
  end

  def groundY
    return @character.screen_y_ground
  end

  def visible=(value)
    super(value)
    @reflection.visible = value if @reflection
  end

  def dispose
    @bushbitmap&.dispose
    @bushbitmap = nil
    @charbitmap&.dispose
    @charbitmap = nil
    @reflection&.dispose
    @reflection = nil
    @surfbase&.dispose
    @surfbase = nil
    @character = nil
    @footprints.each { |prints| prints[0]&.dispose }
    super
  end

  def refresh_graphic
    return if @tile_id == @character.tile_id &&
              @character_name == @character.character_name &&
              @character_hue == @character.character_hue &&
              @oldbushdepth == @character.bush_depth
    @tile_id        = @character.tile_id
    @character_name = @character.character_name
    @character_hue  = @character.character_hue
    @oldbushdepth   = @character.bush_depth
    @charbitmap&.dispose
    @charbitmap = nil
    @bushbitmap&.dispose
    @bushbitmap = nil
    if @tile_id >= 384
      @charbitmap = pbGetTileBitmap(@character.map.tileset_name, @tile_id,
                                    @character_hue, @character.width, @character.height)
      @charbitmapAnimated = false
      @spriteoffset = false
      @cw = Game_Map::TILE_WIDTH * @character.width
      @ch = Game_Map::TILE_HEIGHT * @character.height
      self.src_rect.set(0, 0, @cw, @ch)
      self.ox = @cw / 2
      self.oy = @ch
    elsif @character_name != ""
      @charbitmap = AnimatedBitmap.new(
        "Graphics/Characters/" + @character_name, @character_hue
      )
      RPG::Cache.retain("Graphics/Characters/", @character_name, @character_hue) if @character == $game_player
      @charbitmapAnimated = true
      @spriteoffset = @character_name[/offset/i]
      @cw = @charbitmap.width / 4
      @ch = @charbitmap.height / 4
      self.ox = @cw / 2
    else
      self.bitmap = nil
      @cw = 0
      @ch = 0
    end
    @character.sprite_size = [@cw, @ch]
  end

  def update
    return if @character.is_a?(Game_Event) && !@character.should_update?
    super
    refresh_graphic
    return if !@charbitmap
    @charbitmap.update if @charbitmapAnimated
    bushdepth = @character.bush_depth
    if bushdepth == 0
      self.bitmap = (@charbitmapAnimated) ? @charbitmap.bitmap : @charbitmap
    else
      @bushbitmap = BushBitmap.new(@charbitmap, (@tile_id >= 384), bushdepth) if !@bushbitmap
      self.bitmap = @bushbitmap.bitmap
    end
    self.visible = !@character.transparent
    if @tile_id == 0
      sx = @character.pattern * @cw
      sy = ((@character.direction - 2) / 2) * @ch
      self.src_rect.set(sx, sy, @cw, @ch)
      self.oy = (@spriteoffset rescue false) ? @ch - 16 : @ch
      self.oy -= @character.bob_height
    end
    if self.visible
      if @character.is_a?(Game_Event) && @character.name[/regulartone/i]
        self.tone.set(0, 0, 0, 0)
      else
        pbDayNightTint(self)
      end
    end
    this_x = @character.screen_x
    this_x = ((this_x - (Graphics.width / 2)) * TilemapRenderer::ZOOM_X) + (Graphics.width / 2) if TilemapRenderer::ZOOM_X != 1
    self.x = this_x
    this_y = @character.screen_y
    this_y = ((this_y - (Graphics.height / 2)) * TilemapRenderer::ZOOM_Y) + (Graphics.height / 2) if TilemapRenderer::ZOOM_Y != 1
    self.y = this_y
    self.z = @character.screen_z(@ch)
    self.opacity = @character.opacity
    self.blend_type = @character.blend_type
    if @character.animation_id != 0
      animation = $data_animations[@character.animation_id]
      animation(animation, true)
      @character.animation_id = 0
    end
    @reflection&.update
    @surfbase&.update
    @old_x ||= @character.x
    @old_y ||= @character.y
    @old_dir == nil
    @old_dir = @character.direction if !$game_player.moving?
    if (@character.x != @old_x || @character.y != @old_y) && !["", "nil"].include?(@character.character_name)
      if @character == $game_player && $PokemonGlobal.dependentEvents &&
         $PokemonGlobal.dependentEvents.respond_to?(:realEvents) &&
         $PokemonGlobal.dependentEvents.realEvents.select { |e| !["", "nil"].include?(e.character_name) }.size > 0 &&
         !DUPLICATE_FOOTSTEPS_WITH_FOLLOWER
        if !NO_TRACKS.include?($PokemonGlobal.dependentEvents.realEvents[0].name) &&
           !NO_TRACKS.include?($PokemonGlobal.dependentEvents.realEvents[0].character_name)
          make_tracks = false
        else
          make_tracks = true
        end
      elsif (!@character.respond_to?(:name) || !NO_TRACKS.include?(@character.name.downcase)) &&
             !NO_TRACKS.include?(@character.character_name.downcase)
        tilesetid = @character.map.instance_eval { @map.tileset_id }
        make_tracks = [2,1,0].any? do |e|
          tile_id = @character.map.data[@old_x, @old_y, e]
          next false if tile_id.nil?
          next SOFT_TERRAIN.include?($data_tilesets[tilesetid].terrain_tags[tile_id])
        end
      end
      if make_tracks
        tracks = Sprite.new(self.viewport)
        tracks.z = 0
        pathway = [nil, "Down", "Left", "Right", "Up"]
        angle = pathway[@character.direction / 2]
        case @old_dir
        when 2 # Down
          angle = "BottomRight" if @character.direction == 4 # Left
          angle = "BottomLeft" if @character.direction == 6 # Right
        when 4 # Left
          angle = "TopLeft" if @character.direction == 2 # Down
          angle = "BottomLeft" if @character.direction == 8 # Up
        when 6 # Right
          angle = "TopRight" if @character.direction == 2 # Down
          angle = "BottomRight" if @character.direction == 8 # Up
        when 8 # Up
          angle = "TopRight" if @character.direction == 4 # Left
          angle = "TopLeft" if @character.direction == 6 # Right
        end
        if @character == $game_player
          if DEEP_TERRAIN.include?($game_map.terrain_tag($game_player.x, $game_player.y))
            tracks.bmp("Graphics/Characters/Tracks/#{angle}_Deep")
          elsif $PokemonGlobal.bicycle
            tracks.bmp("Graphics/Characters/Tracks/#{angle}_Bike")
          else
            tracks.bmp("Graphics/Characters/Tracks/#{angle}")
          end
        else
          if DEEP_TERRAIN.include?($game_map.terrain_tag(@character.x, @character.y))
            tracks.bmp("Graphics/Characters/Tracks/#{angle}_Deep")
          elsif BIKE_TRACKS.include?(@character.character_name.downcase) || BIKE_TRACKS.include?(@character.name.downcase)
            tracks.bmp("Graphics/Characters/Tracks/#{angle}_Bike")
          elsif Dir.exist?("Graphics/Characters/Tracks/#{@character.character_name}")
            tracks.bmp("Graphics/Characters/Tracks/#{@character.character_name}/#{angle}")
          elsif Dir.exist?("Graphics/Characters/Tracks/#{@character.name}")
            tracks.bmp("Graphics/Characters/Tracks/#{@character.name}/#{angle}")
          else
            tracks.bmp("Graphics/Characters/Tracks/#{angle}")
          end
        end
        @steps ||= []
        if @character == $game_player && $PokemonGlobal.bicycle
          x = BIKE_X_OFFSET
          y = BIKE_Y_OFFSET
        else
          x = WALK_X_OFFSET
          y = WALK_Y_OFFSET
        end
        @steps << [tracks, @character.map, @old_x + x / Game_Map::TILE_WIDTH.to_f, @old_y + y / Game_Map::TILE_HEIGHT.to_f]
      end
      @old_dir  = @character.direction
    end
    @old_x    = @character.x
    @old_y    = @character.y
    update_footsteps
  end
  
  def update_footsteps
    if @steps
      for i in 0...@steps.size
        next unless @steps[i]
        sprite, map, x, y, ox = @steps[i]
        sprite.x = -map.display_x / Game_Map::X_SUBPIXELS + x * Game_Map::TILE_WIDTH
        sprite.y = -map.display_y / Game_Map::Y_SUBPIXELS + (y + 1) * Game_Map::TILE_HEIGHT
        sprite.y -= Game_Map::TILE_HEIGHT
        sprite.opacity -= FADE_OUT_SPEED
        if sprite.opacity <= 0
          sprite.dispose
          @steps[i] = nil
        end
      end
      @steps.compact!
    end
  end
end

class DependentEventSprites
  attr_accessor :sprites
  
  def refresh
    steps = []
    for sprite in @sprites
      steps << sprite.steps
      if sprite.follower
        $FollowerSteps = sprite.steps
      end
      sprite.steps = []
      sprite.dispose
    end
    @sprites.clear
    $PokemonGlobal.dependentEvents.eachEvent do |event, data|
      if data[0] == @map.map_id # Check original map
        #@map.events[data[1]].erase
      end
      if data[2] == @map.map_id # Check current map
        spr = Sprite_Character.new(@viewport, event)
        if spr.follower
          spr.steps = $FollowerSteps
          $FollowerSteps = nil
        end
        @sprites.push(spr)
      end
    end
  end
end

class Spriteset_Map
  alias footsteps_update update
  def update
    footsteps_update
    # Only update events that are on-screen
    for sprite in @character_sprites
      if sprite.character.is_a?(Game_Event)
        sprite.update_footsteps
      end
    end
  end
end