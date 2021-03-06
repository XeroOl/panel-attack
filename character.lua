require("character_loader")

  -- Stuff defined in this file: the data structure that store a character's data

local basic_images = { "icon" }
local other_images = {"topleft", "botleft", "topright", "botright",
                  "top", "bot", "left", "right", "face", "pop",
                  "doubleface", "filler1", "filler2", "flash",
                  "portrait"}
local defaulted_images = { icon=true, topleft=true, botleft=true, topright=true, botright=true,
                  top=true, bot=true, left=true, right=true, face=true, pop=true,
                  doubleface=true, filler1=true, filler2=true, flash=true,
                  portrait=true } -- those images will be defaulted if missing
local basic_sfx = {"selection"}
local other_sfx = {"chain", "combo", "combo_echo", "chain_echo", "chain2" ,"chain2_echo", "garbage_match", "win", "taunt_up", "taunt_down"}
local defaulted_sfxs = {} -- those sfxs will be defaulted if missing
local basic_musics = {}
local other_musics = {"normal_music", "danger_music", "normal_music_start", "danger_music_start"}
local defaulted_musics = {} -- those musics will be defaulted if missing

local default_character = nil -- holds default assets fallbacks

Character = class(function(self, full_path, folder_name)
    self.path = full_path -- string | path to the character folder content
    self.id = folder_name -- string | id of the character, specified in config.json
    self.display_name = self.id -- string | display name of the stage
    self.stage = nil -- string | stage that get selected upon doing the super selection of that character
    self.panels = nil -- string | panels that get selected upon doing the super selection of that character
    self.images = {}
    self.sounds = { combos = {}, combo_echos = {}, selections = {}, wins = {}, garbage_matches = {}, taunt_ups = {}, taunt_downs = {}, others = {} }
    self.musics = {}
    self.fully_loaded = false
  end)

function Character.id_init(self)
  local read_data = {}
  local config_file, err = love.filesystem.newFile(self.path.."/config.json", "r")
  if config_file then
    local teh_json = config_file:read(config_file:getSize())
    for k,v in pairs(json.decode(teh_json)) do
      read_data[k] = v
    end
  end

  if read_data.id then
    self.id = read_data.id
    return true
  end

  return false
end

function Character.other_data_init(self)
  -- read .json
  local read_data = {}
  local config_file, err = love.filesystem.newFile(self.path.."/config.json", "r")
  if config_file then
    local teh_json = config_file:read(config_file:getSize())
    for k,v in pairs(json.decode(teh_json)) do
      read_data[k] = v
    end
  end
  
  -- id has already been handled! DO NOT handle id here!

  -- display name
  if read_data.name then
    self.display_name = read_data.name
  end
  -- associated stage
  if read_data.stage and stages[read_data.stage] then
    self.stage = read_data.stage
  end
  -- associated panel
  if read_data.panels and panels[read_data.panels] then
    self.panels = read_data.panels
  end
end

function Character.stop_sounds(self)
  -- SFX
  for _, sound_table in ipairs(self.sounds) do
    if type(sound_table) == "table" then
      for _,sound in pairs(sound_table) do
        sound:stop()
      end
    end
  end

  -- music
  for _, music in ipairs(self.musics) do
    if self.musics[music] then
      self.musics[music]:stop()
    end
  end
end

function Character.play_selection_sfx(self)
  if not SFX_mute and #self.sounds.selections ~= 0 then
    self.sounds.selections[math.random(#self.sounds.selections)]:play()
  end
end

function Character.preload(self)
  print("preloading character "..self.id)
  self:other_data_init()
  self:graphics_init(false,false)
  self:sound_init(false,false)
end

function Character.load(self,instant)
  print("loading character "..self.id)
  self:graphics_init(true,(not instant))
  self:sound_init(true,(not instant))
  self.fully_loaded = true
  print("loaded character "..self.id)
end

function Character.unload(self)
  print("unloading character "..self.id)
  self:graphics_uninit()
  self:sound_uninit()
  self.fully_loaded = false
  print("unloaded character "..self.id)
end

local function add_characters_from_dir_rec(path)
  local lfs = love.filesystem
  local raw_dir_list = lfs.getDirectoryItems(path)
  for i,v in ipairs(raw_dir_list) do
    local start_of_v = string.sub(v,0,string.len(prefix_of_ignored_dirs))
    if start_of_v ~= prefix_of_ignored_dirs then
      local current_path = path.."/"..v
      if lfs.getInfo(current_path) and lfs.getInfo(current_path).type == "directory" then
        -- call recursively: facade folder
        add_characters_from_dir_rec(current_path)

        -- init stage: 'real' folder
        local character = Character(current_path,v)
        local success = character:id_init()

        if success then
          if characters[character.id] ~= nil then
            print(current_path.." has been ignored since a character with this id has already been found")
          else
            characters[character.id] = character
            characters_ids[#characters_ids+1] = character.id
            -- print(current_path.." has been added to the character list!")
          end
        end
      end
    end
  end
end

function characters_init()
  characters = {} -- holds all characters, most of them will not be fully loaded
  characters_ids = {} -- holds all characters ids
  characters_ids_for_current_theme = {} -- holds characters ids for the current theme, those characters will appear in the lobby
  characters_ids_by_display_names = {} -- holds keys to array of character ids holding that name

  add_characters_from_dir_rec("characters")

  if love.filesystem.getInfo("themes/"..config.theme.."/characters.txt") then
    for line in love.filesystem.lines("themes/"..config.theme.."/characters.txt") do
      line = trim(line) -- remove whitespace
      if characters[line] then
        -- found at least a valid stage in a characters.txt file
        characters_ids_for_current_theme[#characters_ids_for_current_theme+1] = line
      end
    end
  end

  -- all characters case
  if #characters_ids_for_current_theme == 0 then
    characters_ids_for_current_theme = shallowcpy(characters_ids)
  end

  -- fix config character if it's missing
  if not config.character or ( config.character ~= random_character_special_value and not characters[config.character] ) then
    config.character = uniformly(characters_ids_for_current_theme)
  end

  -- actual init for all stages, starting with the default one
  default_character = Character("characters/__default", "__default")
  default_character:preload()
  default_character:load(true)

  for _,character in pairs(characters) do
    character:preload()

    if characters_ids_by_display_names[character.display_name] then
      characters_ids_by_display_names[character.display_name][#characters_ids_by_display_names[character.display_name]+1] = character.id
    else
      characters_ids_by_display_names[character.display_name] = { character.id }
    end
  end

  if config.character ~= random_character_special_value then
    character_loader_load(config.character)
    character_loader_wait()
  end
end

function Character.graphics_init(self,full,yields)
  local character_images = full and other_images or basic_images
  for _,image_name in ipairs(character_images) do
    self.images[image_name] = load_img_from_supported_extensions(self.path.."/"..image_name)
    if not self.images[image_name] and defaulted_images[image_name] then
      self.images[image_name] = default_character.images[image_name]
    end
    if yields then coroutine.yield() end
  end
end

function Character.graphics_uninit(self)
  for _,image_name in ipairs(other_images) do
    self.images[image_name] = nil
  end
end

function Character.init_sfx_variants(self, sfx_array, sfx_name)
  local sound_name = sfx_name..1
  if self.sounds.others[sfx_name] then
    -- "combo" in others will be stored in "combo1" in combos and others will be freed from it
    sfx_array[1] = self.sounds.others[sfx_name]
    self.sounds.others[sfx_name] = nil
  else
    local sound = load_sound_from_supported_extensions(self.path.."/"..sound_name, false)
    if sound then
      sfx_array[1] = sound
    end
  end

  -- search for all variants
  local sfx_count = 1
  while sfx_array[sfx_count] do
    sfx_count = sfx_count+1
    sound_name = sfx_name..sfx_count
    local sound = load_sound_from_supported_extensions(self.path.."/"..sound_name, false)
    if sound then
      sfx_array[sfx_count] = sound
    end
  end
end

function Character.apply_config_volume(self)
  set_volume(self.sounds, config.SFX_volume/100)
  set_volume(self.musics, config.music_volume/100)
end

function Character.sound_init(self,full,yields)
  -- SFX
  local character_sfx = full and other_sfx or basic_sfx
  for _, sfx in ipairs(character_sfx) do
    self.sounds.others[sfx] = load_sound_from_supported_extensions(self.path.."/"..sfx, false)

    -- fallback case: chain/combo can be used for the other one if missing and for the longer names versions ("combo" used for "combo_echo" for instance)
    if not self.sounds.others[sfx] then
      if sfx == "combo" then
        self.sounds.others[sfx] = load_sound_from_supported_extensions(self.path.."/chain", false)
      elseif sfx == "chain" then 
        self.sounds.others[sfx] = load_sound_from_supported_extensions(self.path.."/combo", false)
      elseif string.find(sfx, "chain") then
        self.sounds.others[sfx] = load_sound_from_supported_extensions(self.path.."/chain", false)
      elseif string.find(sfx, "combo") then 
        self.sounds.others[sfx] = load_sound_from_supported_extensions(self.path.."/combo", false)
      end
    end
    if not self.sounds.others[sfx] and defaulted_sfxs[sfx] then
      self.sounds.others[sfx] = default_character.sounds.others[sfx] or zero_sound
    end
    if yields then coroutine.yield() end
  end

  if not full then
    self:init_sfx_variants(self.sounds.selections, "selection")
    if yields then coroutine.yield() end
  else
    self:init_sfx_variants(self.sounds.combos, "combo")
    if yields then coroutine.yield() end
    self:init_sfx_variants(self.sounds.combo_echos, "combo_echo")
    if yields then coroutine.yield() end
    self:init_sfx_variants(self.sounds.wins, "win")
    if yields then coroutine.yield() end
    self:init_sfx_variants(self.sounds.garbage_matches, "garbage_match")
    if yields then coroutine.yield() end
    -- those two are maxed at 10 since this is a server requirement
    self:init_sfx_variants(self.sounds.taunt_downs, "taunt_down")
    if yields then coroutine.yield() end
    self:init_sfx_variants(self.sounds.taunt_ups, "taunt_up")
    if yields then coroutine.yield() end
  end

  -- music
  local character_musics = full and other_musics or basic_musics
  for _, music in ipairs(character_musics) do
    self.musics[music] = load_sound_from_supported_extensions(self.path.."/"..music, true)
    -- Set looping status for music.
    -- Intros won't loop, but other parts should.
    if self.musics[music] then
      if not string.find(music, "start") then
        self.musics[music]:setLooping(true)
      else
        self.musics[music]:setLooping(false)
      end
    elseif not self.musics[music] and defaulted_musics[music] then
      self.musics[music] = default_character.musics[music] or zero_sound
    end

    if yields then coroutine.yield() end
  end
  
  self:apply_config_volume()
end

function Character.sound_uninit(self)
  -- SFX
  for _,sound in ipairs(other_sfx) do
    self.sounds.others[sound] = nil
  end
  self.sounds.combos = {}
  self.sounds.combo_echos = {}
  self.sounds.wins = {}
  self.sounds.garbage_matches = {}

  -- music
  for _,music in ipairs(other_musics) do
    self.musics[music] = nil
  end
end