import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const database = resolve(root, "database");
const sources = resolve(database, "source-data");
const sourceDefinitions = [
  ["digimon_story_ds", "digimon-story-ds.json", 201],
  ["dawn_dusk", "dawn-dusk.json", 513],
  ["lost_evolution", "lost-evolution.json", 546],
  ["super_xros_wars", "super-xros-wars.json", 1000],
];
const sourceUrls = {
  digimon_story_ds: "https://w.atwiki.jp/digimonstory/pages/57.html",
  dawn_dusk: "https://strategywiki.org/wiki/Digimon_World:_Dawn_and_Dusk/Techniques",
  lost_evolution: "https://gamefaqs.gamespot.com/ds/980253-digimon-story-lost-evolution/faqs/78408/attacks",
  super_xros_wars: "https://wikimon.net/Digimon_Story:_Super_Xros_Wars_Guide/Technique",
};
const digiXrosSourceUrl = "https://wikimon.net/SXW_DigiXros_Technique";
const existingIdByName = new Map([
  ["pepper breath", "pepper_breath"], ["blue blaster", "blue_blaster"],
  ["mega flame", "mega_flame"], ["bubbles", "bubbles"],
  ["adhesive bubble", "adhesive_bubble"], ["vee headbutt", "vee_headbutt"],
  ["guard charge", "guard_charge"], ["speed charge", "speed_charge"],
]);
const rankLevels = {
  fresh: [3], "in-training": [5], rookie: [8, 16], champion: [10, 20],
  ultimate: [12, 24], mega: [15, 30], ultra: [15, 30],
};
const elements = new Set(["neutral", "fire", "plant", "water", "electric", "wind", "earth", "light", "dark"]);
const legacyActionDefaults = [
  ["pepper_breath", "Pepper Breath", "damage", "physical", "fire", 39, 11, 34, "cone", "damage", ""],
  ["blue_blaster", "Blue Blaster", "damage", "special", "fire", 39, 11, 34, "line", "damage", ""],
  ["mega_flame", "Mega Flame", "damage", "physical", "fire", 50, 17, 48, "diamond", "damage", ""],
  ["bubbles", "Bubbles", "damage", "special", "water", 26, 8, 24, "cross", "damage", ""],
  ["adhesive_bubble", "Adhesive Bubble", "damage", "special", "plant", 31, 12, 34, "single", "damage", "speed_down"],
  ["vee_headbutt", "Vee Headbutt", "damage", "physical", "neutral", 46, 8, 34, "single", "damage", ""],
  ["guard_charge", "Guard Charge", "support", "none", "neutral", 0, 6, 28, "self", "status", "def_up"],
  ["speed_charge", "Speed Charge", "support", "none", "neutral", 0, 6, 26, "self", "status", "speed_up"],
].map(([id, name, category, damageClass, element, power, spCost, recoveryCost, shape, effectType, status]) => ({
  id, name, category, damageClass, element, power, accuracy: shape === "diamond" ? 95 : 100, spCost, recoveryCost,
  selection: ["self", "single"].includes(shape) ? "unit" : shape === "line" || shape === "cone" ? "direction" : "tile",
  range: { shape: shape === "self" ? "self" : shape === "single" ? "adjacent_8" : shape === "line" ? "line" : "diamond", min: shape === "self" ? 0 : 1, max: shape === "self" ? 0 : shape === "single" ? 1 : 4, requiresLineOfSight: false },
  area: { shape, radius: ["diamond", "cross"].includes(shape) ? 1 : 0, ...(["line", "cone"].includes(shape) ? { length: 4 } : {}) },
  targets: shape === "self" ? ["self"] : ["enemy"], canCrit: category === "damage",
  effects: effectType === "damage" ? [{ type: "damage" }, ...(status ? [{ type: "status", status, chance: 25, duration: 2 }] : [])] : [{ type: "status", status, chance: 100, duration: 3 }],
}));

const load = async (path) => JSON.parse(await readFile(path, "utf8"));
const normalize = (value) => String(value ?? "").normalize("NFKC").trim().replace(/\s+/g, " ").toLowerCase();
const hash = (value) => createHash("sha1").update(value).digest("hex").slice(0, 8);
const csv = (value) => `"${String(value ?? "").replaceAll('"', '""')}"`;
const title = (value) => String(value).replace(/\b\w/g, (letter) => letter.toUpperCase());
const slug = (value) => normalize(value).normalize("NFKD").replace(/[\u0300-\u036f]/g, "")
  .replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
const semanticEnglishKey = (value) => normalize(value).replace(/^(mega|giga) gain (attack|guard|speed)$/, "gain $2");

const kana = {
  あ:"a",い:"i",う:"u",え:"e",お:"o",か:"ka",き:"ki",く:"ku",け:"ke",こ:"ko",
  さ:"sa",し:"shi",す:"su",せ:"se",そ:"so",た:"ta",ち:"chi",つ:"tsu",て:"te",と:"to",
  な:"na",に:"ni",ぬ:"nu",ね:"ne",の:"no",は:"ha",ひ:"hi",ふ:"fu",へ:"he",ほ:"ho",
  ま:"ma",み:"mi",む:"mu",め:"me",も:"mo",や:"ya",ゆ:"yu",よ:"yo",
  ら:"ra",り:"ri",る:"ru",れ:"re",ろ:"ro",わ:"wa",を:"o",ん:"n",
  が:"ga",ぎ:"gi",ぐ:"gu",げ:"ge",ご:"go",ざ:"za",じ:"ji",ず:"zu",ぜ:"ze",ぞ:"zo",
  だ:"da",ぢ:"ji",づ:"zu",で:"de",ど:"do",ば:"ba",び:"bi",ぶ:"bu",べ:"be",ぼ:"bo",
  ぱ:"pa",ぴ:"pi",ぷ:"pu",ぺ:"pe",ぽ:"po",ゔ:"vu",ゕ:"ka",ゖ:"ke",
};
const kanaPairs = {
  きゃ:"kya",きゅ:"kyu",きょ:"kyo",ぎゃ:"gya",ぎゅ:"gyu",ぎょ:"gyo",
  しゃ:"sha",しゅ:"shu",しょ:"sho",じゃ:"ja",じゅ:"ju",じょ:"jo",
  ちゃ:"cha",ちゅ:"chu",ちょ:"cho",にゃ:"nya",にゅ:"nyu",にょ:"nyo",
  ひゃ:"hya",ひゅ:"hyu",ひょ:"hyo",びゃ:"bya",びゅ:"byu",びょ:"byo",ぴゃ:"pya",ぴゅ:"pyu",ぴょ:"pyo",
  みゃ:"mya",みゅ:"myu",みょ:"myo",りゃ:"rya",りゅ:"ryu",りょ:"ryo",
  ふぁ:"fa",ふぃ:"fi",ふぇ:"fe",ふぉ:"fo",ふゅ:"fyu",ゔぁ:"va",ゔぃ:"vi",ゔぇ:"ve",ゔぉ:"vo",
  しぇ:"she",じぇ:"je",ちぇ:"che",てぃ:"ti",でぃ:"di",とぅ:"tu",どぅ:"du",
  つぁ:"tsa",つぃ:"tsi",つぇ:"tse",つぉ:"tso",うぃ:"wi",うぇ:"we",うぉ:"wo",
};

function romanizeJapanese(value) {
  const input = String(value ?? "").normalize("NFKC").replace(/∞/g, " Infinity ").replace(/[ァ-ヶ]/g, (character) => String.fromCharCode(character.charCodeAt(0) - 0x60));
  let result = "";
  let doubleNext = false;
  for (let index = 0; index < input.length; index++) {
    const character = input[index];
    if (character === "っ") { doubleNext = true; continue; }
    if (character === "ー") {
      const vowel = result.match(/[aeiou](?!.*[aeiou])/i)?.[0] ?? "";
      result += vowel;
      continue;
    }
    const pair = input.slice(index, index + 2);
    let syllable = kanaPairs[pair];
    if (syllable) index++;
    else syllable = kana[character] ?? (/^[A-Za-z0-9]$/.test(character) ? character : " ");
    if (doubleNext && /^[bcdfghjklmnpqrstvwxyz]/i.test(syllable)) syllable = syllable[0] + syllable;
    doubleNext = false;
    result += syllable;
  }
  return title(result.replace(/([a-z])([A-Z0-9])/g, "$1 $2").replace(/([0-9])([A-Za-z])/g, "$1 $2").replace(/\s+/g, " ").trim());
}

function auditSourceData(record) {
  const allowed = ["name", "japanese", "level", "mp", "effectValue", "attribute", "hits", "section", "range", "fields", "url"];
  return Object.fromEntries(allowed.filter((key) => record[key] !== undefined).map((key) => [key, structuredClone(record[key])]));
}

function parseLostEvolution(pages) {
  const rows = [];
  for (const page of pages) {
    const lines = page.body.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);
    for (let index = 0; index < lines.length; index++) {
      if (!lines[index].startsWith("Learned by:")) continue;
      let nameIndex = index - 1;
      while (nameIndex >= 0 && index - nameIndex < 12 && !(lines[nameIndex].includes(" (") && lines[nameIndex].endsWith(")"))) nameIndex--;
      if (nameIndex < 0) continue;
      const nameLine = lines[nameIndex];
      const japaneseStart = nameLine.lastIndexOf(" (");
      if (japaneseStart <= 0) throw new Error(`Lost Evolution name could not be parsed: ${nameLine}`);
      const english = nameLine.slice(0, japaneseStart).trim();
      const japanese = nameLine.slice(japaneseStart + 2, -1).trim();
      const fields = {};
      for (let fieldIndex = nameIndex + 1; fieldIndex < index; fieldIndex++) {
        const split = lines[fieldIndex].indexOf(":");
        if (split > 0) fields[lines[fieldIndex].slice(0, split)] = lines[fieldIndex].slice(split + 1).trim();
      }
      rows.push({
        name: english, japanese, fields,
        learnedBy: lines[index].slice("Learned by:".length).split(",").map((name) => name.trim()).filter(Boolean),
        url: page.url,
      });
    }
  }
  return rows;
}

function inferElement(record) {
  const page = String(record.url ?? "");
  const attribute = normalize(record.attribute);
  const text = normalize(`${record.name} ${record.japanese} ${record.description} ${record.information}`);
  if (page.includes("dark-attacks") || attribute === "dark" || /dark|shadow|night|curse|やみ|闇/.test(text)) return "dark";
  if (page.includes("earth-attacks") || attribute === "earth" || /earth|rock|sand|gaia|土|岩/.test(text)) return "earth";
  if (page.includes("fire-attacks") || attribute === "fire" || /fire|flame|burn|heat|ホノオ|炎|火/.test(text)) return "fire";
  if (page.includes("holy-attacks") || attribute === "light" || /holy|light|photon|shine|光/.test(text)) return "light";
  if (page.includes("thunder-attacks") || attribute === "thunder" || /thunder|electric|lightning|spark|デンキ|雷/.test(text)) return "electric";
  if (page.includes("water-attacks") || attribute === "water" || /water|aqua|bubble|ice|水|アワ/.test(text)) return "water";
  if (attribute === "wind" || /wind|air|storm|sonic|風/.test(text)) return "wind";
  if (attribute === "nature" || /plant|leaf|flower|seed|vine|wood|草|花/.test(text)) return "plant";
  return "neutral";
}

function inferCategory(record) {
  const page = String(record.url ?? "");
  const text = normalize(`${record.name} ${record.description} ${record.information} ${record.effect}`);
  if (page.includes("healing-moves") || /heal|restore.*hp|recover.*hp|かいふく|回復/.test(text)) return "healing";
  if (page.includes("support-moves") || /raise|increase|decrease|down|up|barrier|guard|status|buff|debuff/.test(text)) return "support";
  if (/push|pull|dash|teleport|swap/.test(text)) return "mobility";
  if (/sleep|stun|paraly|poison|confus|blind|doom|death/.test(text) && !record.power) return "control";
  return "damage";
}

function tacticalShape(record) {
  const alignment = String(record.fields?.Alignment ?? record.alignment ?? "");
  const text = normalize(`${record.description} ${record.information} ${record.range}`);
  if (/all|5 zones|map|すべて|ぜんたい/.test(text) || alignment === "OOOOO") return ["diamond", 2, 5];
  if (/around|surround|まわり/.test(text) || alignment === "OOXOO") return ["diamond", 1, 3];
  if (/line|pierc/.test(text) || ["XOXOX", "OXOXO"].includes(alignment)) return ["line", 0, 4];
  if (/cone|breath/.test(text) || alignment === "XXOOX") return ["cone", 0, 4];
  if (alignment && alignment !== "XXOXX") return ["cross", 1, 4];
  return ["single", 0, 3];
}

function statusFrom(record) {
  const text = normalize(`${record.effect} ${record.fields?.["Stat Modification"]} ${record.description} ${record.information}`);
  if (/melody|conversion|メロディ/.test(text)) return "data_mark";
  for (const [pattern, status] of [
    [/(poison|ポイズン)/, "poison"], [/(burn|やけど)/, "burn"], [/(paraly|まひ)/, "paralysis"], [/(sleep|ねむり)/, "sleep"],
    [/(confus|こんらん)/, "confusion"], [/(blind|accuracy down|miss|めいちゅうをさげる|命中)/, "blind"], [/(stun|スタン)/, "stun"], [/(death|instant death|そくし)/, "doom"],
    [/(counter|カウンター)/, "counter"], [/(reflect|はんしゃ|反射)/, "reflect"],
    [/(attack down|atk down|ちからをさげる)/, "atk_down"], [/(defense down|def down|まもりをさげる)/, "def_down"],
    [/(intelligence down|int down|かしこさをさげる)/, "int_down"], [/(speed down|spd down|すばやさをさげる)/, "speed_down"],
    [/(attack up|atk up|ちからをあげる)/, "atk_up"], [/(defense up|def up|まもりをあげる)/, "def_up"],
    [/(intelligence up|int up|かしこさをあげる)/, "int_up"], [/(speed up|spd up|すばやさをあげる)/, "speed_up"],
  ]) if (pattern.test(text)) return status;
  return "";
}

function runtimeAction(canonical) {
  const source = canonical.best;
  const category = inferCategory(source);
  const element = inferElement(source);
  const [shape, radius, maxRange] = tacticalShape(source);
  const sourcePower = Number.parseInt(source.power ?? source.fields?.Power ?? source.effectValue ?? "", 10);
  let band = Number.isFinite(sourcePower) ? (sourcePower <= 20 ? 0 : sourcePower <= 50 ? 1 : sourcePower <= 80 ? 2 : 3) : 1;
  const bands = [[32, 4, 24, 100], [46, 8, 34, 100], [62, 13, 48, 95], [80, 22, 70, 90]];
  let [power, spCost, recoveryCost, accuracy] = bands[band];
  if (["line", "cone"].includes(shape)) { power = Math.round(power * .85); spCost += 3; }
  if (["cross", "diamond"].includes(shape)) { power = Math.round(power * (radius >= 2 ? .65 : .8)); spCost += radius >= 2 ? 8 : 4; recoveryCost += radius >= 2 ? 12 : 0; }
  const status = statusFrom(source);
  if (category === "damage" && status) { power = Math.max(1, power - 15); spCost += 4; }
  if (category === "healing") {
    power = shape === "single" ? 30 : 18;
    spCost = shape === "single" ? 10 : 14;
    recoveryCost = shape === "single" ? 38 : 50;
  }
  else if (["support", "mobility"].includes(category)) {
    power = 0; spCost = shape === "single" || shape === "self" ? 6 : 10; recoveryCost = shape === "single" || shape === "self" ? 28 : 40;
  }
  if (category !== "damage") accuracy = 100;
  const effects = [];
  const effectText = normalize(`${source.effect} ${source.fields?.Effect} ${source.description} ${source.information}`);
  if (/revive/.test(effectText)) {
    effects.push({ type: "revive", percentMaxHp: 25 });
    spCost = 20; recoveryCost = 70;
  }
  else if (category === "healing") effects.push({ type: "heal", percentMaxHp: power });
  else if (category === "damage" || category === "control") {
    const hits = Math.max(1, Number.parseInt(source.hits ?? "1", 10) || 1);
    effects.push({ type: "damage", ...(hits > 1 ? { hits } : {}) });
  }
  if (status) effects.push({ type: "status", status, chance: category === "damage" ? 25 : 40, duration: status === "doom" ? 3 : 3 });
  if (/hp drain/.test(effectText)) effects.push({ type: "drain_hp", percentOfDamage: 35 });
  if (/mp drain|sp drain/.test(effectText)) effects.push({ type: "drain_sp", amount: 6 });
  if (/push|knockback/.test(effectText)) effects.push({ type: "push", distance: 1 });
  if (/pull/.test(effectText)) effects.push({ type: "pull", distance: 1 });
  if (!effects.length) effects.push({ type: "status", status: "guard", chance: 100, duration: 3 });
  const powerfulUtility = radius > 0 || Boolean(status);
  const masteryProfile = category === "healing" && !powerfulUtility ? "potent"
    : category === "damage" && !powerfulUtility && band >= 2 ? "potent"
      : accuracy < 100 ? "precise" : spCost >= 13 ? "efficient" : status ? "reliable_effect" : "swift";
  const tags = [element, category === "healing" ? "healing" : source.name?.toLowerCase().includes("breath") ? "breath" : shape === "single" ? "melee" : "projectile"];
  const role = category === "damage" ? (shape === "single" ? "striker" : "area_damage") : category;
  return {
    id: canonical.id,
    names: { en: canonical.english, pt_BR: canonical.portuguese, ...(canonical.japanese ? { ja: canonical.japanese } : {}) },
    name: canonical.english,
    descriptions: {
      en: category === "healing" ? `Restores HP with a ${element} technique.` : `Uses ${canonical.english} as a ${role.replaceAll("_", " ")} technique.`,
      pt_BR: category === "healing" ? `Restaura HP com uma técnica de ${element}.` : `Usa ${canonical.portuguese} como técnica de ${role.replaceAll("_", " ")}.`,
    },
    aliases: [...canonical.aliases].sort(), sourceGames: [...canonical.games].sort(),
    category, damageClass: category === "damage" ? (tags.includes("melee") ? "physical" : "special") : "none",
    element, power, accuracy, spCost, recoveryCost, selection: shape === "single" ? "unit" : (["line", "cone"].includes(shape) ? "direction" : "tile"),
    range: { shape: maxRange === 1 ? "adjacent_8" : "diamond", min: category === "support" || category === "healing" ? 0 : 1, max: maxRange, requiresLineOfSight: false },
    area: { shape, radius, ...(shape === "line" || shape === "cone" ? { length: maxRange } : {}) },
    targets: category === "healing" || category === "support" ? ["self", "ally"] : ["enemy"],
    canCrit: category === "damage", effects, tacticalRole: role, tags, masteryProfile,
    availability: canonical.requiresMechanic ? "requires_digixros" : "ready",
    sourceMetadata: canonical.sourceMetadata,
  };
}

function selectBestCanonical(pool, species, used, offset = 0) {
  const speciesName = normalize(species.name).replace(/\s*\([^)]*\)\s*/g, "");
  const learnedMatches = pool.filter((entry) => entry.learnedBy?.some((name) => normalize(name).replace(/\s*\([^)]*\)\s*/g, "") === speciesName));
  for (const candidates of [learnedMatches, pool]) {
    if (!candidates.length) continue;
    for (let step = 0; step < candidates.length; step++) {
      const candidate = candidates[(Math.abs(hash(`${species.seed}:${offset}`).split("").reduce((a, c) => a + c.charCodeAt(0), 0)) + step) % candidates.length];
      if (!used.has(candidate.canonicalId) && candidate.availability === "ready") return candidate.canonicalId;
    }
  }
  throw new Error(`No technique candidate for ${species.name}`);
}

async function main() {
  const existingActions = legacyActionDefaults.map((action) => structuredClone(action));
  const species = await load(resolve(database, "base-digimon-list.json"));
  const sourcePayloads = new Map();
  for (const [game, file] of sourceDefinitions) sourcePayloads.set(game, await load(resolve(sources, file)));
  const digiXrosRows = await load(resolve(sources, "super-xros-wars-digixros.json"));
  const digiXrosNames = new Set(digiXrosRows.map((record) => normalize(record.japanese)));
  const leRows = parseLostEvolution(sourcePayloads.get("lost_evolution"));
  if (leRows.length !== 546) throw new Error(`Expected 546 Lost Evolution rows, found ${leRows.length}`);
  const ddRaw = sourcePayloads.get("dawn_dusk");
  let ddSection = "normal";
  const ddRows = ddRaw.flatMap((cells) => {
    if (cells[0] === "Name") { if (ddSection === "normal" && ddRaw.indexOf(cells) > 0) ddSection = "special"; return []; }
    return [{ name: cells[0], level: cells[1], mp: cells[3], effectValue: cells[4], attribute: cells[5], description: cells[6], hits: cells[7], details: cells[8], section: ddSection }];
  });
  const dsRows = sourcePayloads.get("digimon_story_ds").filter((cells) => cells[0] !== "技名")
    .map((cells) => ({ japanese: cells[0], range: cells[1], mp: cells[2], effectValue: cells[3], notes: cells[4] }));
  const sxwRows = sourcePayloads.get("super_xros_wars").slice(1)
    .map((cells) => ({ japanese: cells[1], information: cells[2] }));
  if (ddRows.length !== 513 || dsRows.length !== 201 || sxwRows.length !== 1000) throw new Error("Source row counts changed");

  const canonicalByKey = new Map();
  const canonicals = new Map();
  const audit = [];
  let sequence = 0;
  function register(game, sourceIndex, record, english, japanese = "", forceDecision = "") {
    sequence++;
    const dummy = game === "super_xros_wars" && /ダミー/.test(record.information ?? "");
    if (dummy) {
      audit.push({ sourceGame: game, sourceUrl: sourceUrls[game], sourceIndex, sourceName: japanese, sourceData: auditSourceData(record), decision: "dummy_excluded", canonicalId: null });
      return null;
    }
    const englishKey = english ? `en:${semanticEnglishKey(english)}` : "";
    const japaneseKey = japanese ? `ja:${normalize(japanese)}` : "";
    let canonical = (englishKey && canonicalByKey.get(englishKey)) || (japaneseKey && canonicalByKey.get(japaneseKey));
    const isAlias = Boolean(canonical);
    if (!canonical) {
      const localizedEnglish = english || romanizeJapanese(japanese);
      const base = existingIdByName.get(normalize(localizedEnglish)) || slug(localizedEnglish) || `${game}_technique_${String(sourceIndex).padStart(4, "0")}`;
      let id = base;
      if (canonicals.has(id)) id = `${base}_${hash(`${game}:${sourceIndex}:${japanese}`)}`;
      canonical = {
        id, english: localizedEnglish || `Technique ${game.replaceAll("_", " ")} ${String(sourceIndex).padStart(4, "0")}`,
        portuguese: localizedEnglish || `Técnica ${game.replaceAll("_", " ")} ${String(sourceIndex).padStart(4, "0")}`,
        japanese, aliases: new Set(), games: new Set(), best: record, requiresMechanic: false, sourceMetadata: [],
      };
      canonicals.set(id, canonical);
    }
    if (english && normalize(english) !== normalize(canonical.english)) canonical.aliases.add(english);
    if (japanese) canonical.aliases.add(japanese);
    canonical.games.add(game);
    canonical.sourceMetadata.push({ game, sourceIndex });
    if (!canonical.japanese && japanese) canonical.japanese = japanese;
    if (!canonicalByKey.has(englishKey) && englishKey) canonicalByKey.set(englishKey, canonical);
    if (!canonicalByKey.has(japaneseKey) && japaneseKey) canonicalByKey.set(japaneseKey, canonical);
    if (game === "lost_evolution") canonical.best = record;
    const xrosRequired = game === "super_xros_wars" && (
      digiXrosNames.has(normalize(japanese))
      || /(デジクロス|クロスの力|合体)/.test(record.information ?? "")
    );
    canonical.requiresMechanic ||= xrosRequired;
    const decision = forceDecision || (xrosRequired ? "requires_mechanic" : isAlias ? "alias" : "mapped");
    audit.push({ sourceGame: game, sourceUrl: sourceUrls[game], sourceIndex, sourceName: english || japanese, sourceData: auditSourceData(record), decision, canonicalId: canonical.id, ...(xrosRequired ? { mechanicSourceUrl: digiXrosSourceUrl } : {}) });
    record.canonicalId = canonical.id;
    return canonical;
  }

  leRows.forEach((record, index) => register("lost_evolution", index + 1, record, record.name, record.japanese));
  ddRows.forEach((record, index) => register("dawn_dusk", index + 1, record, record.name));
  dsRows.forEach((record, index) => {
    const known = canonicalByKey.get(`ja:${normalize(record.japanese)}`);
    register("digimon_story_ds", index + 1, record, known?.english ?? "", record.japanese);
  });
  sxwRows.forEach((record, index) => {
    const known = canonicalByKey.get(`ja:${normalize(record.japanese)}`);
    register("super_xros_wars", index + 1, record, known?.english ?? "", record.japanese);
  });
  if (audit.length !== 2260) throw new Error(`Expected 2260 audit rows, found ${audit.length}`);
  const dummyCount = audit.filter((row) => row.decision === "dummy_excluded").length;
  if (dummyCount !== 54) throw new Error(`Expected exactly 54 dummy rows, found ${dummyCount}`);

  for (const existing of existingActions) {
    if ([...canonicals.values()].some((canonical) => canonical.id === existing.id)) continue;
    canonicals.set(`legacy:${existing.id}`, {
      id: existing.id, english: existing.name, portuguese: existing.name, japanese: "",
      aliases: new Set(), games: new Set(["digigame_legacy"]), best: existing,
      requiresMechanic: false, sourceMetadata: [{ game: "digigame_legacy", sourceIndex: 0 }],
    });
  }

  const generated = [...canonicals.values()].map(runtimeAction);
  const generatedById = new Map(generated.map((action) => [action.id, action]));
  for (const existing of existingActions) {
    const action = generatedById.get(existing.id);
    if (!action) continue;
    const identity = { names: action.names, descriptions: action.descriptions, aliases: action.aliases, sourceGames: action.sourceGames, sourceMetadata: action.sourceMetadata };
    Object.assign(action, existing, identity, { masteryProfile: action.masteryProfile, availability: action.availability, tacticalRole: action.tacticalRole, tags: action.tags });
  }
  const readyPool = [];
  for (const row of leRows) {
    const action = generatedById.get(row.canonicalId);
    if (action) readyPool.push({ ...row, availability: action.availability });
  }
  for (const canonical of canonicals.values()) {
    const action = generatedById.get(canonical.id);
    if (action && action.availability === "ready" && !readyPool.some((row) => row.canonicalId === canonical.id)) readyPool.push({ canonicalId: canonical.id, availability: "ready" });
  }

  const signatureIds = new Set();
  const signatureOverrides = new Map([
    ["agumon", "pepper_breath"], ["gabumon", "blue_blaster"], ["greymon", "mega_flame"],
    ["koromon", "bubbles"], ["tanemon", "adhesive_bubble"], ["veemon", "vee_headbutt"],
  ]);
  const inheritedOverrides = new Map([
    ["agumon", ["guard_charge"]], ["gabumon", ["speed_charge"]],
    ["greymon", ["guard_charge"]], ["veemon", ["speed_charge"]],
  ]);
  const learnsets = species.map((entry) => {
    const used = new Set();
    const signatureOverride = signatureOverrides.get(normalize(entry.name));
    const signature = signatureOverride && generatedById.has(signatureOverride) ? signatureOverride : selectBestCanonical(readyPool, entry, used, 0);
    used.add(signature); signatureIds.add(signature);
    const levels = rankLevels[normalize(entry.rank)] ?? [8, 16];
    const skills = [{ skill: signature, level: 1, acquisition: "signature" }];
    levels.forEach((level, index) => {
      const override = inheritedOverrides.get(normalize(entry.name))?.[index];
      const skill = override && generatedById.has(override) && !used.has(override) ? override : selectBestCanonical(readyPool, entry, used, index + 1);
      used.add(skill);
      skills.push({ skill, level, acquisition: "level" });
    });
    return { speciesSeed: entry.seed, species: entry.name, rank: entry.rank, skills };
  });

  const rarityCost = { common: 300, uncommon: 900, rare: 2500, legendary: 6000 };
  const records = generated.map((action) => {
    const rarity = action.spCost <= 8 ? "common" : action.spCost <= 13 ? "uncommon" : action.spCost <= 21 ? "rare" : "legendary";
    const teachable = action.availability === "ready" && !signatureIds.has(action.id);
    action.teachable = teachable;
    action.recordLevel = rarity;
    return {
      skill: action.id, teachable, recordLevel: rarity, bitsCost: rarityCost[rarity],
      unlockSources: teachable ? (rarity === "common" ? ["research", "story", "mission", "exploration", "chest", "npc"] : ["story", "mission", "exploration", "chest", "boss", "npc"]) : [],
      allOf: [], anyOf: action.tags.filter((tag) => ["fire", "plant", "water", "electric", "wind", "earth", "light", "dark", "melee", "projectile", "breath", "healing"].includes(tag)),
      allowSpeciesSeeds: [], denySpeciesSeeds: [],
    };
  });

  const matrixHeader = ["id", "name_en", "name_pt_BR", "name_ja", "aliases", "source_games", "role", "element", "range", "area", "power", "accuracy", "sp", "recovery", "effects", "mastery", "tags", "teachable", "availability"];
  const matrixRows = generated.map((action) => [
    action.id, action.names.en, action.names.pt_BR, action.names.ja ?? "", action.aliases.join(" | "), action.sourceGames.join(" | "),
    action.tacticalRole, action.element, JSON.stringify(action.range), JSON.stringify(action.area), action.power, action.accuracy,
    action.spCost, action.recoveryCost, JSON.stringify(action.effects), action.masteryProfile, action.tags.join(" | "), action.teachable, action.availability,
  ]);
  await Promise.all([
    writeFile(resolve(database, "techniques.json"), JSON.stringify(generated, null, 2) + "\n"),
    writeFile(resolve(database, "technique-source-audit.json"), JSON.stringify(audit, null, 2) + "\n"),
    writeFile(resolve(database, "digimon-learnsets.json"), JSON.stringify(learnsets, null, 2) + "\n"),
    writeFile(resolve(database, "technique-records.json"), JSON.stringify(records, null, 2) + "\n"),
    writeFile(resolve(database, "technique-matrix.csv"), [matrixHeader, ...matrixRows].map((row) => row.map(csv).join(",")).join("\n") + "\n"),
  ]);
  console.log(`Built ${generated.length} canonical techniques, ${audit.length} audit rows (${dummyCount} dummy), ${learnsets.length} learnsets, and ${records.length} records.`);
}

await main();
