-- spec/trie_spec.lua

-- テスト対象のモジュールを読み込む
--local Trie = require("./../../lua/nvim-submode/trie")
local Trie = require("nvim-submode/trie")

describe("Trie (トークナイズ対応)", function()
  local trie

  -- 各`it`ブロックの実行前に、新しいTrieインスタンスを作成
  before_each(function()
    trie = Trie:new()
  end)

  describe(":insert() と :search()", function()
    it("挿入した単語を正しく検索できる", function()
      trie:insert("apple")
      assert.is_true(trie:search("apple"))
    end)

    it("挿入していない単語は検索できない", function()
      trie:insert("apple")
      assert.is_false(trie:search("banana"))
    end)

    it("プレフィックスを単語として検索しない (isEndOfWordフラグ)", function()
      trie:insert("apple")
      -- "app" は挿入したが、単語の終わりではない
      assert.is_false(trie:search("app"))
      assert.is_true(trie:startsWith("app"))
    end)

    it("プレフィックスでもある単語を正しく検索できる", function()
      trie:insert("app")
      trie:insert("apple")
      assert.is_true(trie:search("app"))
      assert.is_true(trie:search("apple"))
    end)

    it("<...> トークンを単一の単位として扱う", function()
      trie:insert("f<any>")
      assert.is_true(trie:search("f<any>"))
      -- トークンが不完全な場合は false
      assert.is_false(trie:search("f<an>"))
      assert.is_false(trie:search("f<any"))
    end)

    it("通常の文字と <...> トークンを区別する", function()
      trie:insert("<esc>")
      assert.is_true(trie:search("<esc>"))
      assert.is_false(trie:search("e"))
      assert.is_false(trie:search("esc"))
    end)

    it("空の文字列を正しく処理できる", function()
      trie:insert("")
      assert.is_true(trie:search(""))
    end)
  end)

  ---

  describe(":startsWith()", function()
    before_each(function()
      trie:insert("apple")
      trie:insert("app")
      trie:insert("f<any>b")
    end)

    it("有効なプレフィックスを検出できる", function()
      assert.is_true(trie:startsWith("a"))
      assert.is_true(trie:startsWith("app"))
    end)

    it("無効なプレフィックスを検出できる", function()
      assert.is_false(trie:startsWith("b"))
      assert.is_false(trie:startsWith("apx"))
    end)

    it("単語全体もプレフィックスとして扱われる", function()
      assert.is_true(trie:startsWith("apple"))
      assert.is_true(trie:startsWith("app"))
    end)

    it("<...> トークンを含むプレフィックスを正しく処理する", function()
      assert.is_true(trie:startsWith("f"))
      assert.is_true(trie:startsWith("f<any>"))
      assert.is_true(trie:startsWith("f<any>b"))
    end)

    it("不完全な <...> トークンはプレフィックスとして認識しない", function()
      assert.is_false(trie:startsWith("f<an"))
    end)

    it("空の文字列は常にtrue (ルートノード)", function()
      assert.is_true(trie:startsWith(""))
    end)
  end)

  ---

  describe(":countStartsWith()", function()
    it("存在しないプレフィックスは0を返す", function()
      assert.are.equal(0, trie:countStartsWith("z"))
    end)

    it("複数の単語を正しくカウントする", function()
      trie:insert("f")
      trie:insert("fa")
      trie:insert("fb")
      assert.are.equal(3, trie:countStartsWith("f"))
      assert.are.equal(1, trie:countStartsWith("fa"))
    end)

    it("単語の終わり (isEndOfWord) のみカウントする (プレフィックスノードは数えない)", function()
      trie:insert("apple") -- "app" は単語ではない
      assert.are.equal(1, trie:countStartsWith("app"))
    end)

    it("プレフィックス自体が単語の場合も正しくカウントする", function()
      trie:insert("app")   -- "app" は単語
      trie:insert("apple") -- "apple" も単語
      assert.are.equal(2, trie:countStartsWith("app"))
      assert.are.equal(2, trie:countStartsWith("a"))
    end)

    it("<...> トークンを含むプレフィックスで正しくカウントする", function()
      trie:insert("f")
      trie:insert("f<any>")
      trie:insert("f<any>b")
      trie:insert("f<esc>")

      assert.are.equal(4, trie:countStartsWith("f"))
      assert.are.equal(2, trie:countStartsWith("f<any>"))
      assert.are.equal(1, trie:countStartsWith("f<any>b"))
      assert.are.equal(1, trie:countStartsWith("f<esc>"))
      assert.are.equal(0, trie:countStartsWith("f<an")) -- 不完全なトークン
    end)

    it("空の文字列は挿入された全単語をカウントする", function()
      trie:insert("a")
      trie:insert("b")
      trie:insert("<c>")
      assert.are.equal(3, trie:countStartsWith(""))
    end)

    it("空の文字列自体が挿入された場合もカウントする", function()
      trie:insert("")
      assert.are.equal(1, trie:countStartsWith(""))
      assert.is.True(trie:search(""))
    end)
  end)

  describe("value", function()
    before_each(function()
      trie:insert("a", function()
        return "a"
      end)
      trie:insert("aa", "aa")
      trie:insert("ab", function()
        return "ab"
      end)
    end)

    it("それぞれの関数を呼び出す", function()
      assert.are.equal(3, trie:countStartsWith("a"))
      assert.equal("a", trie:getLeaf("a").value())
      assert.equal("aa", trie:getLeaf("aa").value)
      assert.equal("ab", trie:getLeaf("ab").value())
      assert.equal("ab", trie:getLeaf("ab").value())
      assert.equal(nil, trie:getLeaf("ac"))
    end)
  end)

  describe(":findStartsWith()", function()
    -- テスト用のヘルパー関数:
    -- 2つのテーブル（配列）をソートして内容が同じか比較する
    local function assert_tables_are_same_set(actual, expected)
      if not actual then actual = {} end
      if not expected then expected = {} end

      table.sort(actual)
      table.sort(expected)
      assert.are.same(actual, expected)
    end

    before_each(function()
      -- このテストブロック用の共通データをセットアップ
      trie:insert("f")
      trie:insert("fa")
      trie:insert("fb")
      trie:insert("f<any>")
      trie:insert("f<any>b")
      trie:insert("<esc>")
      trie:insert("<esc>a")
      trie:insert("z")
    end)

    it("単純なプレフィックスで複数の単語を正しく見つける", function()
      local results = trie:findStartsWith("f")
      local expected = { "f", "fa", "fb", "f<any>", "f<any>b" }
      assert_tables_are_same_set(results, expected)
    end)

    it("プレフィックス自体が単語の場合、それも結果に含める", function()
      local results = trie:findStartsWith("fa")
      local expected = { "fa" }
      assert_tables_are_same_set(results, expected)
    end)

    it("<...> トークンを含むプレフィックスで正しく見つける", function()
      local results = trie:findStartsWith("f<any>")
      local expected = { "f<any>", "f<any>b" }
      assert_tables_are_same_set(results, expected)
    end)

    it("<...> トークンのみのプレフィックスで正しく見つける", function()
      local results = trie:findStartsWith("<esc>")
      local expected = { "<esc>", "<esc>a" }
      assert_tables_are_same_set(results, expected)
    end)

    it("存在しないプレフィックスは空のテーブルを返す", function()
      local results = trie:findStartsWith("g")
      local expected = {}
      assert_tables_are_same_set(results, expected)
    end)

    it("不完全なトークンはプレフィックスとしてマッチしない", function()
      local results = trie:findStartsWith("f<an")
      local expected = {}
      assert_tables_are_same_set(results, expected)
    end)

    it("空のプレフィックス (\"\") は全ての単語を返す", function()
      local results = trie:findStartsWith("")
      local expected = { "f", "fa", "fb", "f<any>", "f<any>b", "<esc>", "<esc>a", "z" }
      assert_tables_are_same_set(results, expected)
    end)

    it("プレフィックスにはマッチするが単語が存在しない場合", function()
      trie:insert("longprefix_word")
      -- "longprefix" は "startsWith" は true だが、
      -- "findStartsWith" は "isEndOfWord" が true のものだけを返す
      local results = trie:findStartsWith("longprefix")
      local expected = { "longprefix_word" }
      assert_tables_are_same_set(results, expected)
    end)
  end)
end)
