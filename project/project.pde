#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <TFT_eSPI.h>
#include <time.h>
#include <LilyGo_AMOLED.h>
#include <LV_Helper.h>
#include <lvgl.h>

// -----------------------------
// Wi-Fi credentials
// -----------------------------
static const char* WIFI_SSID     = "iPhone";      // <--- CHANGE THIS
static const char* WIFI_PASSWORD = "123456789";  // <--- CHANGE THIS

// -----------------------------
// OpenWeather API setup
// -----------------------------
// Get your free API key here: https://openweathermap.org/api
static const char* WEATHER_API_KEY = "016c0c44dbd096e136df092d9f187c7f";      // <--- CHANGE THIS
static const char* CITY_NAME       = "Karlskrona";         // <--- CHANGE THIS
static const char* COUNTRY_CODE    = "SE";                // <--- CHANGE THIS
// Example: "London", "GB"

// -----------------------------
// Global objects
// -----------------------------
LilyGo_Class amoled;
static lv_obj_t* status_label;
static lv_obj_t* weather_label;

// --- Tabs for swipe between pages ---
static lv_obj_t* tabview;
static lv_obj_t* tab_boot;
static lv_obj_t* tab_weather;

// -----------------------------
// Function: Connect to Wi-Fi
// -----------------------------
void connect_wifi() {
  Serial.printf("Connecting to WiFi SSID: %s\n", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long startAttemptTime = millis();
  const unsigned long timeout = 15000; // 15 seconds timeout

  while (WiFi.status() != WL_CONNECTED && millis() - startAttemptTime < timeout) {
    Serial.print(".");
    delay(500);
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("✅ WiFi connected successfully!");
    Serial.print("📶 IP Address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("❌ WiFi connection failed!");
  }
}

// -----------------------------
// Function: Create UI
// -----------------------------
void create_ui() {
  lv_obj_t* screen = lv_scr_act();

  // Tabview with two pages (swipe enabled)
  tabview = lv_tabview_create(screen, LV_DIR_TOP, 40); // 40px header, we hide it
  lv_obj_t* header = lv_tabview_get_tab_btns(tabview); // <-- LVGL 8.4 API
  lv_obj_add_flag(header, LV_OBJ_FLAG_HIDDEN);         // Hide the tab buttons

  // --- TAB 1: Boot screen ---
  tab_boot = lv_tabview_add_tab(tabview, "Boot");

  // Title: Group 19
  lv_obj_t* boot_title = lv_label_create(tab_boot);
  lv_label_set_text(boot_title, "Group 19");
  lv_obj_set_style_text_font(boot_title, &lv_font_montserrat_20, 0);
  lv_obj_align(boot_title, LV_ALIGN_TOP_MID, 0, 28);

  // Names
  lv_obj_t* names = lv_label_create(tab_boot);
  lv_label_set_text(names, "Ghazi\nOsama\nFeras\nOmar\nImad");
  lv_obj_set_style_text_font(names, &lv_font_montserrat_18, 0);
  lv_obj_align(names, LV_ALIGN_CENTER, 0, -10);

  // Version
  lv_obj_t* ver = lv_label_create(tab_boot);
  lv_label_set_text(ver, "Version 1.0");
  lv_obj_set_style_text_font(ver, &lv_font_montserrat_18, 0);
  lv_obj_align(ver, LV_ALIGN_CENTER, 0, 60);

  // Hint
  lv_obj_t* hint = lv_label_create(tab_boot);
  lv_label_set_text(hint, "Swipe \u2192 for Weather");
  lv_obj_set_style_text_font(hint, &lv_font_montserrat_18, 0);
  lv_obj_align(hint, LV_ALIGN_BOTTOM_MID, 0, -16);

  // --- TAB 2: Weather screen ---
  tab_weather = lv_tabview_add_tab(tabview, "Weather");

  // Title
  lv_obj_t* title = lv_label_create(tab_weather);
  lv_label_set_text(title, "LilyGO Weather Display");
  lv_obj_set_style_text_font(title, &lv_font_montserrat_20, 0);
  lv_obj_align(title, LV_ALIGN_TOP_MID, 0, 20);

  // Status label
  status_label = lv_label_create(tab_weather);
  lv_obj_set_style_text_font(status_label, &lv_font_montserrat_18, 0);
  lv_obj_align(status_label, LV_ALIGN_CENTER, 0, -40);
  lv_label_set_text(status_label, "Connecting to WiFi...");

  // Weather label
  weather_label = lv_label_create(tab_weather);
  lv_obj_set_style_text_font(weather_label, &lv_font_montserrat_20, 0);
  lv_obj_align(weather_label, LV_ALIGN_CENTER, 0, 40);
  lv_label_set_text(weather_label, "No data yet");

  // Start on boot page
  lv_tabview_set_act(tabview, 0, LV_ANIM_OFF);
}

// -----------------------------
// Function: Update UI text
// -----------------------------
void update_label(lv_obj_t* label, const String& msg) {
  lv_label_set_text(label, msg.c_str());
  lv_timer_handler(); // Refresh
}

// -----------------------------
// Function: Fetch weather info
// -----------------------------
String get_weather() {
  if (WiFi.status() != WL_CONNECTED) {
    return "WiFi not connected";
  }

  HTTPClient http;
  String url = "https://api.openweathermap.org/data/2.5/weather?q=" 
                + String(CITY_NAME) + "," + COUNTRY_CODE +
                "&appid=" + WEATHER_API_KEY + "&units=metric";
  Serial.println("🌍 Requesting: " + url);
  http.begin(url);

  int httpResponseCode = http.GET();
  String result;

  if (httpResponseCode == 200) {
    String payload = http.getString();
    Serial.println("✅ Weather data received.");

    DynamicJsonDocument doc(8192);
    DeserializationError error = deserializeJson(doc, payload);

    if (!error) {
      const char* weatherMain = doc["weather"][0]["main"];
      float temp = doc["main"]["temp"];
      String city = doc["name"];
      result = "📍 " + city + "\n" + String(temp, 1) + "°C | " + weatherMain;
    } else {
      result = "JSON parse error!";
    }
  } else {
    result = "HTTP error: " + String(httpResponseCode);
  }

  http.end();
  return result;
}

// -----------------------------
// Setup
// -----------------------------
void setup() {
  Serial.begin(115200);
  delay(200);

  if (!amoled.begin()) {
    Serial.println("❌ Failed to init LilyGO AMOLED!");
    while (true) delay(1000);
  }

  beginLvglHelper(amoled);
  create_ui();

  update_label(status_label, "Connecting to WiFi...");
  connect_wifi();

  if (WiFi.status() == WL_CONNECTED) {
    String ipMsg = "✅ Connected!\nIP: " + WiFi.localIP().toString();
    update_label(status_label, ipMsg);

    // Fetch weather info
    update_label(weather_label, "Fetching weather...");
    String weather = get_weather();
    update_label(weather_label, weather);
  } else {
    update_label(status_label, "❌ WiFi failed!");
  }
}

// -----------------------------
// Loop
// -----------------------------
void loop() {
  lv_timer_handler();
  delay(5);
}
