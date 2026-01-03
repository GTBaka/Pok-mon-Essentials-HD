#==============================================================================
# 8 Frame walking animations
#------------------------------------------------------------------------------
#  This splits the standing frames and the walking into 2 different sprite
#  sheets. The standing sprite sheet should only consist of 1 frame for each
#  of the 4 directions, while all the movement sprite sheets (walking, running,
#  surfing, etc...) should have 8 frames for each direction.
#
#  The file name for the walking sprite sheet does not change. IE:
#  trainer_POKEMONTRAINER_Red
#
#  The file name for the standing sprite sheet adds "_stand" to the file name.
#  trainer_POKEMONTRAINER_Red_stand
#
#==============================================================================

class Sprite_Character < RPG::Sprite
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
      @cw = @charbitmap.width / (@character_name.include?('_stand') ? 1 : (@character_name.include?('_idle') ? 40 : 8))
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
  end
end

class Game_Character
    def update_pattern
    return if @lock_pattern
#    return if @jumping_on_spot   # Don't animate if jumping on the spot
    # Character has stopped moving, return to original pattern
    if @moved_last_frame && !@moved_this_frame && !@step_anime
      @pattern = @original_pattern
      @anime_count = 0
      return
    end
    # Character has started to move, change pattern immediately
    if !@moved_last_frame && @moved_this_frame && !@step_anime
      @pattern = (@pattern + 1) % 8 if @walk_anime
      @anime_count = 0
      return
    end
    # Calculate how many frames each pattern should display for, i.e. the time
    # it takes to move half a tile (or a whole tile if cycling). We assume the
    # game uses square tiles.
    pattern_time = pattern_update_speed / (@character_name.include?('_idle') ? 4.25 : 8)# frames per cycle in a charset
    return if @anime_count < pattern_time
    # Advance to the next animation frame
    @pattern = (@pattern + 1) % (@character_name.include?('_idle') ? 40 : 8)
    @anime_count -= pattern_time
  end
end


#==============================================================================
# ** Game_Player - Idle Sprites for Pokemon Essentials v21.1
#------------------------------------------------------------------------------
#  With idle sprites. Name the idle sprites the same as their normal ones
#  except with '_idle' on the end (before the extension)
#  Simple, safe implementation to avoid nil errors.
#==============================================================================

# Configuration Constants
IDLE_TIMER_FRAMES = 1800      # Frames to wait before switching to idle (60 = ~1 second)
IDLE_UPDATE_FREQUENCY = 1  # How often to check for idle (every X frames)
IDLE_ANIMATION_SPEED = 0.5  # Speed multiplier for idle animation (lower = slower)

class Game_Player < Game_Character
  #--------------------------------------------------------------------------
  # * Public Instance Variables
  #--------------------------------------------------------------------------
  attr_reader   :current_sprite           # current sprite suffix
  attr_reader   :idle_timer               # timer for idle animation
  
  #--------------------------------------------------------------------------
  # * Object Initialization
  #--------------------------------------------------------------------------
  alias initialize_idlesprites_before initialize
  def initialize
    initialize_idlesprites_before
    @current_sprite = ""
    @idle_timer = 0
    @was_moving = false
    @last_direction = 0
    @original_move_time = nil  # Store original move_time for restoring
  end
  
  #--------------------------------------------------------------------------
  # * Update (simple approach)
  #--------------------------------------------------------------------------
  alias update_idlesprites_before update
  def update
    # Call original update first
    update_idlesprites_before
    
    # Only run idle logic based on frequency setting
    return if Graphics.frame_count % IDLE_UPDATE_FREQUENCY != 0
    
    # Simple idle sprite logic
    begin
      update_idle_logic
    rescue
      # If anything goes wrong, just continue normally
    end
  end
  
  #--------------------------------------------------------------------------
  # * Update Idle Logic (simplified and safe)
  #--------------------------------------------------------------------------
  def update_idle_logic
    # Basic safety checks
    return if !@character_name || @character_name.empty?
    #return if !$player
    
    # Get basic movement state
    is_moving = moving?
    current_input = Input.dir4

    # Simple state tracking
    if is_moving != @was_moving || current_input != @last_direction
      @was_moving = is_moving
      @last_direction = current_input
      
      if is_moving
        # Moving - switch back to normal sprite if needed
        @idle_timer = 0
        if @current_sprite != ""
          switch_to_normal_sprite
        end
      else
        # Not moving - start/continue idle timer
        @idle_timer += 1
      end
    else
      # State hasn't changed, just increment timer if not moving
      @idle_timer += 1 if !is_moving
    end
    
    # Switch to idle sprite after enough time
    if !is_moving && current_input == 0
      #@idle_timer >= IDLE_TIMER_FRAMES ? switch_to_idle_sprite : switch_to_stand_sprite
      switch_to_stand_sprite if @idle_timer < IDLE_TIMER_FRAMES && @idle_timer > 8
      switch_to_idle_sprite if @idle_timer >= IDLE_TIMER_FRAMES && !$game_temp.message_window_showing
    end
    
    # Switch back from idle if player presses a key
    if @current_sprite != "" && current_input != 0 && !$game_temp.message_window_showing
      switch_to_normal_sprite
    end
  end
  
  #--------------------------------------------------------------------------
  # * Switch to Normal Sprite
  #--------------------------------------------------------------------------
  def switch_to_normal_sprite
    return if !@character_name || @character_name.empty?
    return if $game_temp.in_menu
    
    if @character_name.include?('_idle')
      @character_name = @character_name.gsub('_rain_idle', '') if @character_name.include?('_rain_idle')
      @character_name = @character_name.gsub('_sandstorm_idle', '') if @character_name.include?('_sandstorm_idle')
      @character_name = @character_name.gsub('_cold_idle', '') if @character_name.include?('_cold_idle')
      @character_name = @character_name.gsub('_hot_idle', '') if @character_name.include?('_hot_idle')
      @character_name = @character_name.gsub('_wind_idle', '') if @character_name.include?('_wind_idle')
      @character_name = @character_name.gsub('_idle', '') if @character_name.include?('_idle')
      @current_sprite = ""
      @step_anime = false
      @idle_timer = 0
    end

    if @character_name.include?('_stand')
      @character_name = @character_name.gsub('_stand', '')
      @current_sprite = ""
      @step_anime = false
      @idle_timer = 0
    end
      
      # Restore original move_time if we modified it
      if @original_move_time
        @move_time = @original_move_time
        @original_move_time = nil
      end

  end
  
  #--------------------------------------------------------------------------
  # * Switch to Stand Sprite
  #--------------------------------------------------------------------------
  def switch_to_stand_sprite
    return if !@character_name || @character_name.empty?
    return if @character_name.include?('_stand') # Already idle
    
    # Only use idle sprites for basic movement (not surfing, biking, etc.)
    #return if $PokemonGlobal.surfing || $PokemonGlobal.diving || $PokemonGlobal.bicycle
    
    # Try to switch to idle sprite
    idle_name = @character_name + '_stand'
    
    # Check if idle sprite file exists
    if file_exists?("Graphics/Characters/" + idle_name + ".png")
      @character_name = idle_name
      @current_sprite = "_stand"
      @step_anime = false
      
      # Store original move_time and modify it for slower animation
      if IDLE_ANIMATION_SPEED != 1 && !@original_move_time
        @original_move_time = @move_time
        @move_time = @move_time / IDLE_ANIMATION_SPEED
      end
    end
  end

  #--------------------------------------------------------------------------
  # * Switch to Idle Sprite
  #--------------------------------------------------------------------------
  def switch_to_idle_sprite
    return if !@character_name || @character_name.empty?
    return if @character_name.include?('_idle') # Already idle
    idle_type = '_idle'
    
    # Only use idle sprites for basic movement (not surfing, biking, etc.)
    return if $PokemonGlobal.surfing || $PokemonGlobal.diving || $PokemonGlobal.bicycle
    
    # Try to switch to idle sprite
    if @character_name.include?('_stand')
      @character_name = @character_name.gsub('_stand', '')
    end

    # Changes the idle animation depending on the weather and tempature
    if [:Rain, :HeavyRain, :Storm].include?(GameData::Weather.get($game_screen.weather_type).category)
      idle_type = '_rain_idle'
    elsif [:SandStorm].include?(GameData::Weather.get($game_screen.weather_type).category)
      idle_type = '_sandstorm_idle'
    elsif $game_map&.metadata&.has_flag?("TempCold") || [:Snow, :Blizzard, :Hail].include?(GameData::Weather.get($game_screen.weather_type).category) 
      idle_type = '_cold_idle'
    elsif $game_map&.metadata&.has_flag?("TempHot") || [:Sun, :HarshSun].include?(GameData::Weather.get($game_screen.weather_type).category)
      idle_type = '_hot_idle'
    elsif [:Wind, :StrongWinds].include?(GameData::Weather.get($game_screen.weather_type).category)
      idle_type = '_wind_idle'
    end

    idle_name = @character_name + idle_type
    
    # Check if idle sprite file exists
    if file_exists?("Graphics/Characters/" + idle_name + ".png")
      @character_name = idle_name
      @current_sprite = "_idle"
      @step_anime = true
    elsif file_exists?("Graphics/Characters/" + '_idle' + ".png")
      @character_name = @character_name + '_idle'
      @current_sprite = "_idle"
      @step_anime = true
      
      # Store original move_time and modify it for slower animation
      if IDLE_ANIMATION_SPEED != 1 && !@original_move_time
        @original_move_time = @move_time
        @move_time = @move_time / IDLE_ANIMATION_SPEED
      end
    end
  end
  
  #--------------------------------------------------------------------------
  # * Check if File Exists (safe method)
  #--------------------------------------------------------------------------
  def file_exists?(filepath)
    begin
      return pbResolveBitmap(filepath) != nil
    rescue
      begin
        return FileTest.exist?(filepath)
      rescue
        return false
      end
    end
  end

  #--------------------------------------------------------------------------
  # * Set's the speed of the player's movement
  #--------------------------------------------------------------------------

  def can_run?
    return @move_speed > 3 if @move_route_forcing
    return false if @bumping
    return false if $game_temp.in_menu || $game_temp.in_battle ||
                    $game_temp.message_window_showing || pbMapInterpreterRunning?
    return false if !$player.has_running_shoes && !$PokemonGlobal.diving &&
                    !$PokemonGlobal.surfing && !$PokemonGlobal.bicycle
    return false if jumping?
    return false if pbTerrainTag.must_walk
    return ($PokemonSystem.runstyle == 1) ^ Input.press?(Input::BACK)
  end

  def set_movement_type(type)
    meta = GameData::PlayerMetadata.get($player&.character_ID || 1)
    new_charset = nil
    case type
    when :fishing
      new_charset = pbGetPlayerCharset(meta.fish_charset)
    when :surf_fishing
      new_charset = pbGetPlayerCharset(meta.surf_fish_charset)
    when :diving, :diving_fast, :diving_jumping, :diving_stopped
      self.move_speed = 3 if !@move_route_forcing
      new_charset = pbGetPlayerCharset(meta.dive_charset)
    when :surfing, :surfing_fast, :surfing_jumping, :surfing_stopped
      if !@move_route_forcing
        self.move_speed = (type == :surfing_jumping) ? 3 : 4

      end
      new_charset = pbGetPlayerCharset(meta.surf_charset)
    when :descending_waterfall, :ascending_waterfall
      self.move_speed = 2 if !@move_route_forcing
      new_charset = pbGetPlayerCharset(meta.surf_charset)
    when :cycling, :cycling_fast, :cycling_jumping, :cycling_stopped
      if !@move_route_forcing
        self.move_speed = (type == :cycling_jumping) ? 3 : 5
      end
      new_charset = pbGetPlayerCharset(meta.cycle_charset)
    when :running
      self.move_speed = 4 if !@move_route_forcing
      new_charset = pbGetPlayerCharset(meta.run_charset)
    when :ice_sliding
      self.move_speed = 4 if !@move_route_forcing
      new_charset = pbGetPlayerCharset(meta.slide_charset)
    else   # :walking, :jumping, :walking_stopped
      self.move_speed = 3 if !@move_route_forcing
      new_charset = pbGetPlayerCharset(meta.walk_charset)
    end
    self.move_speed = 3 if @bumping
    @character_name = new_charset if new_charset
  end
end

#--------------------------------------------------------------------------
#  Allows the player to animate while on ice.
#--------------------------------------------------------------------------

def pbSlideOnIce
  if !$DEBUG || !Input.press?(Input::CTRL)
    if $game_player.pbTerrainTag.ice && $game_player.can_move_in_direction?($game_player.direction)
      $PokemonGlobal.ice_sliding = true
      $game_player.straighten
      return
    end
  end
  $PokemonGlobal.ice_sliding = false
  $game_player.walk_anime = true
end


# Surf
class Sprite_SurfBase
  attr_reader :visible

  def initialize(parent_sprite, viewport = nil)
    @parent_sprite = parent_sprite
    @sprite = nil
    @viewport = viewport
    @disposed = false
    @surfbitmap = AnimatedBitmap.new("Graphics/Characters/base_surf")
    @divebitmap = AnimatedBitmap.new("Graphics/Characters/base_dive")
    RPG::Cache.retain("Graphics/Characters/base_surf")
    RPG::Cache.retain("Graphics/Characters/base_dive")
    @cws = @surfbitmap.width / 8
    @chs = @surfbitmap.height / 4
    @cwd = @divebitmap.width / 8
    @chd = @divebitmap.height / 4
    update
  end

  def dispose
    return if @disposed
    @sprite&.dispose
    @sprite = nil
    @parent_sprite = nil
    @surfbitmap.dispose
    @divebitmap.dispose
    @disposed = true
  end

  def disposed?
    return @disposed
  end

  def event
    return @parent_sprite.character
  end

  def visible=(value)
    @visible = value
    @sprite.visible = value if @sprite && !@sprite.disposed?
  end

  def update
    return if disposed?
    if !$PokemonGlobal.surfing && !$PokemonGlobal.diving
      # Just-in-time disposal of sprite
      if @sprite
        @sprite.dispose
        @sprite = nil
      end
      return
    end
    # Just-in-time creation of sprite
    @sprite = Sprite.new(@viewport) if !@sprite
    return if !@sprite
    if $PokemonGlobal.surfing
      @sprite.bitmap = @surfbitmap.bitmap
      cw = @cws
      ch = @chs
    elsif $PokemonGlobal.diving
      @sprite.bitmap = @divebitmap.bitmap
      cw = @cwd
      ch = @chd
    end
    sx = event.pattern_surf * cw
    sy = ((event.direction - 2) / 2) * ch
    @sprite.src_rect.set(sx, sy, cw, ch)
    if $game_temp.surf_base_coords
      spr_x = ((($game_temp.surf_base_coords[0] * Game_Map::REAL_RES_X) - event.map.display_x).to_f / Game_Map::X_SUBPIXELS).round
      spr_x += (Game_Map::TILE_WIDTH / 2)
      spr_x = ((spr_x - (Graphics.width / 2)) * TilemapRenderer::ZOOM_X) + (Graphics.width / 2) if TilemapRenderer::ZOOM_X != 1
      @sprite.x = spr_x
      spr_y = ((($game_temp.surf_base_coords[1] * Game_Map::REAL_RES_Y) - event.map.display_y).to_f / Game_Map::Y_SUBPIXELS).round
      spr_y += (Game_Map::TILE_HEIGHT / 2) + 16
      spr_y = ((spr_y - (Graphics.height / 2)) * TilemapRenderer::ZOOM_Y) + (Graphics.height / 2) if TilemapRenderer::ZOOM_Y != 1
      @sprite.y = spr_y
    else
      @sprite.x = @parent_sprite.x
      @sprite.y = @parent_sprite.y
    end
    @sprite.ox      = cw / 2
    @sprite.oy      = ch - 16   # Assume base needs offsetting
    @sprite.oy      -= event.bob_height
    @sprite.z       = event.screen_z(ch) - 1
    @sprite.zoom_x  = @parent_sprite.zoom_x
    @sprite.zoom_y  = @parent_sprite.zoom_y
    @sprite.tone    = @parent_sprite.tone
    @sprite.color   = @parent_sprite.color
    @sprite.opacity = @parent_sprite.opacity
  end
end
