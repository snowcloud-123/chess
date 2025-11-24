-- loader.lua
-- Wrapper loader: safe HttpGet/HttpPost + retry + simple fallback
-- Thay RAW_ORIG = link raw của script gốc (Pastebin raw hoặc raw.githubusercontent link to your 'chess' file)

local RAW_ORIG = "https://raw.githubusercontent.com/snowcloud-123/chess/main/chess" -- <-- nếu bạn dùng pastebin thì thay bằng pastebin raw link
local ALT_API_REPLACEMENTS = {
    -- nếu script gọi trực tiếp chess-api.com, loader sẽ thử thay host bằng các base khác (nếu muốn)
    -- (bạn có thể để trống hoặc thêm endpoint khác nếu biết)
    -- ví dụ: ["https://chess-api.com"] = {"https://stockfishapi.example.com", "https://another.example.com"}
}

local function safeHttpGet(url, noCache)
    -- Thử gọi game:HttpGet tối đa 5 lần, mỗi lần chờ 0.5s
    for i = 1, 5 do
        local ok, res = pcall(function()
            return game:HttpGet(url, noCache)
        end)
        if ok and res and res ~= "" then
            return res
        end
        task.wait(0.5)
    end

    -- Nếu url chứa chess-api (hoặc bạn muốn fallback host), thử thay host với ALT_API_REPLACEMENTS
    for origHost, altHosts in pairs(ALT_API_REPLACEMENTS) do
        if string.find(url, origHost, 1, true) then
            for _, alt in ipairs(altHosts) do
                local altUrl = string.gsub(url, origHost, alt)
                for i = 1, 3 do
                    local ok, res = pcall(function()
                        return game:HttpGet(altUrl, noCache)
                    end)
                    if ok and res and res ~= "" then
                        return res
                    end
                    task.wait(0.5)
                end
            end
        end
    end

    return nil
end

local function safeHttpPost(url, body, headers)
    for i = 1, 5 do
        local ok, res = pcall(function()
            return game:HttpPost(url, body, headers)
        end)
        if ok and res and res ~= "" then
            return res
        end
        task.wait(0.5)
    end
    return nil
end

-- Fetch original source
local source = safeHttpGet(RAW_ORIG, true)
if not source then
    -- nếu không lấy được, báo lỗi (bạn có thể đổi thành fallback message)
    error("Loader error: cannot fetch original script from " .. tostring(RAW_ORIG))
    return
end

-- Replace some common direct calls to HTTP so script will use safe wrappers:
-- Replace game:HttpGet and game.HttpGet with safeHttpGet
source = source:gsub("game:HttpGet", "safeHttpGet")
source = source:gsub("game%.HttpGet", "safeHttpGet")
-- Replace game:HttpPost and game.HttpPost with safeHttpPost
source = source:gsub("game:HttpPost", "safeHttpPost")
source = source:gsub("game%.HttpPost", "safeHttpPost")

-- If the script used something like HttpService:GetAsync, we can optionally wrap that too:
source = source:gsub("HttpService:GetAsync%s*%(", "safeHttpGet(")
source = source:gsub("HttpService:PostAsync%s*%(", "safeHttpPost(")

-- Provide safeHttpGet/ safeHttpPost in global env for the loaded script
_G.safeHttpGet = safeHttpGet
_G.safeHttpPost = safeHttpPost

-- Load and run original script (now patched to use safe wrappers)
local fn, err = loadstring(source)
if not fn then
    error("Loader: loadstring failed: " .. tostring(err))
    return
end

local ok, e = pcall(fn)
if not ok then
    warn("Loader: script runtime error: " .. tostring(e))
end
