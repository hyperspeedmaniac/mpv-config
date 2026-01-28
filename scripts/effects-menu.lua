local mp = require 'mp'
local assdraw = require 'mp.assdraw'

local active = false
local selected = 1
local options = {"gamma", "brightness", "contrast", "saturation", "sharpen"}
local labels = {"Гамма", "Яркость", "Контраст", "Насыщенность", "Четкость"}
local base_steps = {0.05, 0.5, 0.5, 0.5, 0.05}

local input_mode = false
local input_buffer = ""

-- Для ускорения при быстрых нажатиях
local last_press_time = 0
local speed_multiplier = 1
local max_multiplier = 10

local function get_value(name)
    return mp.get_property_number(name, 0)
end

local function set_value(name, val)
    mp.set_property_number(name, val)
end

local function calc_speed()
    local now = mp.get_time()
    local diff = now - last_press_time
    last_press_time = now
    
    -- Чем быстрее нажатия, тем больше множитель
    if diff < 0.1 then
        speed_multiplier = math.min(speed_multiplier + 2, max_multiplier)
    elseif diff < 0.2 then
        speed_multiplier = math.min(speed_multiplier + 1, max_multiplier)
    elseif diff < 0.4 then
        -- держим текущий
    else
        speed_multiplier = 1
    end
    
    return speed_multiplier
end

local function draw_menu()
    if not active then return end
    
    local ass = assdraw.ass_new()
    ass:new_event()
    ass:pos(50, 50)
    ass:append("{\\fs24\\bord2\\c&HFFFFFF&\\3c&H000000&}")
    ass:append("─── Эффекты ───\\N\\N")
    
    for i, opt in ipairs(options) do
        local val = get_value(opt)
        local prefix = (i == selected) and "► " or "   "
        local color = (i == selected) and "{\\c&H00FFFF&}" or "{\\c&HFFFFFF&}"
        
        if i == selected and input_mode then
            ass:append(string.format("%s%s%s: {\\c&H00FF00&}%s_\\N", color, prefix, labels[i], input_buffer))
        else
            ass:append(string.format("%s%s%s: %.2f\\N", color, prefix, labels[i], val))
        end
    end
    
    -- Показываем скорость
    local speed_bar = string.rep("●", speed_multiplier) .. string.rep("○", max_multiplier - speed_multiplier)
    ass:append(string.format("\\N{\\c&HFF6600&\\fs16}Скорость: %s x%d\\N", speed_bar, speed_multiplier))
    
    if input_mode then
        ass:append("\\N{\\c&H00FF00&\\fs18}Ввод числа | Enter ОК | Esc отмена")
    else
        ass:append("{\\c&H888888&\\fs18}↑↓ выбор | ←→ изменить (быстрее жми = быстрее едет) | 0-9 ввод | R сброс | E закрыть")
    end
    
    mp.set_osd_ass(1920, 1080, ass.text)
end

local function clear_menu()
    mp.set_osd_ass(1920, 1080, "")
end

local function toggle_menu()
    active = not active
    input_mode = false
    input_buffer = ""
    speed_multiplier = 1
    if active then
        draw_menu()
    else
        clear_menu()
    end
end

local function menu_up()
    if not active or input_mode then return end
    selected = selected - 1
    if selected < 1 then selected = #options end
    speed_multiplier = 1
    draw_menu()
end

local function menu_down()
    if not active or input_mode then return end
    selected = selected + 1
    if selected > #options then selected = 1 end
    speed_multiplier = 1
    draw_menu()
end

local function change_value(dir)
    if not active or input_mode then return end
    local speed = calc_speed()
    local opt = options[selected]
    local val = get_value(opt)
    local step = base_steps[selected] * speed
    set_value(opt, val + (step * dir))
    draw_menu()
end

local function menu_reset()
    if not active then return end
    input_mode = false
    input_buffer = ""
    speed_multiplier = 1
    for _, opt in ipairs(options) do
        set_value(opt, 0)
    end
    draw_menu()
    mp.osd_message("Сброс!", 1)
end

local function start_input(char)
    if not active then return end
    input_mode = true
    input_buffer = char
    draw_menu()
end

local function add_input(char)
    if not active or not input_mode then return end
    input_buffer = input_buffer .. char
    draw_menu()
end

local function confirm_input()
    if not active or not input_mode then return end
    local val = tonumber(input_buffer)
    if val then
        set_value(options[selected], val)
    end
    input_mode = false
    input_buffer = ""
    draw_menu()
end

local function cancel_input()
    if not active then return end
    input_mode = false
    input_buffer = ""
    draw_menu()
end

local function backspace()
    if not active or not input_mode then return end
    input_buffer = input_buffer:sub(1, -2)
    draw_menu()
end

local function handle_digit(d)
    return function()
        if not active then return end
        if input_mode then
            add_input(d)
        else
            start_input(d)
        end
    end
end

mp.add_key_binding("e", "toggle-effects-menu", toggle_menu)
mp.add_key_binding("UP", "effects-up", menu_up, {repeatable=true})
mp.add_key_binding("DOWN", "effects-down", menu_down, {repeatable=true})
mp.add_key_binding("LEFT", "effects-left", function() change_value(-1) end, {repeatable=true})
mp.add_key_binding("RIGHT", "effects-right", function() change_value(1) end, {repeatable=true})
mp.add_key_binding("r", "effects-reset", menu_reset)

mp.add_key_binding("0", "input-0", handle_digit("0"))
mp.add_key_binding("1", "input-1", handle_digit("1"))
mp.add_key_binding("2", "input-2", handle_digit("2"))
mp.add_key_binding("3", "input-3", handle_digit("3"))
mp.add_key_binding("4", "input-4", handle_digit("4"))
mp.add_key_binding("5", "input-5", handle_digit("5"))
mp.add_key_binding("6", "input-6", handle_digit("6"))
mp.add_key_binding("7", "input-7", handle_digit("7"))
mp.add_key_binding("8", "input-8", handle_digit("8"))
mp.add_key_binding("9", "input-9", handle_digit("9"))
mp.add_key_binding(".", "input-dot", function() if input_mode then add_input(".") end end)
mp.add_key_binding("-", "input-minus", function() 
    if not active then return end
    if input_mode then
        if input_buffer == "" then add_input("-") end
    else
        start_input("-")
    end
end)

mp.add_key_binding("KP_ENTER", "confirm-input", confirm_input)
mp.add_key_binding("ENTER", "confirm-input2", confirm_input)
mp.add_key_binding("ESC", "cancel-input", cancel_input)
mp.add_key_binding("BS", "backspace", backspace)
