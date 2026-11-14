.pragma library

// Statusphere's personality. Lines are grouped by weather category and tagged
// by tone. Snarky is the default: mostly friendly, occasionally rude, and
// profane when the moment calls for it. A few dates get their own holiday
// pack, which takes over from the weather category for the day.
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
      "Sunshine. Your vitamin D called; it's been waiting.",
      "Blue sky, no notes. Make the most of it.",
      "Not a cloud in sight. A good day to be outside.",
      "Bright and clear. The park is calling.",
      "Sunny and calm. Open a window and let it in.",
      "Clear skies. Even the pigeons look pleased.",
      "Lovely out. A walk would do you good.",
      "The sun showed up on time today. Enjoy it.",
      "Crisp, bright, and easy. A rare treat.",
      "Sunshine all day. Find a bench and sit on it.",
      "Clear and kind. The sky is being nice for once."
    ],
    rude: [
      "Perfect weather. Don't waste it scrolling in here.",
      "Clear skies. Yes, outside exists. Shocking, I know.",
      "Gorgeous out. Your excuses are getting weaker.",
      "The sun is out. You have no excuse now.",
      "Sun's out. No, your screen doesn't count as outside.",
      "Clear skies. The weather app is not the activity.",
      "Beautiful day. You'll still find something to complain about.",
      "Sunshine. Your indoor plans are now officially suspicious.",
      "Not a cloud. The sky is showing off; try to keep up.",
      "Gorgeous out. Your excuses are officially expired.",
      "Clear and bright. The sun is doing its job; do yours.",
      "Blue skies. The vitamin D isn't going to absorb itself.",
      "Sunny. The window is not a substitute for the outdoors.",
      "Perfect weather. Try not to spend it in a group chat."
    ],
    profane: [
      "Gorgeous out. Get off your ass and go outside.",
      "Clear skies. Stop fucking around and enjoy it.",
      "Sunshine. Close the damn laptop and touch grass.",
      "Perfect weather. Don't fuck this up.",
      "Sun's out. Get the fuck outside.",
      "Clear skies. Stop wasting daylight, you gremlin.",
      "Beautiful day. Don't fucking blow it.",
      "Not a cloud. The sun is free and you're in here.",
      "Sunshine. Close the laptop before I do it for you.",
      "Perfect weather. Go outside and be a fucking person.",
      "Blue sky. Your excuses are shit and the day is short.",
      "Gorgeous. Get off your arse and soak it up.",
      "Clear as hell. The pub garden is waiting, you coward.",
      "Sun's beating down. Stop doomscrolling and live a little.",
      "Sun's out. Get the fuck off your phone and go outside, you absolute waster.",
      "Clear skies. You've got no fucking excuse left, so move.",
      "Perfect weather. Stop being a fucking hermit and use it.",
      "Not a cloud. The day's wasting away while you sit there like a lemon.",
      "Gorgeous out. Get out there before you fucking regret it, you melt."
    ]
  },
  cloudy: {
    nice: [
      "Soft grey skies. A good day for a slow one.",
      "Overcast. The sun is taking a personal day.",
      "Cloudy but calm. Take the win.",
      "The sky is quilted today. Cozy enough.",
      "Grey but gentle. A good day for a long walk.",
      "Cloud cover. The light is soft and the air is calm.",
      "Overcast. Nothing dramatic, nothing to worry about.",
      "A quiet grey sky. Perfect for getting things done.",
      "Cloudy. The kind of day that suits a bookstore.",
      "Soft skies. No rush today.",
      "Mild and overcast. A blanket of a day.",
      "Clouds doing their thing. Enjoy the calm.",
      "Grey outside, cozy inside. Balance achieved.",
      "Overcast. The sun is resting; you can too."
    ],
    rude: [
      "Overcast. The sky is doing its best impression of your motivation.",
      "Grey skies. At least they have an excuse.",
      "Cloudy. The sun has left the chat.",
      "Dull skies. Try not to match them.",
      "Cloudy. The sky is matching your energy again.",
      "Grey skies. At least it's not raining. Yet.",
      "Overcast. The sun called in sick.",
      "Cloudy. Not bad, not good, just beige.",
      "Dull sky. Your plans are still allowed.",
      "Grey. The weather is doing the bare minimum.",
      "Cloudy. The sun is on airplane mode.",
      "Overcast. The sky has commitment issues.",
      "Grey and flat. Try to be the interesting part of today.",
      "Clouds everywhere. The sun is hiding from your to-do list."
    ],
    profane: [
      "Grey and miserable. At least the sky has a fucking excuse.",
      "Overcast as hell. The sun ghosted us.",
      "Cloudy. The sky looks how Monday feels.",
      "Gloomy. Don't let the sky win.",
      "Grey as shit. The sun fucked off again.",
      "Overcast. The sky can't be arsed today.",
      "Cloudy. Not a fucking ray in sight.",
      "Dull as hell. At least it's not snowing.",
      "Grey skies. The sun is ghosting us.",
      "Overcast. The weather is taking the piss.",
      "Cloudy. The sky looks like a hangover.",
      "Flat grey. Even the pigeons look bored.",
      "Gloomy as fuck. Don't let it get to you.",
      "Clouds. The sun has gone to bother someone else.",
      "Grey as fuck. The sky's given up; don't you fucking dare.",
      "Overcast. The sun fucked off, so stop waiting for permission.",
      "Dull as shit. Get on with your day and stop whinging.",
      "Cloudy. The sky can't be arsed; don't let that be your excuse, you lazy sod.",
      "Flat grey. The weather's shit, but you don't have to be."
    ]
  },
  rain: {
    nice: [
      "Rainy day. Perfect excuse to stay in and be cozy.",
      "Rain. The garden is thrilled, even if you aren't.",
      "A little rain never hurt anyone. Bring a jacket.",
      "Wet outside. Tea and window-gazing weather.",
      "Rain. The plants are having the best day.",
      "A steady drizzle. Good excuse for a slow morning.",
      "Wet weather. The sound on the roof is free therapy.",
      "Rainy. Take the umbrella and enjoy the smell.",
      "Light rain. The world is getting a wash.",
      "Drizzle. A good day for soup.",
      "Rain outside, kettle on. Correct order of operations.",
      "Showers. The garden says thank you.",
      "Rainy day. A book and a window seat.",
      "Wet and grey. Cozy up and let it fall."
    ],
    rude: [
      "It's raining. Your umbrella is at home, obviously.",
      "Rain. Your hair had plans, apparently.",
      "Wet outside. Yes, you still have to go to work.",
      "Rainy. The sky is crying; you're just late.",
      "Rain. Your shoes were nice while they lasted.",
      "Wet outside. The sky is not on your side today.",
      "Rainy. The one day you didn't check.",
      "Drizzle. It's not heavy, just relentless.",
      "Rain. The bus will be late, obviously.",
      "Wet. Your umbrella is somewhere, probably.",
      "Showers. The sky is doing that thing again.",
      "Rainy. Yes, it will get worse at exactly the wrong time.",
      "Rain. The ground is now a minefield of puddles.",
      "Damp and grim. Bring a second pair of socks."
    ],
    profane: [
      "It's pissing it down. Your umbrella is at home, obviously.",
      "Raining like hell. Your shoes are about to have a bad time.",
      "Wet as fuck. The sky picked today to fall apart.",
      "Rain. The sky is shitting on your commute.",
      "Raining. Your shoes are fucked.",
      "Wet as hell. The sky is taking the piss.",
      "Rain. Of course it's today.",
      "Pissing down. The puddles are winning.",
      "Drizzle. The sky can't even commit to a proper storm.",
      "Rainy as fuck. Your umbrella is a decoration.",
      "Wet. Everything is damp and you're late.",
      "Showers. The sky is crying and so are your socks.",
      "Rain. The commute is now a water feature.",
      "Grim, wet, and grey. Fucking wonderful.",
      "Pissing down. Your shoes are fucked, your hair's fucked, and the bus is late. Get over it.",
      "Rain. The sky's having a fucking laugh at your commute.",
      "Wet as fuck. Stop whinging and walk faster, you soggy bastard.",
      "Raining sideways. The umbrella's a fucking lie; accept it.",
      "Drizzle. The sky can't even be arsed to rain properly, the useless git."
    ]
  },
  snow: {
    nice: [
      "Snow. Everything is quiet and a little magical.",
      "Snow day energy. Dress warm and enjoy it.",
      "Fresh snow. The world looks like a postcard.",
      "Snowing. Go make a snowball, you kid.",
      "Snow. The world has gone quiet and soft.",
      "Flurries. A good day for gloves and a slow walk.",
      "Snow falling. The streetlights look like a film set.",
      "Fresh powder. Everything is prettier under it.",
      "Snowy. Build something silly before it melts.",
      "Snow day. Hot chocolate is a valid food group.",
      "Soft flakes. Take a photo before the slush arrives.",
      "Snow. Even the bins look festive.",
      "Cold and white. The quiet is the best part.",
      "Snowfall. Wrap up and enjoy the hush."
    ],
    rude: [
      "Snow. The sky has dandruff and you have to walk in it.",
      "Snowing. Your commute is now a group project.",
      "Snow. Everything is cold, white, and inconvenient.",
      "Snow day. The buses have other plans.",
      "Snow. Your commute just got a plot twist.",
      "Snowing. The buses are already lying to you.",
      "Snow. Pretty for ten minutes, then it's slush.",
      "Snow day. Your boots are not up to this.",
      "Flurries. The sky is shedding again.",
      "Snow. Everything is white except the road.",
      "Snowing. Yes, you still have to go in.",
      "Snow. The council will pretend they didn't know.",
      "White everywhere. Your train is now theoretical.",
      "Snow. The scenic route is the only route."
    ],
    profane: [
      "Snow. The sky is shitting dandruff. Wear boots.",
      "Snowing like hell. Your commute is fucked.",
      "Snow. Beautiful until you have to fucking drive in it.",
      "Cold white bullshit everywhere. At least it's pretty.",
      "Snow. The sky is shitting on your plans again.",
      "White fucking everywhere. Wear proper boots.",
      "Snow day. The roads are a joke and so are the buses.",
      "Flurries as fuck. Everything's cold and wet.",
      "Snow. Lovely from the window, fucking awful on foot.",
      "Snowing. Your train is cancelled, obviously.",
      "Cold white mess. At least it's quieter.",
      "Snow. The sky is making it everyone's problem.",
      "Blizzard-ish bullshit. Stay in if you can.",
      "Snow. The heating bill is about to get violent.",
      "Snowing like hell. The whole country's fucked; don't be the idiot who drives anyway.",
      "Snow. The sky's shitting itself and you're wearing trainers. Genius.",
      "White fucking everywhere. Your commute's a joke, your boots are a joke, and the council's on holiday.",
      "Snow day. Stay the fuck home unless you fancy a pile-up.",
      "Snow. Pretty little fucking disaster, isn't it."
    ]
  },
  storm: {
    nice: [
      "Thunderstorms. Stay cozy inside and let the sky do its thing.",
      "A proper storm. Nature is putting on a show.",
      "Thunder and lightning. Unplug the fancy stuff and enjoy the drama.",
      "Stormy. A good night to stay in and listen.",
      "Thunder. The best seat in the house is indoors.",
      "Stormy. Nature is being loud; let it.",
      "Lightning. Unplug the good stuff and enjoy the show.",
      "A proper storm. Stay warm and dry.",
      "Thunder rolling. The sky is putting on a play.",
      "Stormy. A cup of tea and a front-row seat.",
      "Rain and thunder. Perfect excuse to do nothing.",
      "The sky is grumbling. Stay inside and let it vent.",
      "Storm. Cozy up; the weather has the floor.",
      "Thunderstorms. A night for blankets and no errands."
    ],
    rude: [
      "Thunderstorms. Stay inside, genius. This one's actually dangerous.",
      "Storm. The sky is throwing a tantrum. Don't join it.",
      "Thunderstorms. Your umbrella is useless and you know it.",
      "Stormy. Nature is angry; stay out of its way.",
      "Storm. Stay inside. This isn't a personality test.",
      "Thunder. The sky is shouting; don't shout back.",
      "Stormy. Your umbrella is now a liability.",
      "Lightning. Yes, the washing can wait.",
      "Storm. Nature is in a mood; give it space.",
      "Thunderstorms. Your plans are cancelled, not delayed.",
      "Stormy. The sky is throwing furniture.",
      "Thunder. Unplug things and stop pretending you're safe.",
      "Storm. This is not the day for a walk.",
      "Lightning everywhere. Stay in and be boring."
    ],
    profane: [
      "Thunderstorms. Stay the fuck inside. This one's actually dangerous.",
      "Storm as hell. The sky is pissed and you should not test it.",
      "Thunderstorms. Your plans are cancelled. Nature said so.",
      "Stormy. Get inside before the sky fucking smites you.",
      "Storm as hell. Stay the fuck inside.",
      "Thunder. The sky is fucking furious; don't test it.",
      "Stormy. Your umbrella is a fucking joke today.",
      "Lightning. Get inside before you become a story.",
      "Thunderstorms. Cancel your shit. Nature already did.",
      "Storm. The sky is throwing a proper tantrum.",
      "Rain and thunder. Stay in, you absolute donut.",
      "Storming like hell. Don't be a hero.",
      "Lightning. Unplug the expensive stuff and fucking wait.",
      "This storm is bullshit. Stay inside.",
      "Storm. Stay the fuck inside, you absolute moron. This one can kill you.",
      "Thunder. The sky's fucking furious and you're still thinking about a walk. No.",
      "Lightning. Get the fuck indoors before the sky picks you.",
      "Thunderstorms. Cancel your shit and stay in, unless you fancy being a statistic.",
      "Storming like hell. The sky's out for blood; don't be a fucking hero."
    ]
  },
  fog: {
    nice: [
      "Fog. The world is soft and mysterious today.",
      "Misty. Take it slow and enjoy the quiet.",
      "Foggy. A good day for a thoughtful walk.",
      "Fog. The horizon is playing hide and seek.",
      "Fog. The streets have gone all soft-focus.",
      "Misty. Walk slowly and look around.",
      "Foggy. The park looks like a ghost story.",
      "Fog. A good morning for a warm drink.",
      "Low cloud. The hills have gone missing.",
      "Misty morning. Let it burn off.",
      "Fog. Everything looks like a memory.",
      "Grey soup outside. Cozy enough.",
      "Foggy. The streetlights are doing overtime.",
      "Mist. Take the long way and enjoy the hush."
    ],
    rude: [
      "Fog. Visibility is low, much like your chances of being on time.",
      "Foggy. The world has been muted for your protection.",
      "Fog. Yes, you still need to use your headlights.",
      "Misty. Your GPS is guessing now.",
      "Fog. Your headlights are not optional.",
      "Misty. The world is on low visibility mode.",
      "Fog. Yes, that is a car in front of you.",
      "Foggy. Your commute is now a guessing game.",
      "Fog. The horizon has left the building.",
      "Mist. Slow down; the road is lying to you.",
      "Fog. Everything is grey and slightly ominous.",
      "Low cloud. Your GPS is as confused as you.",
      "Foggy. No, you can't see through it.",
      "Fog. The view is cancelled."
    ],
    profane: [
      "Fog so thick you couldn't find your own ass. Drive slower.",
      "Foggy as fuck. Turn your damn lights on.",
      "Fog. The world is ghosting you literally.",
      "Thick fog. Slow the fuck down before you become a statistic.",
      "Fog thick as fuck. Slow the hell down.",
      "Fog. Lights on, ego off.",
      "Fog. You can't see shit, so drive like it.",
      "Mist. The road is a fucking mystery today.",
      "Thick fog. Don't tailgate, you idiot.",
      "Foggy as hell. Your high beams are making it worse.",
      "Fog. The street signs are just suggestions now.",
      "Low cloud. Visibility is fucked; act accordingly.",
      "Fog everywhere. Stay off the fucking phone.",
      "Fog. It's not mysterious, it's dangerous. Slow down.",
      "Fog. You can't see shit, so stop driving like an idiot.",
      "Fog thick as fuck. Slow down before you kill someone, you idiot.",
      "Foggy. Your lights are off, your brain is off, and the road's a lottery.",
      "Thick fog. It's not atmospheric, it's a fucking death trap. Drive like it.",
      "Fog. The sky's hiding the road and you're still tailgating like a moron."
    ]
  },
  wind: {
    nice: [
      "Breezy. A good day to let the wind do the dramatic hair thing.",
      "Windy. Hold onto your hat and enjoy the fresh air.",
      "A blustery day. The trees are having fun.",
      "Windy. Nature's free exfoliation.",
      "Breezy. A good day to fly a kite.",
      "Windy. Fresh air and dramatic coats.",
      "Gusty. The leaves are putting on a show.",
      "Wind. Hold your hat and enjoy the rush.",
      "Blustery. The trees are dancing.",
      "Windy. A good day for laundry, if you're brave.",
      "Breeze. The air feels alive today.",
      "Gusty. Keep your hair out of your face and enjoy it.",
      "Wind. The clouds are moving fast.",
      "Blowy. A scarf is a good idea."
    ],
    rude: [
      "Windy. Your umbrella is now a kite.",
      "Windy enough to ruin your hair and your dignity.",
      "Gusty. Yes, your recycling bin is on tour.",
      "Windy. The sky is pushing you around today.",
      "Windy. Your bins are on tour again.",
      "Gusty. The umbrella is a lost cause.",
      "Wind. Your hair has chosen violence.",
      "Blustery. Yes, your recycling is in the road.",
      "Windy. Everything is flapping and nothing is safe.",
      "Gusts. Walking is now a negotiation.",
      "Windy. Your hat is now someone else's hat.",
      "Breezy. Your plans to look tidy are cancelled.",
      "Wind. The trees are showing off.",
      "Gusty. Hold onto your coffee."
    ],
    profane: [
      "Windy as hell. Your umbrella is now a kite and your hair is fucked.",
      "Gusty as fuck. Hold onto your shit.",
      "Wind. The sky is having a tantrum and your bins are the victims.",
      "Blowing a gale. Don't bother with the fucking umbrella.",
      "Windy as fuck. Your bins are gone.",
      "Gusts. The sky is taking the piss out of your hair.",
      "Windy. The umbrella is fucking useless.",
      "Gale. Walk sideways and swear loudly.",
      "Gusty. Your hat is now in the next postcode.",
      "Wind. Everything's flapping and you look ridiculous.",
      "Blustery as hell. The trees are losing it.",
      "Windy. Your recycling is a fucking crime scene.",
      "Gale. Stay clear of the fucking trees.",
      "Wind. Your umbrella is dead; long live the wind.",
      "Windy as fuck. Your bins are gone, your hair's gone, and the fence is next.",
      "Gale. Stay away from the fucking trees before one lands on you.",
      "Blowing a gale. The sky's having a proper fucking tantrum and you're dressed for a picnic.",
      "Windy. Your umbrella's dead, your hat's gone, and you look like a fucking disaster.",
      "Gusty as hell. Hold onto your shit or lose it, you careless bastard."
    ]
  },
  hot: {
    nice: [
      "It's warm out. Find some shade and enjoy it.",
      "Hot day. Cold drinks and slow plans.",
      "Sun's out. Remember to drink some water.",
      "Warm one today. A good excuse for ice cream.",
      "Warm one. Find shade and drink water.",
      "Sunny and hot. Ice cream is a valid meal.",
      "It's warm. A good day for the park and a cold drink.",
      "Hot day. Go slow and stay hydrated.",
      "The sun is out in force. Enjoy it safely.",
      "Warm. A hat and some shade will do you good.",
      "Hot and bright. A good day for a paddling pool.",
      "Sun's up and so is the temperature. Pace yourself.",
      "Warm weather. Open the windows and let it in.",
      "It's toasty. A cold drink and a shady bench."
    ],
    rude: [
      "It's hot. You're going to complain about it either way.",
      "Hot day. Yes, you need water. No, iced coffee doesn't count.",
      "It's warm. The sun is winning; dress accordingly.",
      "Hot. Your black clothes were a choice.",
      "Hot. Iced coffee is a drink, not hydration.",
      "It's warm. Your black jeans were a mistake.",
      "Hot day. The sun is winning.",
      "Warm. You'll complain either way, so hydrate.",
      "Hot. The pavement is cooking and so are you.",
      "Sunny and hot. Find shade before you regret it.",
      "It's warm. Stop pretending you like being sweaty.",
      "Hot. Your fan is doing its best.",
      "Warm day. The office is still 22 degrees, somehow.",
      "Hot. Yes, sunscreen is still a thing."
    ],
    profane: [
      "It's hot as hell. Drink some fucking water.",
      "Hot as fuck. Stop pretending you enjoy this.",
      "The sun is absolutely roasting us. Hydrate, genius.",
      "It's fucking boiling. Find shade and stop being a hero.",
      "Hot as fuck. Your body is a fucking desert.",
      "It's boiling. Find shade and shut up.",
      "Warm as hell. Your black clothes are a war crime.",
      "Hot. The sun is roasting us and you're wearing jeans.",
      "It's fucking hot. Stop being a hero and sit down.",
      "Sun's out and it's brutal. Hydrate, you idiot.",
      "Hot. Your fan is fighting a losing battle.",
      "Boiling. The pavement is a fucking grill.",
      "It's warm as hell. Get in the shade.",
      "Hot. Yes, you're sweating. Everyone is. Move on.",
      "It's hot as fuck. Drink some fucking water before you keel over, you idiot.",
      "Boiling. The sun's trying to fucking kill us and you're still in black.",
      "Hot as hell. Get in the shade before you cook, you absolute melt.",
      "It's fucking roasting. Stop pretending you're fine and sit the fuck down.",
      "Sun's out and it's brutal. Hydrate or fucking suffer."
    ]
  },
  cold: {
    nice: [
      "Cold out. Bundle up and enjoy the crisp air.",
      "Chilly. A good day for a warm coat and a hot drink.",
      "Cold snap. The scarf is not optional.",
      "Brisk today. Dress in layers and you'll be fine.",
      "Cold. A good day for a proper coat.",
      "Chilly. The kettle is the best invention today.",
      "Frosty. The world looks sharp and clean.",
      "Cold snap. Layers are your friend.",
      "Brisk. A walk will wake you up.",
      "It's cold. A scarf makes all the difference.",
      "Frost on the windows. A good morning to stay in.",
      "Cold and clear. Wrap up and enjoy it.",
      "Freezing. Hat, gloves, and a warm drink.",
      "Cold. The air is sharp and the sky is bright."
    ],
    rude: [
      "It's freezing. Put on a coat, you absolute walnut.",
      "Cold. Yes, shorts were a bad idea. We all saw it.",
      "Freezing. The sky is not messing around today.",
      "Chilly. Your fingers will file a complaint.",
      "Cold. Yes, a hoodie is not a coat.",
      "Freezing. Your fingers are already complaining.",
      "Chilly. The shorts were a bold choice.",
      "Frosty. Scrape the car properly, genius.",
      "It's freezing. Your ears will not forgive you.",
      "Cold. Your heating bill is going to be a novel.",
      "Brisk. Dress like you mean it.",
      "Chilly. The bus stop is now an endurance event.",
      "Freezing. Your ears are turning a new colour.",
      "Cold. The sky is being extra about it."
    ],
    profane: [
      "It's freezing. Put a fucking coat on.",
      "Cold as fuck. Stop pretending you're built for this.",
      "Freezing. Wear a damn hat before your ears fall off.",
      "It's fucking Baltic. Layer up, you maniac.",
      "Cold as fuck. Wear a fucking coat.",
      "Freezing. Your ears are not built for this.",
      "It's Baltic. Layer the fuck up.",
      "Chilly as hell. Stop pretending shorts are fine.",
      "Frosty. Scrape your fucking windscreen.",
      "Cold. The sky is being a bastard today.",
      "Freezing. Hat, gloves, and fucking socks.",
      "Brisk as fuck. Dress like an adult.",
      "Freezing. The bus stop is a fucking icebox.",
      "Cold. Your heating is about to earn its keep.",
      "Freezing. Put a fucking coat on before you get hypothermia, you idiot.",
      "Cold as fuck. Your ears are going to fall off and I'll fucking laugh.",
      "It's Baltic. Dress like a fucking adult or stay inside.",
      "Freezing. The sky's a bastard and you're in a hoodie. Fucking brilliant.",
      "Cold. Your heating's going to cost a fucking fortune and you'll still be shivering."
    ]
  },
  humid: {
    nice: [
      "Humid today. Take it slow and keep some water nearby.",
      "Sticky air. A good day for a fan and a cold drink.",
      "Muggy. The air is basically a warm hug.",
      "Humid. Your hair will do whatever it wants.",
      "Humid. Slow down and keep a drink handy.",
      "Muggy. A fan and a cold drink will help.",
      "Sticky air. A good day for a swim.",
      "Humid. Light clothes and slow plans.",
      "It's close today. Find a breeze if you can.",
      "Muggy. The air is thick; pace yourself.",
      "Humid. Find some shade and sit very still.",
      "Sticky. Open the windows and hope for wind.",
      "Warm and humid. A good day for a siesta.",
      "Muggy. The air is doing a warm blanket impression."
    ],
    rude: [
      "90% humidity. Congratulations, you're soup.",
      "Muggy. You're not sweating; you're marinating.",
      "Humid. The air is wearing you.",
      "Sticky. Your shirt has already given up.",
      "Humid. Your hair has chosen chaos.",
      "Sticky. Everything you touch is slightly damp.",
      "It's close. The air is doing nothing for you.",
      "Humid. Your fan is just moving soup around.",
      "Muggy. The weather is doing a sauna.",
      "Humid. Everything sticks and nothing dries.",
      "Muggy. You're sweating in places you forgot about.",
      "Humid. The air is warm and useless.",
      "Sticky. The windows are fogged and so are you.",
      "Muggy. Even the fan looks tired."
    ],
    profane: [
      "It's humid as fuck. You're not sweating, you're marinating.",
      "Muggy as hell. The air is fucking soup.",
      "Sticky. Your clothes are losing the will to live.",
      "Humid. Welcome to the world's shittiest sauna.",
      "It's a fucking sauna out there.",
      "Humid. Everything is damp and you're angry.",
      "Muggy. The air is thick as shit.",
      "Sticky as fuck. Your shirt is a lost cause.",
      "Close and gross. The fan is doing fuck all.",
      "Muggy as fuck. Move slowly and swear quietly.",
      "Humid. The air is a wet fucking blanket.",
      "Sticky. Nothing dries and you're furious.",
      "It's muggy as hell. Sit still and suffer.",
      "Humid. The weather is taking the piss.",
      "Humid as fuck. You're sweating like a bastard and the air's doing nothing.",
      "Muggy as hell. The air's a fucking swamp and your shirt's already dead.",
      "Sticky. Everything's damp, everything stinks, and the fan's a fucking joke.",
      "It's a fucking sauna. Sit still, sweat, and shut up.",
      "Humid. The weather's a wet fucking blanket and you're stuck under it."
    ]
  }
}

// Holiday packs take over from the weather category for the day. Keep them
// warm enough for the date and generic enough to fit whatever the sky does.
var HOLIDAYS = {
  christmas: {
    nice: [
      "Merry Christmas. Whatever the weather, the kettle is on.",
      "Christmas. Snow or not, it's a good day to be warm.",
      "Happy Christmas. Eat too much and blame the weather.",
      "Christmas. The sky can do what it likes; you're inside with cake.",
      "Merry Christmas. A day for family, food, and no errands.",
      "Christmas. Even the grey looks festive today.",
      "Happy Christmas. Stay warm and let someone else do the dishes.",
      "Christmas. A good day to do absolutely nothing useful."
    ],
    rude: [
      "Merry Christmas. Yes, you have to talk to your relatives.",
      "Christmas. The weather is not the difficult part today.",
      "Happy Christmas. The sprouts are already plotting.",
      "Christmas. Someone will argue about the heating.",
      "Merry Christmas. Your uncle has opinions about the weather.",
      "Christmas. The only day the grey sky counts as festive.",
      "Happy Christmas. Try not to start a fight at dinner.",
      "Christmas. Eat, nap, repeat. The weather can wait."
    ],
    profane: [
      "Merry fucking Christmas. Eat too much and argue with family.",
      "Christmas. The weather's shit, the dinner's good. Balance.",
      "Happy Christmas, you absolute gremlin.",
      "Christmas. The sky can fuck off; there's cake.",
      "Merry Christmas. Someone's already on the wine.",
      "Christmas. Eat like it's your job and ignore the weather.",
      "Happy fucking Christmas. Stay warm and stay out of the kitchen politics.",
      "Christmas. The heating is on, the family is here, God help us."
    ]
  },
  newyear: {
    nice: [
      "Happy New Year. Whatever the weather, a fresh start.",
      "New Year. A fresh start, same sky.",
      "New Year. A good time to be warm and among friends.",
      "Happy New Year. May the weather be kinder this year.",
      "New Year. Stay warm and let the fireworks do the work.",
      "New Year. A blank page and a cold night.",
      "Happy New Year. Here's to a better forecast.",
      "New Year. Quiet night or loud one, dress for the weather."
    ],
    rude: [
      "Happy New Year. The weather is not the thing that will ruin it.",
      "Happy New Year. Same sky, new excuses.",
      "New Year. The resolutions won't survive the weather either.",
      "New Year. Someone will cry before the night is out.",
      "Happy New Year. The fireworks are louder than your plans.",
      "New Year. The weather's grim and the taxi's expensive.",
      "New Year. Dress warm; the queue is outside.",
      "Happy New Year. The sky doesn't care about your fresh start."
    ],
    profane: [
      "Happy fucking New Year. The weather's still shit.",
      "New Year. Get warm, get drunk, get home.",
      "New Year. Same bullshit sky, new year.",
      "Happy New Year. The fireworks are better than the weather.",
      "New Year. Don't freeze waiting for a taxi.",
      "New Year. The resolutions are already fucked.",
      "Happy fucking New Year. May the forecast be less of a bastard.",
      "New Year. It's cold, it's loud, and it's nearly over."
    ]
  },
  halloween: {
    nice: [
      "Halloween. The fog is doing the decorating for free.",
      "Happy Halloween. A good night for a costume and a walk.",
      "Halloween. The dark comes early; enjoy the spooky.",
      "Halloween. Even the weather is dressed up tonight.",
      "Happy Halloween. Sweets, candles, and a warm coat.",
      "Halloween. A good night for a ghost story.",
      "Halloween. The sky is grey and the pumpkins are glowing.",
      "Halloween. Stay warm and let the kids have the street."
    ],
    rude: [
      "Halloween. Your costume is not weatherproof.",
      "Happy Halloween. The real horror is the forecast.",
      "Halloween. Yes, you're too old. Do it anyway.",
      "Halloween. The fog is free and the sweets are not.",
      "Happy Halloween. Someone's pumpkin is already rotting.",
      "Halloween. Dress up; the weather is doing scary for free.",
      "Halloween. The trick is staying dry.",
      "Happy Halloween. The scariest thing is your outfit."
    ],
    profane: [
      "Happy fucking Halloween. The weather's already in costume.",
      "Halloween. The fog is doing the work; you do the drinking.",
      "Halloween. It's cold, it's dark, and the sweets are shit.",
      "Happy Halloween. Don't freeze for a costume.",
      "Halloween. The real horror is the weather.",
      "Halloween. Get spooky, get warm, get on with it.",
      "Happy fucking Halloween. The pumpkins look better than the sky.",
      "Halloween. Stay in with the sweets; the weather's grim."
    ]
  }
}

var HOLIDAY_DAYS = {
  "12-24": "christmas",
  "12-25": "christmas",
  "12-26": "christmas",
  "12-31": "newyear",
  "01-01": "newyear",
  "10-31": "halloween"
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

function holidayFor(dayKey) {
  var name = HOLIDAY_DAYS[String(dayKey || "")]
  return name ? HOLIDAYS[name] : null
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
  var holiday = holidayFor(context.dayKey)
  var pack = holiday || PACKS[categoryFor(context)] || PACKS.clear
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
    holidayFor: holidayFor,
    toneFor: toneFor,
    lineFor: lineFor
  }
}
