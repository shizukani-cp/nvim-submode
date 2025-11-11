--- A simple implementation of a Queue data structure in Lua using a table.
--- @class Queue
--- @field list table Table to store the queue elements
local Queue = {}
Queue.__index = Queue

--- Creates a new Queue instance.
--- @return Queue A new instance of the Queue class
function Queue:new()
    local instance = {
        list = {}
    }
    setmetatable(instance, Queue)
    return instance
end

--- Adds a value to the end of the queue (enqueue operation).
--- @param value any The value to be added to the queue
function Queue:enqueue(value)
    table.insert(self.list, value)
end

--- Removes and returns the value from the front of the queue (dequeue operation).
--- @return any|nil The value removed from the front, or nil if the queue is empty
function Queue:dequeue()
    return table.remove(self.list, 1)
end

--- Returns the value at the front of the queue without removing it (peek operation).
--- @return any|nil The value at the front, or nil if the queue is empty
function Queue:peek()
    return self.list[1]
end

--- Returns the number of elements in the queue.
--- @return number The size of the queue
function Queue:size()
    return #self.list
end

--- Checks if the queue is empty.
--- @return boolean True if the queue is empty, false otherwise
function Queue:isEmpty()
    return #self.list == 0
end

--- Replaces the value at the front of the queue.
--- @param value any The new value to set at the front
--- @return boolean True if successful, false if the queue is empty
function Queue:setFront(value)
    if #self.list == 0 then
        self:enqueue(value)
        return true
    end
    self.list[1] = value
    return true
end

--- Replaces the value at the end of the queue.
--- @param value any The new value to set at the end
--- @return boolean True if successful, false if the queue is empty
function Queue:setBack(value)
    if #self.list == 0 then
        self:enqueue(value)
        return true
    end
    self.list[#self.list] = value
    return true
end


--- Get the value at the end of the queue.
--- @return any if successful, "" if the queue is empty
function Queue:getBack()
    if #self.list == 0 then
        return ""
    end
    return self.list[#self.list]
end

function Queue:show()
    print("QueueContent:",table.concat(self.list,","))
end
return Queue
