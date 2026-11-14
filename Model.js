.pragma library

// Statusphere's Open-Meteo reader. Everything here is pure: no Qt objects, no
// network, no files. Panel.qml owns acquisition; this file only validates and
// shapes the response so a malformed payload can never become visible state.

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function number(value, minimum, maximum) {
  if (value === undefined || value === null || value === "") return null
  if (typeof value !== "number" && typeof value !== "string") return null
  var text = String(value)
  if (text.length > 24 || !/^-?[0-9]+(?:\.[0-9]+)?$/.test(text)) return null
  var parsed = Number(text)
  if (!isFinite(parsed) || parsed < minimum || parsed > maximum) return null
  return parsed
}

function integer(value, minimum, maximum) {
  var parsed = number(value, minimum, maximum)
  return parsed === null || Math.floor(parsed) !== parsed ? null : parsed
}

function at(array, index) {
  return Array.isArray(array) ? array[index] : null
}

function dateKey(value) {
  if (typeof value !== "string" || !/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(value))
    return null
  var year = Number(value.slice(0, 4))
  var month = Number(value.slice(5, 7))
  var day = Number(value.slice(8, 10))
  if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) return null
  var date = new Date(value + "T00:00:00")
  if (isNaN(date.getTime())) return null
  return date.getFullYear() === year && date.getMonth() === month - 1
    && date.getDate() === day ? value : null
}

function cToF(value) {
  return Math.round(((value * 9 / 5) + 32) * 10) / 10
}

function kmhToMph(value) {
  return Math.round(value * 0.621371 * 10) / 10
}

function descriptionForCode(code) {
  var value = parseInt(String(code || "0"), 10) || 0
  if (value === 0) return "Clear sky"
  if (value === 1) return "Mainly clear"
  if (value === 2) return "Partly cloudy"
  if (value === 3) return "Overcast"
  if (value === 45 || value === 48) return "Fog"
  if (value >= 51 && value <= 57) return "Drizzle"
  if (value >= 61 && value <= 67) return "Rain"
  if (value >= 71 && value <= 77) return "Snow"
  if (value >= 80 && value <= 82) return "Rain showers"
  if (value === 85 || value === 86) return "Snow showers"
  if (value === 95) return "Thunderstorm"
  if (value === 96 || value === 99) return "Thunderstorm with hail"
  return "Cloudy"
}

// WMO weather codes mapped to the same Nerd Font glyphs the rest of the
// shell uses. Clear and partly cloudy have a night variant.
function iconForCode(code, night) {
  var value = parseInt(String(code || "0"), 10) || 0
  if (value === 0) return night ? "\ue32b" : "\ue30d"
  if (value === 1 || value === 2) return night ? "\ue32e" : "\ue302"
  if (value === 3) return "\ue33d"
  if (value === 45 || value === 48) return "\ue313"
  if (value >= 51 && value <= 57) return "\ue318"
  if (value >= 61 && value <= 67) return "\ue308"
  if (value >= 71 && value <= 77) return "\ue31a"
  if (value >= 80 && value <= 82) return "\ue308"
  if (value === 85 || value === 86) return "\ue31a"
  if (value >= 95) return "\ue31d"
  return "\ue33d"
}

// WMO code -> the particle effect the popup should show. Snow and thunder win
// over rain; stars only appear on a clear night.
function effectForCode(code, isDay) {
  var value = parseInt(String(code || "0"), 10) || 0
  if ((value >= 71 && value <= 77) || value === 85 || value === 86)
    return "snow"
  if (value >= 95) return "storm"
  if ((value >= 51 && value <= 67) || (value >= 80 && value <= 82))
    return "rain"
  if (value === 45 || value === 48) return "fog"
  if ((value === 0 || value === 1) && isDay === false) return "stars"
  return ""
}

function parseDaily(daily) {
  var times = daily.time
  if (!Array.isArray(times) || times.length === 0) return []
  var codes = daily.weather_code
  var maxima = daily.temperature_2m_max
  var minima = daily.temperature_2m_min
  var rains = daily.precipitation_probability_max
  var uvs = daily.uv_index_max
  var sunrises = daily.sunrise
  var sunsets = daily.sunset
  var result = []
  var count = Math.min(times.length, 3)
  for (var index = 0; index < count; index++) {
    var date = dateKey(times[index])
    var code = integer(at(codes, index), 0, 99)
    var maxC = number(at(maxima, index), -100, 60)
    var minC = number(at(minima, index), -100, 60)
    if (date === null || code === null || maxC === null || minC === null
        || minC > maxC) return []
    var rain = number(at(rains, index), 0, 100)
    var uv = number(at(uvs, index), 0, 20)
    var sunrise = at(sunrises, index)
    var sunset = at(sunsets, index)
    result.push({
      date: date,
      code: code,
      maxC: maxC,
      maxF: cToF(maxC),
      minC: minC,
      minF: cToF(minC),
      rain: rain === null ? 0 : rain,
      uv: uv === null ? 0 : uv,
      sunrise: typeof sunrise === "string" ? sunrise : "",
      sunset: typeof sunset === "string" ? sunset : "",
      description: descriptionForCode(code),
      icon: iconForCode(code, false)
    })
  }
  return result
}

function parseWeather(raw, fetchedAt) {
  var data
  try {
    data = JSON.parse(String(raw || ""))
  } catch (error) {
    return null
  }
  if (!isObject(data) || !isObject(data.current) || !isObject(data.daily))
    return null

  var current = data.current
  var tempC = number(current.temperature_2m, -100, 60)
  var feelsC = number(current.apparent_temperature, -120, 70)
  var humidity = number(current.relative_humidity_2m, 0, 100)
  var windKmh = number(current.wind_speed_10m, 0, 500)
  var code = integer(current.weather_code, 0, 99)
  var isDay = integer(current.is_day, 0, 1)
  if (tempC === null || feelsC === null || humidity === null
      || windKmh === null || code === null || isDay === null) return null

  var daily = parseDaily(data.daily)
  if (daily.length === 0) return null

  var stamp = number(fetchedAt, 0, 4102444800000)
  return {
    fetchedAt: stamp === null ? Date.now() : stamp,
    current: {
      tempC: tempC,
      tempF: cToF(tempC),
      feelsC: feelsC,
      feelsF: cToF(feelsC),
      humidity: humidity,
      windKmh: windKmh,
      windMph: kmhToMph(windKmh),
      code: code,
      isDay: isDay === 1,
      description: descriptionForCode(code),
      icon: iconForCode(code, isDay === 0)
    },
    daily: daily
  }
}

function parseLocation(raw) {
  var unset = { name: "", latitude: null, longitude: null }
  var data
  try {
    data = JSON.parse(String(raw || ""))
  } catch (error) {
    return unset
  }
  if (!isObject(data)) return unset
  var latitude = number(data.latitude, -90, 90)
  var longitude = number(data.longitude, -180, 180)
  var hasCoordinates = latitude !== null && longitude !== null
  return {
    name: typeof data.name === "string" ? data.name.trim().slice(0, 120) : "",
    latitude: hasCoordinates ? latitude : null,
    longitude: hasCoordinates ? longitude : null
  }
}

function parseGeocode(raw) {
  var data
  try {
    data = JSON.parse(String(raw || ""))
  } catch (error) {
    return null
  }
  if (!isObject(data) || !Array.isArray(data.results) || data.results.length === 0)
    return null
  var result = data.results[0]
  if (!isObject(result)) return null
  var latitude = number(result.latitude, -90, 90)
  var longitude = number(result.longitude, -180, 180)
  if (latitude === null || longitude === null) return null
  return {
    name: typeof result.name === "string"
      ? result.name.trim().slice(0, 120) : "",
    latitude: latitude,
    longitude: longitude
  }
}

function parseGeocodeResults(raw, limit) {
  var data
  try {
    data = JSON.parse(String(raw || ""))
  } catch (error) {
    return []
  }
  if (!isObject(data) || !Array.isArray(data.results)) return []
  var max = Number(limit)
  if (!isFinite(max) || max < 1) max = 4
  var results = []
  for (var i = 0; i < data.results.length && results.length < max; i++) {
    var result = data.results[i]
    if (!isObject(result)) continue
    var latitude = number(result.latitude, -90, 90)
    var longitude = number(result.longitude, -180, 180)
    if (latitude === null || longitude === null) continue
    var name = typeof result.name === "string"
      ? result.name.trim().slice(0, 120) : ""
    if (name === "") continue
    var parts = []
    var region = typeof result.admin1 === "string" ? result.admin1.trim() : ""
    var country = typeof result.country === "string" ? result.country.trim() : ""
    if (region !== "" && region !== name) parts.push(region)
    if (country !== "" && country !== name) parts.push(country)
    results.push({
      name: name,
      latitude: latitude,
      longitude: longitude,
      detail: parts.join(", ")
    })
  }
  return results
}

function localeUsesImperial(localeName) {
  var name = String(localeName || "").replace(".", "_")
  return /^en[_-]US($|[_.-])/.test(name)
    || /^en[_-]LR($|[_.-])/.test(name)
    || /^my($|[_.-])/.test(name)
}

function formatTemp(value) {
  var parsed = Number(value)
  return isFinite(parsed) ? Math.round(parsed) + "\u00b0" : ""
}

// A small hue/saturation nudge around the theme accent. The accent stays the
// base color; the condition only changes its mood.
function moodFor(code, tempC, humidity, windKmh) {
  var value = parseInt(String(code || "0"), 10) || 0
  if (value >= 95) return { hue: -0.15, sat: 0.95 }
  if ((value >= 71 && value <= 77) || value === 85 || value === 86)
    return { hue: -0.18, sat: 0.85 }
  if ((value >= 51 && value <= 67) || (value >= 80 && value <= 82))
    return { hue: -0.10, sat: 0.9 }
  if (value === 45 || value === 48) return { hue: 0.0, sat: 0.55 }
  if (tempC >= 30) return { hue: 0.06, sat: 1.0 }
  if (tempC <= 2) return { hue: -0.12, sat: 0.9 }
  if (humidity >= 80 && tempC >= 20) return { hue: -0.04, sat: 0.85 }
  if (windKmh >= 30) return { hue: 0.02, sat: 0.9 }
  if (value >= 1 && value <= 3) return { hue: 0.0, sat: 0.7 }
  return { hue: 0.05, sat: 1.0 }
}

if (typeof module !== "undefined") {
  module.exports = {
    parseWeather: parseWeather,
    parseLocation: parseLocation,
    parseGeocode: parseGeocode,
    parseGeocodeResults: parseGeocodeResults,
    localeUsesImperial: localeUsesImperial,
    formatTemp: formatTemp,
    moodFor: moodFor,
    effectForCode: effectForCode,
    descriptionForCode: descriptionForCode,
    iconForCode: iconForCode
  }
}
