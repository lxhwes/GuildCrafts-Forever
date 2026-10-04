-- Size of N1 CSV/JSON and an N3 SavedVariables block for a synthetic guild.
-- Run from anywhere: lua5.1 spec/later/research/export-size.lua [members] [recipesPerProfession]
-- Assumes 2 primary professions x R recipes + Cooking x 60 per member, ~24-char names.
local MEMBERS, R = tonumber(arg[1] or 100), tonumber(arg[2] or 120)
local profs = { "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Leatherworking", "Tailoring" }
local cats = { "Potions", "Elixirs", "Flasks", "Armor", "Weapons", "Consumables", "Reagents" }
local function name(i) return string.format("Recipe of the Thing %04d", i) end
local members = {}
for m = 1, MEMBERS do
  local e = { guid = string.format("Player-4619-%08X", m), name = "First" .. m .. " Surname", professions = {} }
  for p = 1, 2 do
    local pn = profs[(m + p) % #profs + 1]
    local rec = {}
    for i = 1, R do rec[#rec + 1] = { key = -(p * 10000 + i), name = name(i), cat = cats[i % #cats + 1] } end
    e.professions[pn] = { skill = 300, max = 300, spec = (m % 3 == 0) and "Elixir Master" or nil, last = 1790000000 + m, recipes = rec }
  end
  local rec = {}
  for i = 1, 60 do rec[#rec + 1] = { key = 20000 + i, name = name(i), cat = "Cooking" } end
  e.professions.Cooking = { skill = 300, max = 300, last = 1790000000, recipes = rec }
  members[#members + 1] = e
end

local t0 = os.clock()
local out, rows = { "Member,Profession,Skill,Specialisation,Recipe,RecipeKey,Category,LastScanned" }, 0
for _, e in ipairs(members) do
  for pn, p in pairs(e.professions) do
    for _, r in ipairs(p.recipes) do
      rows = rows + 1
      out[#out + 1] = table.concat({ e.name, pn, p.skill, p.spec or "", r.name, r.key, r.cat, "2026-09-20" }, ",")
    end
  end
end
local csv = table.concat(out, "\n")
local tcsv = os.clock() - t0

local function q(s) return '"' .. s .. '"' end
t0 = os.clock()
local j = { '{"schema":1,"guild":"Grim","generatedAt":1790000000,"members":[' }
for mi, e in ipairs(members) do
  local ps = {}
  for pn, p in pairs(e.professions) do
    local rs = {}
    for _, r in ipairs(p.recipes) do rs[#rs + 1] = '{"key":' .. r.key .. ',"name":' .. q(r.name) .. ',"category":' .. q(r.cat) .. '}' end
    ps[#ps + 1] = '{"name":' .. q(pn) .. ',"skill":' .. p.skill .. ',"maxSkill":' .. p.max .. (p.spec and (',"specialisation":' .. q(p.spec)) or '') .. ',"lastScanned":' .. p.last .. ',"recipes":[' .. table.concat(rs, ",") .. ']}'
  end
  j[#j + 1] = (mi > 1 and "," or "") .. '{"guid":' .. q(e.guid) .. ',"name":' .. q(e.name) .. ',"professions":[' .. table.concat(ps, ",") .. ']}'
end
j[#j + 1] = "]}"
local json = table.concat(j)
local tjson = os.clock() - t0

-- Compact variant: recipe dictionary once, members reference keys only.
local dict, ckeys = {}, {}
for _, e in ipairs(members) do for _, p in pairs(e.professions) do for _, r in ipairs(p.recipes) do dict[r.key] = r end end end
local d = {}
for k, r in pairs(dict) do d[#d + 1] = '"' .. k .. '":{"name":' .. q(r.name) .. ',"category":' .. q(r.cat) .. '}' end
local cm = {}
for _, e in ipairs(members) do
  local ps = {}
  for pn, p in pairs(e.professions) do
    local ks = {}
    for _, r in ipairs(p.recipes) do ks[#ks + 1] = r.key end
    ps[#ps + 1] = '{"name":' .. q(pn) .. ',"skill":' .. p.skill .. ',"lastScanned":' .. p.last .. ',"recipes":[' .. table.concat(ks, ",") .. ']}'
  end
  cm[#cm + 1] = '{"guid":' .. q(e.guid) .. ',"name":' .. q(e.name) .. ',"professions":[' .. table.concat(ps, ",") .. ']}'
end
local compact = '{"schema":1,"recipes":{' .. table.concat(d, ",") .. '},"members":[' .. table.concat(cm, ",") .. ']}'

-- SavedVariables serialisation of the compact shape, roughly as WoW writes it (tabs, ["k"] = v,).
local svlen = 0
for _, e in ipairs(members) do
  svlen = svlen + 60
  for _, p in pairs(e.professions) do svlen = svlen + 120 + #p.recipes * 10 end
end
for _, r in pairs(dict) do svlen = svlen + 30 + #r.name + #r.cat + 30 end

print(string.format("members=%d rows=%d", MEMBERS, rows))
print(string.format("CSV          %8.0f KB  (build %.0f ms, desktop Lua)", #csv / 1024, tcsv * 1000))
print(string.format("JSON verbose %8.0f KB  (build %.0f ms)", #json / 1024, tjson * 1000))
print(string.format("JSON compact %8.0f KB  (recipe dictionary + key lists)", #compact / 1024))
print(string.format("SV compact   %8.0f KB  (estimate)", svlen / 1024))
