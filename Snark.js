.pragma library

// Statusphere's personality. Lines are grouped by weather category and tagged
// by tone. Snarky is the default: mostly friendly, occasionally rude, and
// profane when the moment calls for it.
//
// Rules for new lines:
// - Keep the joke about the weather, not the reader's identity or body.
// - No slurs, no medical advice, no telling anyone to go out in dangerous
//   weather. A storm line can swear and still say "stay inside".
// - Profane lines are seasoning, not the whole meal.

var PACKS = {
  clear: {
    nice: [
      "Perfect weather. Go outside and pretend you have your life together.",
      "The sky is showing off today. You should probably join it.",
      "Clear skies. A rare invitation to leave the house.",
      "Sunshine. Your vitamin D called; it's been waiting."
    ],
    rude: [
      "Perfect weather. Don't waste it scrolling in here.",
      "Clear skies. Yes, outside exists. Shocking, I know.",
      "Gorgeous out. Your excuses are getting weaker.",
      "The sun is out. You have no excuse now."
    ],
    profane: [
      "Gorgeous out. Get off your ass and go outside.",
      "Clear skies. Stop fucking around and enjoy it.",
      "Sunshine. Close the damn laptop and touch grass.",
      "Perfect weather. Don't fuck this up."
    ]
  },
  cloudy: {
    nice: [
      "Soft grey skies. A good day for a slow one.",
      "Overcast. The sun is taking a personal day.",
      "Cloudy but calm. Take the win.",
      "The sky is quilted today. Cozy enough."
    ],
    rude: [
      "Overcast. The sky is doing its best impression of your motivation.",
      "Grey skies. At least they have an excuse.",
      "Cloudy. The sun has left the chat.",
      "Dull skies. Try not to match them."
    ],
    profane: [
      "Grey and miserable. At least the sky has a fucking excuse.",
      "Overcast as hell. The sun ghosted us.",
      "Cloudy. The sky looks how Monday feels.",
      "Gloomy. Don't let the sky win."
    ]
  },
  rain: {
    nice: [
      "Rainy day. Perfect excuse to stay in and be cozy.",
      "Rain. The garden is thrilled, even if you aren't.",
      "A little rain never hurt anyone. Bring a jacket.",
      "Wet outside. Tea and window-gazing weather."
    ],
    rude: [
      "It's raining. Your umbrella is at home, obviously.",
      "Rain. Your hair had plans, apparently.",
      "Wet outside. Yes, you still have to go to work.",
      "Rainy. The sky is crying; you're just late."
    ],
    profane: [
      "It's pissing it down. Your umbrella is at home, obviously.",
      "Raining like hell. Your shoes are about to have a bad time.",
      "Wet as fuck. The sky picked today to fall apart.",
      "Rain. The sky is shitting on your commute."
    ]
  },
  snow: {
    nice: [
      "Snow. Everything is quiet and a little magical.",
      "Snow day energy. Dress warm and enjoy it.",
      "Fresh snow. The world looks like a postcard.",
      "Snowing. Go make a snowball, you kid."
    ],
    rude: [
      "Snow. The sky has dandruff and you have to walk in it.",
      "Snowing. Your commute is now a group project.",
      "Snow. Everything is cold, white, and inconvenient.",
      "Snow day. The buses have other plans."
    ],
    profane: [
      "Snow. The sky is shitting dandruff. Wear boots.",
      "Snowing like hell. Your commute is fucked.",
      "Snow. Beautiful until you have to fucking drive in it.",
      "Cold white bullshit everywhere. At least it's pretty."
    ]
  },
  storm: {
    nice: [
      "Thunderstorms. Stay cozy inside and let the sky do its thing.",
      "A proper storm. Nature is putting on a show.",
      "Thunder and lightning. Unplug the fancy stuff and enjoy the drama.",
      "Stormy. A good night to stay in and listen."
    ],
    rude: [
      "Thunderstorms. Stay inside, genius. This one's actually dangerous.",
      "Storm. The sky is throwing a tantrum. Don't join it.",
      "Thunderstorms. Your umbrella is useless and you know it.",
      "Stormy. Nature is angry; stay out of its way."
    ],
    profane: [
      "Thunderstorms. Stay the fuck inside. This one's actually dangerous.",
      "Storm as hell. The sky is pissed and you should not test it.",
      "Thunderstorms. Your plans are cancelled. Nature said so.",
      "Stormy. Get inside before the sky fucking smites you."
    ]
  },
  fog: {
    nice: [
      "Fog. The world is soft and mysterious today.",
      "Misty. Take it slow and enjoy the quiet.",
      "Foggy. A good day for a thoughtful walk.",
      "Fog. The horizon is playing hide and seek."
    ],
    rude: [
      "Fog. Visibility is low, much like your chances of being on time.",
      "Foggy. The world has been muted for your protection.",
      "Fog. Yes, you still need to use your headlights.",
      "Misty. Your GPS is guessing now."
    ],
    profane: [
      "Fog so thick you couldn't find your own ass. Drive slower.",
      "Foggy as fuck. Turn your damn lights on.",
      "Fog. The world is ghosting you literally.",
      "Thick fog. Slow the fuck down before you become a statistic."
    ]
  },
  wind: {
    nice: [
      "Breezy. A good day to let the wind do the dramatic hair thing.",
      "Windy. Hold onto your hat and enjoy the fresh air.",
      "A blustery day. The trees are having fun.",
      "Windy. Nature's free exfoliation."
    ],
    rude: [
      "Windy. Your umbrella is now a kite.",
      "Windy enough to ruin your hair and your dignity.",
      "Gusty. Yes, your recycling bin is on tour.",
      "Windy. The sky is pushing you around today."
    ],
    profane: [
      "Windy as hell. Your umbrella is now a kite and your hair is fucked.",
      "Gusty as fuck. Hold onto your shit.",
      "Wind. The sky is having a tantrum and your bins are the victims.",
      "Blowing a gale. Don't bother with the fucking umbrella."
    ]
  },
  hot: {
    nice: [
      "It's warm out. Find some shade and enjoy it.",
      "Hot day. Cold drinks and slow plans.",
      "Sun's out. Remember to drink some water.",
      "Warm one today. A good excuse for ice cream."
    ],
    rude: [
      "It's hot. You're going to complain about it either way.",
      "Hot day. Yes, you need water. No, iced coffee doesn't count.",
      "It's warm. The sun is winning; dress accordingly.",
      "Hot. Your black clothes were a choice."
    ],
    profane: [
      "It's hot as hell. Drink some fucking water.",
      "Hot as fuck. Stop pretending you enjoy this.",
      "The sun is absolutely roasting us. Hydrate, genius.",
      "It's fucking boiling. Find shade and stop being a hero."
    ]
  },
  cold: {
    nice: [
      "Cold out. Bundle up and enjoy the crisp air.",
      "Chilly. A good day for a warm coat and a hot drink.",
      "Cold snap. The scarf is not optional.",
      "Brisk today. Dress in layers and you'll be fine."
    ],
    rude: [
      "It's freezing. Put on a coat, you absolute walnut.",
      "Cold. Yes, shorts were a bad idea. We all saw it.",
      "Freezing. The sky is not messing around today.",
      "Chilly. Your fingers will file a complaint."
    ],
    profane: [
      "It's freezing. Put a fucking coat on.",
      "Cold as fuck. Stop pretending you're built for this.",
      "Freezing. Wear a damn hat before your ears fall off.",
      "It's fucking Baltic. Layer up, you maniac."
    ]
  },
  humid: {
    nice: [
      "Humid today. Take it slow and keep some water nearby.",
      "Sticky air. A good day for a fan and a cold drink.",
      "Muggy. The air is basically a warm hug.",
      "Humid. Your hair will do whatever it wants."
    ],
    rude: [
      "90% humidity. Congratulations, you're soup.",
      "Muggy. You're not sweating; you're marinating.",
      "Humid. The air is wearing you.",
      "Sticky. Your shirt has already given up."
    ],
    profane: [
      "It's humid as fuck. You're not sweating, you're marinating.",
      "Muggy as hell. The air is fucking soup.",
      "Sticky. Your clothes are losing the will to live.",
      "Humid. Welcome to the world's shittiest sauna."
    ]
  }
}

function categoryFor(context) {
  var value = parseInt(String(context && context.code || "0"), 10) || 0
  var temp = Number(context && context.tempC)
  var humidity = Number(context && context.humidity)
  var wind = Number(context && context.windKmh)
  if (value >= 95) return "storm"
  if ((value >= 71 && value <= 77) || value === 85 || value === 86)
    return "snow"
  if ((value >= 51 && value <= 67) || (value >= 80 && value <= 82))
    return "rain"
  if (value === 45 || value === 48) return "fog"
  if (temp >= 30) return "hot"
  if (temp <= 2) return "cold"
  if (humidity >= 80 && temp >= 20) return "humid"
  if (wind >= 30) return "wind"
  if (value >= 1 && value <= 3) return "cloudy"
  return "clear"
}

function toneFor(level) {
  var roll = Math.random()
  if (level === "friendly") return "nice"
  if (level === "unhinged")
    return roll < 0.20 ? "nice" : roll < 0.60 ? "rude" : "profane"
  return roll < 0.55 ? "nice" : roll < 0.85 ? "rude" : "profane"
}

function lineFor(context, level, previous) {
  if (!context) return ""
  var pack = PACKS[categoryFor(context)] || PACKS.clear
  var tone = toneFor(level)
  var lines = pack[tone] || pack.nice || pack.rude
  if (!lines || lines.length === 0) return ""
  var index = Math.floor(Math.random() * lines.length)
  var line = lines[index]
  if (lines.length > 1 && line === previous)
    line = lines[(index + 1) % lines.length]
  return line
}

if (typeof module !== "undefined") {
  module.exports = {
    categoryFor: categoryFor,
    toneFor: toneFor,
    lineFor: lineFor
  }
}
