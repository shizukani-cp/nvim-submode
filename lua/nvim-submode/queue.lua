-- キューの「クラス」を定義
local Queue = {}
Queue.__index = Queue

-- コンストラクタ
function Queue:new()
    local instance = {
        list = {} -- データを格納するテーブル
    }
    setmetatable(instance, Queue)
    return instance
end

-- キューの末尾に値を追加 (Enqueue)
function Queue:enqueue(value)
    table.insert(self.list, value)
end

-- キューの先頭から値を取り出し (Dequeue)
function Queue:dequeue()
    -- table.removeは、インデックス1（先頭）の要素を削除し、その値を返す
    return table.remove(self.list, 1)
end

-- キューの先頭の値を（取り出さずに）見る (Peek)
function Queue:peek()
    return self.list[1]
end

-- キューの要素数を返す
function Queue:size()
    return #self.list
end

-- キューが空かどうかを返す
function Queue:isEmpty()
    return #self.list == 0
end

return Queue
