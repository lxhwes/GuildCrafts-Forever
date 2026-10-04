-- Favorites SavedVariables regressions (Modules/Favorites.lua) with stubbed WoW APIs.
-- Run from the repository root: lua5.1 tools/test-favorites.lua
-- Favorites store 1, not true: booleans may not round-trip on Forever.
local db

GuildCrafts = {
    NewModule = function() return {} end,
    Data = {
        NormalizeMemberKey = function(_, key) return key end,
        GetGuildDB = function() return db end,
        IsMemberOnline = function() return false end,
        GetLocalizedRecipeName = function(_, _, name) return name end,
        GetRecipeCategory = function() return nil end,
        GetRecipeReagents = function() return nil end,
    },
}
dofile("GuildCrafts/Modules/Favorites.lua")
local Favorites = GuildCrafts.Favorites

local function reset()
    GuildCraftsCharDB = nil
    db = {
        ["Player-1-AA"] = { professions = { Alchemy = { recipes = { [101] = { name = "Elixir" } } } } },
    }
    Favorites:OnInitialize()
end

local function assertNoBooleans(t)
    for _, v in pairs(t) do
        assert(type(v) ~= "boolean", "boolean stored in SavedVariables")
    end
end

local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end

test("toggling a recipe stores 1", function()
    assert(Favorites:ToggleRecipe(101) == true)
    assert(GuildCraftsCharDB.favoriteRecipes[101] == 1, "stored " .. tostring(GuildCraftsCharDB.favoriteRecipes[101]))
    assert(Favorites:IsRecipeFavorite(101))
    assert(Favorites:ToggleRecipe(101) == false)
    assert(GuildCraftsCharDB.favoriteRecipes[101] == nil)
end)

test("toggling a member stores 1", function()
    assert(Favorites:ToggleMember("Player-1-AA") == true)
    assert(GuildCraftsCharDB.favoriteMembers["Player-1-AA"] == 1)
    assert(Favorites:IsMemberFavorite("Player-1-AA"))
end)

test("saved true entries still read as favorites", function()
    GuildCraftsCharDB = { favoriteRecipes = { [101] = true }, favoriteMembers = { ["Player-1-AA"] = true } }
    assert(Favorites:IsRecipeFavorite(101), "true recipe not a favorite")
    assert(Favorites:IsMemberFavorite("Player-1-AA"), "true member not a favorite")
end)

test("initialize rewrites saved true entries as 1", function()
    GuildCraftsCharDB = { favoriteRecipes = { [101] = true }, favoriteMembers = { ["Player-1-AA"] = true } }
    Favorites:OnInitialize()
    assertNoBooleans(GuildCraftsCharDB.favoriteRecipes)
    assertNoBooleans(GuildCraftsCharDB.favoriteMembers)
    assert(Favorites:IsRecipeFavorite(101) and Favorites:IsMemberFavorite("Player-1-AA"))
end)

test("toggling off a saved true entry removes it", function()
    GuildCraftsCharDB.favoriteRecipes[101] = true
    assert(Favorites:ToggleRecipe(101) == false)
    assert(GuildCraftsCharDB.favoriteRecipes[101] == nil)
end)

test("favorites tab lists recipes and members stored as 1", function()
    Favorites:ToggleRecipe(101)
    Favorites:ToggleMember("Player-1-AA")
    local grouped = Favorites:GetFavoriteRecipesGrouped()
    assert(grouped.Alchemy and #grouped.Alchemy == 1, "recipe missing from favorites tab")
    assert(#Favorites:GetFavoriteMembersInfo() == 1, "member missing from favorites tab")
end)

local failed = 0
for _, case in ipairs(tests) do
    reset()
    local ok, err = pcall(case[2])
    if ok then
        print("PASS " .. case[1])
    else
        failed = failed + 1
        print("FAIL " .. case[1] .. ": " .. tostring(err))
    end
end
assert(failed == 0, failed .. " favorites regression(s) failed")
print(#tests .. " favorites regressions passed")
