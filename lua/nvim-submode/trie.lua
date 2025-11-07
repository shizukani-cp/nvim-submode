--- @class TrieNode
--- @field children table<string, TrieNode> A map from a token (string) to its child TrieNode.
--- @field isEndOfWord boolean True if this node marks the end of a valid word.
local function createNode()
    return {
        children = {},
        isEndOfWord = false
    }
end

--- 💡 Common Token Splitting Function
--- Splits a string into tokens. A token is either a single character, or a sequence starting with '<' and ending with '>' (treated as a single tag token).
--- @param s string The string to split.
--- @return string[] tokens A list of tokens.
local function splitTokens(s)
    --- @type string[]
    local tokens = {}
    local i = 1
    while i <= #s do
        if s:sub(i, i) == "<" then
            -- Look for the end of the tag
            local j = s:find(">", i, true)
            if j then
                -- Tag found
                table.insert(tokens, s:sub(i, j))
                i = j + 1
            else
                -- No closing tag, treat as a single character
                table.insert(tokens, s:sub(i, i))
                i = i + 1
            end
        else
            -- Normal single character
            table.insert(tokens, s:sub(i, i))
            i = i + 1
        end
    end
    return tokens
end

--- @class Trie
--- @field root TrieNode The root node of the trie.
local Trie = {}
Trie.__index = Trie

--- Creates a new Trie instance.
--- @return Trie A new Trie object.
function Trie:new()
    --- @type Trie
    local obj = setmetatable({}, self)
    obj.root = createNode()
    return obj
end

--- Inserts a word (or token sequence) into the trie.
--- @param word string The word to insert.
function Trie:insert(word)
    --- @type TrieNode
    local node = self.root
    for _, token in ipairs(splitTokens(word)) do
        if not node.children[token] then
            node.children[token] = createNode()
        end
        node = node.children[token]
    end
    node.isEndOfWord = true
end

--- Searches for a complete word in the trie.
--- @param word string The word to search for.
--- @return boolean True if the word is found, false otherwise.
function Trie:search(word)
    --- @type TrieNode
    local node = self.root
    for _, token in ipairs(splitTokens(word)) do
        if not node.children[token] then
            return false
        end
        node = node.children[token]
    end
    return node.isEndOfWord
end

--- Checks if there is any word in the trie that starts with the given prefix.
--- @param prefix string The prefix to check.
--- @return boolean True if a word with the prefix exists, false otherwise.
function Trie:startsWith(prefix)
    --- @type TrieNode
    local node = self.root
    for _, token in ipairs(splitTokens(prefix)) do
        if not node.children[token] then
            return false
        end
        node = node.children[token]
    end
    return true
end

--- Recursive helper to count all words in the subtree starting from a given node.
--- @param node TrieNode The starting node.
--- @return integer The total count of words in the subtree.
local function _countRecursive(node)
    if not node then return 0 end
    --- @type integer
    local count = node.isEndOfWord and 1 or 0
    for _, child in pairs(node.children) do
        count = count + _countRecursive(child)
    end
    return count
end

--- Counts how many words in the trie start with the given prefix.
--- @param prefix string The prefix to search for.
--- @return integer The number of words starting with the prefix.
function Trie:countStartsWith(prefix)
    --- @type TrieNode
    local node = self.root
    for _, token in ipairs(splitTokens(prefix)) do
        if not node.children[token] then
            return 0
        end
        node = node.children[token]
    end
    return _countRecursive(node)
end

--- Recursive helper to collect all words in the subtree.
--- @param node TrieNode The starting node.
--- @param prefix string The current word formed up to this node.
--- @param results string[] The list to accumulate found words.
local function _collectWords(node, prefix, results)
    if not node then return end

    if node.isEndOfWord then
        table.insert(results, prefix)
    end

    for token, child in pairs(node.children) do
        _collectWords(child, prefix .. token, results)
    end
end

--- Finds all words in the trie that start with the given prefix.
--- @param prefix string The prefix to search for.
--- @return string[] results A list of all words that start with the prefix.
function Trie:findStartsWith(prefix)
    --- @type TrieNode
    local node = self.root
    --- @type string[]
    local results = {}

    -- Traverse to the node corresponding to the prefix
    for _, token in ipairs(splitTokens(prefix)) do
        if not node.children[token] then
            return results -- Return empty list if prefix not found
        end
        node = node.children[token]
    end

    -- Collect all words starting from the prefix node
    _collectWords(node, prefix, results)

    return results
end


return Trie
