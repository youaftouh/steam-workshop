singleton_name = "orchard"

local columns, rows, cell_size = 20, 14, 28
local board_width, board_height = columns * cell_size, rows * cell_size
local board_y = 10

local colors = {
    board = Color(0.070, 0.137, 0.114, 1),
    grid = Color(0.103, 0.181, 0.151, 1),
    border = Color(0.242, 0.389, 0.296, 1),
    head = Color(0.830, 0.994, 0.504, 1),
    body = Color(0.343, 0.718, 0.367, 1),
    apple = Color(0.988, 0.384, 0.314, 1),
    leaf = Color(0.639, 0.868, 0.510, 1),
    text = Color(0.925, 0.970, 0.889, 1),
    muted = Color(0.626, 0.752, 0.666, 1),
    panel = Color(0.041, 0.093, 0.073, 0.98),
}

local snake, apple, direction, queued_turn
local score, best, clock = 0, 0, 0
local phase = "ready"
local interact_was_down = false

local function rectangle(id, x, y, width, height, color, layer)
    set_image({
        name = id, image_path = "pixel", position = Vector2(x, y),
        scale = Vector2(width, height), modulate = color, z_index = layer, visible = true,
    })
end

local function label(id, caption, x, y, width, height, font_size, color, layer)
    set_label({
        name = id, text = caption, position = Vector2(x - width / 2, y - height / 2),
        size = Vector2(width * 2, height * 2), scale = 0.5,
        font_size = font_size * 2, font_color = color,
        horizontal_alignment = 1, vertical_alignment = 1, z_index = layer, visible = true,
    })
end

local function cell_center(cell)
    return (cell.x - 0.5) * cell_size - board_width / 2,
        (cell.y - 0.5) * cell_size - board_height / 2 + board_y
end

local function render_score()
    label("orchard_score", string.format("SCORE  %02d     BEST  %02d", score, best),
        0, -218, 560, 27, 16, colors.muted, 5)
end

local function render_board()
    for index, segment in ipairs(snake) do
        local x, y = cell_center(segment)
        rectangle("orchard_segment_" .. index, x, y, 24, 24,
            index == 1 and colors.head or colors.body, 3)
    end
    local visible = apple ~= nil
    if visible then
        local x, y = cell_center(apple)
        rectangle("orchard_apple", x, y + 2, 17, 17, colors.apple, 3)
        rectangle("orchard_leaf", x + 4, y - 9, 8, 4, colors.leaf, 4)
    else
        set_image({ name = "orchard_apple", visible = false })
        set_image({ name = "orchard_leaf", visible = false })
    end
end

local function render_message(title, hint)
    if title then
        rectangle("orchard_message", 0, board_y, 344, 102, colors.panel, 6)
        label("orchard_message_title", title, 0, board_y - 17, 320, 36, 27, colors.text, 7)
        label("orchard_message_hint", hint, 0, board_y + 20, 320, 28, 16, colors.muted, 7)
    else
        set_image({ name = "orchard_message", visible = false })
        set_label({ name = "orchard_message_title", visible = false })
        set_label({ name = "orchard_message_hint", visible = false })
    end
end

local function reset_round()
    if snake then
        for index = 4, #snake do
            set_image({ name = "orchard_segment_" .. index, visible = false })
        end
    end
    snake = { { x = 9, y = 7 }, { x = 8, y = 7 }, { x = 7, y = 7 } }
    apple = { x = 14, y = 7 }
    direction = { x = 1, y = 0 }
    queued_turn = nil
    score, clock = 0, 0
    render_score()
    render_board()
end

local function place_apple()
    local occupied = {}
    for _, segment in ipairs(snake) do
        occupied[(segment.y - 1) * columns + segment.x] = true
    end
    local free_cells = {}
    for index = 1, columns * rows do
        if not occupied[index] then
            free_cells[#free_cells + 1] = index
        end
    end
    if #free_cells == 0 then
        return nil
    end
    local index = free_cells[math.random(#free_cells)] - 1
    return { x = index % columns + 1, y = math.floor(index / columns) + 1 }
end

local function finish_round(title)
    phase = "over"
    render_message(title, "Press @key_7@ to play again")
end

local function advance()
    direction = queued_turn or direction
    queued_turn = nil
    local x, y = snake[1].x + direction.x, snake[1].y + direction.y
    if x < 1 or x > columns or y < 1 or y > rows then
        finish_round("Hit the wall")
        return
    end

    local growing = x == apple.x and y == apple.y
    -- The last segment vacates its square on a move that doesn't eat an apple.
    local last_solid_segment = growing and #snake or #snake - 1
    for index = 1, last_solid_segment do
        if snake[index].x == x and snake[index].y == y then
            finish_round("Hit your tail")
            return
        end
    end

    if not growing then
        table.remove(snake)
    end
    table.insert(snake, 1, { x = x, y = y })
    if growing then
        score = score + 1
        best = math.max(best, score)
        apple = place_apple()
        render_score()
    end
    render_board()
    if not apple then
        finish_round("Orchard cleared!")
    end
end

function _process(delta, inputs)
    local interact = inputs and inputs.key_7 == true
    local pressed = interact and not interact_was_down
    interact_was_down = interact

    if phase ~= "playing" then
        if pressed then
            reset_round()
            phase = "playing"
            render_message()
        end
        return
    end

    local stick = inputs and inputs.stick_1
    if stick and not queued_turn then
        local x, y = stick.x, stick.y
        if math.abs(x) >= math.abs(y) and math.abs(x) >= 0.35 and direction.x == 0 then
            queued_turn = { x = x > 0 and 1 or -1, y = 0 }
        elseif math.abs(y) > math.abs(x) and math.abs(y) >= 0.35 and direction.y == 0 then
            queued_turn = { x = 0, y = y > 0 and 1 or -1 }
        end
    end

    local interval = math.max(0.085, 0.26 - score * 0.009)
    clock = clock + math.min(delta, interval)
    if clock >= interval then
        clock = clock - interval
        advance()
    end
end

rectangle("orchard_border", 0, board_y, board_width + 6, board_height + 6, colors.border, 0)
rectangle("orchard_board", 0, board_y, board_width, board_height, colors.board, 1)
for column = 1, columns - 1 do
    local x = column * cell_size - board_width / 2
    rectangle("orchard_grid_column_" .. column, x, board_y, 1, board_height, colors.grid, 2)
end
for row = 1, rows - 1 do
    local y = row * cell_size - board_height / 2 + board_y
    rectangle("orchard_grid_row_" .. row, 0, y, board_width, 1, colors.grid, 2)
end
label("orchard_title", "ORCHARD COIL", 0, -255, 560, 40, 32, colors.text, 5)
label("orchard_controls", "@stick_1@ Steer  /  Collect apples and avoid the wall and your tail",
    0, 236, 680, 32, 16, colors.muted, 5)
reset_round()
render_message("Ready to coil?", "Press @key_7@ to start")
