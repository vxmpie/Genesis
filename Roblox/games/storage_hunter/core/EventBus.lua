local EventBus = {}
local bindables = {}

function EventBus.Get(name)
    if not bindables[name] then
        local b = Instance.new("BindableEvent")
        bindables[name] = b
    end
    return bindables[name]
end

function EventBus.Fire(name, ...)
    EventBus.Get(name):Fire(...)
end

function EventBus.Connect(name, callback)
    return EventBus.Get(name).Event:Connect(callback)
end

function EventBus.Destroy()
    for _, b in pairs(bindables) do
        pcall(function() b:Destroy() end)
    end
    bindables = {}
end

return EventBus
