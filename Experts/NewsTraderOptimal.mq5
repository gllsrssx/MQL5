
#property copyright "Copyright 2024, GllsRssx Ltd."
#property link "https://www.rssx.eu"
#property version "2.0"
#property description "This EA starts a hedge trade with recovery zone when a news event is detected."

#include <Trade\Trade.mqh>
CTrade trade;

input group "========= settings =========";
input long InpMagicNumber = 88888888; // Magic number
enum CURRENCIES_ENUM
{
  CURRENCY_SYMBOL, // SYMBOL
  CURRENCY_ALL,    // ALL
  CURRENCY_AUD,    // AUD
  CURRENCY_CAD,    // CAD
  CURRENCY_CHF,    // CHF
  CURRENCY_CZK,    // CZK
  CURRENCY_DKK,    // DKK
  CURRENCY_EUR,    // EUR
  CURRENCY_GBP,    // GBP
  CURRENCY_HUF,    // HUF
  CURRENCY_JPY,    // JPY
  CURRENCY_NOK,    // NOK
  CURRENCY_NZD,    // NZD
  CURRENCY_PLN,    // PLN
  CURRENCY_SEK,    // SEK
  CURRENCY_USD     // USD
};
input CURRENCIES_ENUM InpCurrencies = CURRENCY_SYMBOL; // Currency
string InpCurrency = InpCurrencies == CURRENCY_SYMBOL ? "SYMBOL"
                     : InpCurrencies == CURRENCY_ALL  ? "ALL"
                     : InpCurrencies == CURRENCY_AUD  ? "AUD"
                     : InpCurrencies == CURRENCY_CAD  ? "CAD"
                     : InpCurrencies == CURRENCY_CHF  ? "CHF"
                     : InpCurrencies == CURRENCY_CZK  ? "CZK"
                     : InpCurrencies == CURRENCY_DKK  ? "DKK"
                     : InpCurrencies == CURRENCY_EUR  ? "EUR"
                     : InpCurrencies == CURRENCY_GBP  ? "GBP"
                     : InpCurrencies == CURRENCY_HUF  ? "HUF"
                     : InpCurrencies == CURRENCY_JPY  ? "JPY"
                     : InpCurrencies == CURRENCY_NOK  ? "NOK"
                     : InpCurrencies == CURRENCY_NZD  ? "NZD"
                     : InpCurrencies == CURRENCY_PLN  ? "PLN"
                     : InpCurrencies == CURRENCY_SEK  ? "SEK"
                     : InpCurrencies == CURRENCY_USD  ? "USD"
                                                      : "";
string currencies[];
 bool InpFixedRisk = false; // Fixed risk

input double InpRisk = 1.0;                      // Risk size
input double InpRiskReward = 1.0;                // Risk reward
input ENUM_TIMEFRAMES InpTimeFrame = PERIOD_M15; // Range time frame minutes
input ENUM_TIMEFRAMES InpFastEntry = PERIOD_H1;  // fast entry minutes (0=off)
input double InpZoneTimeDivider = 1.0;           // Zone time divider
 ENUM_TIMEFRAMES InpFrequecy = PERIOD_M1;   // trade frequency
enum NEWS_IMPORTANCE_ENUM
{
  IMPORTANCE_ALL,    // ALL
  IMPORTANCE_HIGH,   // HIGH
  IMPORTANCE_MEDIUM, // MEDIUM
  IMPORTANCE_LOW,    // LOW
  IMPORTANCE_BOTH,   // H&M
  IMPORTANCE_NOT_LOW,// NL
};
input NEWS_IMPORTANCE_ENUM InpImportance = IMPORTANCE_ALL; // News importance
bool InpImportance_high = InpImportance == IMPORTANCE_ALL || InpImportance == IMPORTANCE_HIGH || InpImportance == IMPORTANCE_BOTH || InpImportance == IMPORTANCE_NOT_LOW;
bool InpImportance_moderate = InpImportance == IMPORTANCE_ALL || InpImportance == IMPORTANCE_MEDIUM || InpImportance == IMPORTANCE_BOTH || InpImportance == IMPORTANCE_NOT_LOW;
bool InpImportance_low = InpImportance == IMPORTANCE_ALL || InpImportance == IMPORTANCE_LOW;
bool InpImportance_all = InpImportance == IMPORTANCE_ALL || InpImportance == IMPORTANCE_NOT_LOW;

input int InpStartHour = 2;  // Start Hour (0 = off)
input int InpEndHour = 22;    // End Hour (0 = off)

input bool InpMonday = true;    // Monday
input bool InpTuesday = true;   // Tuesday
input bool InpWednesday = true; // Wednesday
input bool InpThursday = true;  // Thursday
input bool InpFriday = true;    // Friday
input bool InpSaturday = false; // Saturday
input bool InpSunday = false;   // Sunday

input bool InpShowInfo = true;       // Show Info
input bool InpShowLines = true;      // Show Range

MqlCalendarValue news[];
MqlTick tick;
MqlDateTime time;

double upperLine, lowerLine;

int OnInit()
{
  if (TimeCurrent() > StringToTime("2025.01.01 00:00:00"))
  {
    Print("INFO: This is a demo version of the EA. It will only work until January 1, 2025.");
    ExpertRemove();
  }
 
  trade.SetExpertMagicNumber(InpMagicNumber);

  if (MQLInfoInteger(MQL_TESTER))
    Print("INFO: Please run the EA in real mode first to download the history.");
  else
    downloadNews();

  ObjectsDeleteAll(0);
  ChartRedraw();

  string messageSucces = "SUCCES: EA running successfully.";
  
  Print(messageSucces);
  Comment(messageSucces);
  return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
  ChartRedraw();
  Print("Last news event: "+lastNewsEvent);
  Print("INFO: EA stopped!");
  if (!MQLInfoInteger(MQL_TESTER))
    Comment("INFO: EA stopped!");
}

void OnTick()
{
  TimeToStruct(TimeCurrent(), time);
  SymbolInfoTick(Symbol(), tick);
  Main();
}

struct economicNews
{
  MqlCalendarEvent event;
  MqlCalendarValue value;
  MqlCalendarCountry country;
};
economicNews newsHist[];
void createEconomicNews(MqlCalendarEvent &event, MqlCalendarValue &value, MqlCalendarCountry &country, economicNews &newsBT)
{

  newsBT.value = value;
  newsBT.event = event;
  newsBT.country = country;
}

string newsToString(economicNews &newsBT)
{

  string strNews = "";
  strNews += ((string)newsBT.event.id + ";");
  strNews += ((string)newsBT.event.type + ";");
  strNews += ((string)newsBT.event.sector + ";");
  strNews += ((string)newsBT.event.frequency + ";");
  strNews += ((string)newsBT.event.time_mode + ";");
  strNews += ((string)newsBT.event.country_id + ";");
  strNews += ((string)newsBT.event.unit + ";");
  strNews += ((string)newsBT.event.importance + ";");
  strNews += ((string)newsBT.event.multiplier + ";");
  strNews += ((string)newsBT.event.digits + ";");
  strNews += (newsBT.event.source_url + ";");
  strNews += (newsBT.event.event_code + ";");
  strNews += (newsBT.event.name + ";");
  strNews += ((string)newsBT.value.id + ";");
  strNews += ((string)newsBT.value.event_id + ";");
  strNews += ((string)(long)newsBT.value.time + ";");
  strNews += ((string)(long)newsBT.value.period + ";");
  strNews += ((string)newsBT.value.revision + ";");
  strNews += ((string)newsBT.value.actual_value + ";");
  strNews += ((string)newsBT.value.prev_value + ";");
  strNews += ((string)newsBT.value.revised_prev_value + ";");
  strNews += ((string)newsBT.value.forecast_value + ";");
  strNews += ((string)newsBT.value.impact_type + ";");
  strNews += ((string)newsBT.country.id + ";");
  strNews += ((string)newsBT.country.name + ";");
  strNews += ((string)newsBT.country.code + ";");
  strNews += ((string)newsBT.country.currency + ";");
  strNews += ((string)newsBT.country.currency_symbol + ";");
  strNews += ((string)newsBT.country.url_name);

  return strNews;
}

bool stringToNews(string newsStr, economicNews &newsBT)
{

  string tokens[];

  if (StringSplit(newsStr, ';', tokens) == 29)
  {

    newsBT.event.id = (ulong)tokens[0];
    newsBT.event.type = (ENUM_CALENDAR_EVENT_TYPE)tokens[1];
    newsBT.event.sector = (ENUM_CALENDAR_EVENT_SECTOR)tokens[2];
    newsBT.event.frequency = (ENUM_CALENDAR_EVENT_FREQUENCY)tokens[3];
    newsBT.event.time_mode = (ENUM_CALENDAR_EVENT_TIMEMODE)tokens[4];
    newsBT.event.country_id = (ulong)tokens[5];
    newsBT.event.unit = (ENUM_CALENDAR_EVENT_UNIT)tokens[6];
    newsBT.event.importance = (ENUM_CALENDAR_EVENT_IMPORTANCE)tokens[7];
    newsBT.event.multiplier = (ENUM_CALENDAR_EVENT_MULTIPLIER)tokens[8];
    newsBT.event.digits = (uint)tokens[9];
    newsBT.event.source_url = tokens[10];
    newsBT.event.event_code = tokens[11];
    newsBT.event.name = tokens[12];
    newsBT.value.id = (ulong)tokens[13];
    newsBT.value.event_id = (ulong)tokens[14];
    newsBT.value.time = (datetime)(long)tokens[15];
    newsBT.value.period = (datetime)(long)tokens[16];
    newsBT.value.revision = (int)tokens[17];
    newsBT.value.actual_value = (long)tokens[18];
    newsBT.value.prev_value = (long)tokens[19];
    newsBT.value.revised_prev_value = (long)tokens[20];
    newsBT.value.forecast_value = (long)tokens[21];
    newsBT.value.impact_type = (ENUM_CALENDAR_EVENT_IMPACT)tokens[22];
    newsBT.country.id = (ulong)tokens[23];
    newsBT.country.name = tokens[24];
    newsBT.country.code = tokens[25];
    newsBT.country.currency = tokens[26];
    newsBT.country.currency_symbol = tokens[27];
    newsBT.country.url_name = tokens[28];

    return true;
  }

  return false;
}

void downloadNews()
{

  int fileHandle = FileOpen("news" + ".csv", FILE_WRITE | FILE_COMMON);

  if (fileHandle != INVALID_HANDLE)
  {

    MqlCalendarValue values[];

    if (CalendarValueHistory(values, StringToTime("01.01.1970"), TimeCurrent()))
    {

      for (int i = 0; i < ArraySize(values); i += 1)
      {

        MqlCalendarEvent event;

        if (CalendarEventById(values[i].event_id, event))
        {

          MqlCalendarCountry country;

          if (CalendarCountryById(event.country_id, country))
          {

            economicNews newsBT;
            createEconomicNews(event, values[i], country, newsBT);
            FileWrite(fileHandle, newsToString(newsBT));
          }
        }
      }
    }
  }

  FileClose(fileHandle);

  Print("End of news download ");
}

bool getBTnews(long period, economicNews &newsBT[])
{

  ArrayResize(newsBT, 0);
  int fileHandle = FileOpen("news" + ".csv", FILE_READ | FILE_COMMON);

  if (fileHandle != INVALID_HANDLE)
  {

    while (!FileIsEnding(fileHandle))
    {

      economicNews n;
      if (stringToNews(FileReadString(fileHandle), n))
      {

        if (n.value.time < TimeCurrent() + period && n.value.time > TimeCurrent() - period)
        {

          ArrayResize(newsBT, ArraySize(newsBT) + 1);
          newsBT[ArraySize(newsBT) - 1] = n;
        }
      }
    }

    FileClose(fileHandle);
    return true;
  }

  FileClose(fileHandle);
  return false;
}

int totalBarsCal;
void GetCalendarValue()
{
  if (!IsNewBar(PERIOD_D1, barsTotal1))
    return;
  if (MQLInfoInteger(MQL_TESTER))
  {
    ArrayFree(newsHist);
    getBTnews(PeriodSeconds(PERIOD_D1), newsHist);
    return;
  }
  datetime startTime = iTime(Symbol(), PERIOD_D1, 0);
  datetime endTime = startTime + PeriodSeconds(PERIOD_D1);
  ArrayFree(news);
  CalendarValueHistory(news, startTime, endTime, NULL, NULL);
}

string lastNewsEvent;
datetime iDay;
datetime holiDay;
int totalBarsEvent;
bool IsNewsEvent()
{
  if (!IsNewBar(InpFrequecy, barsTotal2) || upperLine > 0 || lowerLine > 0 || PositionCount() > 0)
    return false;

  if ((time.hour < InpStartHour && InpStartHour > 0) || (time.hour >= InpEndHour && InpEndHour > 0) )
    return false;

  if ((time.day_of_week == 0 && !InpSunday) || (time.day_of_week == 1 && !InpMonday) || (time.day_of_week == 2 && !InpTuesday) || (time.day_of_week == 3 && !InpWednesday) || (time.day_of_week == 4 && !InpThursday) || (time.day_of_week == 5 && !InpFriday) || (time.day_of_week == 6 && !InpSaturday))
    return false;

  iDay = iTime(Symbol(), PERIOD_D1, 0);
  if(holiDay==iDay)return false;

  GetCalendarValue();
  int amount = MQLInfoInteger(MQL_TESTER) ? ArraySize(newsHist) : ArraySize(news);
  for (int i = amount - 1; i >= 0; i--)
  {
    MqlCalendarEvent event;
    MqlCalendarValue value;
    MqlCalendarCountry country;

    if (MQLInfoInteger(MQL_TESTER))
    {
      event = newsHist[i].event;
      value = newsHist[i].value;
      country = newsHist[i].country;
    }
    else
    {
      CalendarEventById(news[i].event_id, event);
      CalendarValueById(news[i].id, value);
      CalendarCountryById(event.country_id, country);
    }
    
    if (!(country.currency == InpCurrency || InpCurrency == "" || InpCurrency == "ALL" || (InpCurrency == "SYMBOL" && (country.currency == SymbolInfoString(Symbol(), SYMBOL_CURRENCY_MARGIN) || country.currency == SymbolInfoString(Symbol(), SYMBOL_CURRENCY_BASE) || country.currency == SymbolInfoString(Symbol(), SYMBOL_CURRENCY_PROFIT)))))
      continue;
    if (event.type == CALENDAR_TYPE_HOLIDAY && (value.time > iDay && value.time < iDay+PeriodSeconds(PERIOD_D1))) {holiDay=iDay;return false;} 
    
    if (event.importance == CALENDAR_IMPORTANCE_NONE && !InpImportance_all) continue;
    if (event.importance == CALENDAR_IMPORTANCE_LOW && !InpImportance_low) continue;
    if (event.importance == CALENDAR_IMPORTANCE_MODERATE && !InpImportance_moderate) continue;
    if (event.importance == CALENDAR_IMPORTANCE_HIGH && !InpImportance_high) continue;
    
    if (value.time == iTime(Symbol(), PERIOD_M1, 0))
    {
      lastNewsEvent = country.currency +(string)event.importance +" "+ event.name+" "+(string)value.time;
      Print(lastNewsEvent);
      return true;
    }
  }
  return false;
}

bool arrayContains(string &arr[], string value)
{
  for (int i = ArraySize(arr) - 1; i >= 0; i--)
  {
    if (arr[i] == value)
      return true;
  }
  return false;
}

int barsTotal1, barsTotal2, barsTotal3;
bool IsNewBar(ENUM_TIMEFRAMES timeFrame, int &barsTotal)
{
  int bars = iBars(Symbol(), timeFrame);
  if (bars == barsTotal)
    return false;

  barsTotal = bars;
  return true;
}

double AtrValue(ENUM_TIMEFRAMES timeFrame)
{
  int atrHandle = iATR(Symbol(), timeFrame, 500);
  double atrBuffer[];
  ArraySetAsSeries(atrBuffer, true);
  CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
  
  double value = NormalizeDouble(atrBuffer[0],Digits());
  return value;
}

 double minVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
 double maxVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
double startCapital = AccountInfoDouble(ACCOUNT_BALANCE);
double Volume()
{
  double balance = InpFixedRisk ? startCapital : AccountInfoDouble(ACCOUNT_BALANCE);
  double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
  double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
  double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
  double riskMoney = balance * InpRisk * 0.01;
  double slDistance = AtrValue(InpTimeFrame);
  double moneyLotStep = slDistance / tickSize * tickValue * lotStep;
  double lots = MathRound(riskMoney / moneyLotStep) * lotStep;

  if (lots < minVol || lots == NULL)
  {
    lots = minVol;
  }

  return lots;
}

int PositionCount()
{
  int count = 0;
  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (!PositionSelectByTicket(ticket))
      continue;
    if (PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      continue;
    count++;
  }
  return count;
}

double calculatedZoneTime;
void CalculateZone()
{
  if(PositionCount() == 0 && TimeCurrent() > calculatedZoneTime) {
     upperLine = 0;
     lowerLine = 0;
    }
  if (PositionCount() > 0 || !IsNewsEvent())
    return;
  double fastEntry = AtrValue(InpFastEntry);
  calculatedZoneTime = TimeCurrent() + PeriodSeconds(InpFastEntry)/InpZoneTimeDivider;
  upperLine = NormalizeDouble(tick.ask + fastEntry, Digits());
  lowerLine = NormalizeDouble(tick.bid - fastEntry, Digits());
  Print("INFO: Calculated zone.");
}

void TakeTrade()
{
  int posC = PositionCount();
  if (posC > 0) return;
  if(holiDay==iDay && posC == 0)return;
  if ((upperLine == 0 || lowerLine == 0) || (tick.ask - tick.bid)*4 >= upperLine - lowerLine || (((time.hour < InpStartHour && InpStartHour > 0) || (time.hour >= InpEndHour && InpEndHour > 0)) && posC == 0))
    return;

  double lots = Volume();
  double range = AtrValue(InpTimeFrame);

  if (tick.ask >= upperLine) {
    
    while (lots > 0){
      trade.Buy(NormalizeDouble(lots > maxVol ? maxVol : lots, 2),NULL,0,upperLine-range,upperLine+range*InpRiskReward,lastNewsEvent);
      lots -= maxVol;
    }
  }
  if (tick.bid <= lowerLine) {
    while (lots > 0){
      trade.Sell(NormalizeDouble(lots > maxVol ? maxVol : lots, 2),NULL,0,lowerLine+range,lowerLine-range*InpRiskReward,lastNewsEvent);
      lots -= maxVol;
      
    }
  }
}

datetime drawStartTime=0;
void ShowLines()
{
  if (!InpShowLines) return;   
  if (upperLine > 0 && lowerLine > 0 )
{
    if(drawStartTime==0) drawStartTime = TimeCurrent();
    datetime drawStopTime = TimeCurrent();
    double range = AtrValue(InpTimeFrame);
    double tpPoints = range * InpRiskReward;
    
    int posC = PositionCount();
    // Create the rectangle for the range
    ObjectCreate(0, "rangeBox "+ (string)drawStartTime, OBJ_RECTANGLE, 0, drawStartTime, upperLine, drawStopTime, lowerLine);
    ObjectSetInteger(0, "rangeBox "+ (string)drawStartTime, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, "rangeBox "+ (string)drawStartTime, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, "rangeBox "+ (string)drawStartTime, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, "rangeBox "+ (string)drawStartTime, OBJPROP_BACK, true); // Set the box in the background
    ObjectSetInteger(0, "rangeBox "+ (string)drawStartTime, OBJPROP_FILL, true); // Fill the box

    // Create the upper TP box
    ObjectCreate(0, "rangeAboveBox "+ (string)drawStartTime, OBJ_RECTANGLE, 0, drawStartTime, upperLine, drawStopTime, upperLine+tpPoints);
    ObjectSetInteger(0, "rangeAboveBox "+ (string)drawStartTime, OBJPROP_COLOR, clrGreen);
    ObjectSetInteger(0, "rangeAboveBox "+ (string)drawStartTime, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, "rangeAboveBox "+ (string)drawStartTime, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, "rangeAboveBox "+ (string)drawStartTime, OBJPROP_BACK, true); // Set the box in the background
    ObjectSetInteger(0, "rangeAboveBox "+ (string)drawStartTime, OBJPROP_FILL, true); // Fill the box

    // Create the lower TP box
    ObjectCreate(0, "rangeBelowBox "+ (string)drawStartTime, OBJ_RECTANGLE, 0, drawStartTime, lowerLine, drawStopTime, lowerLine-tpPoints);
    ObjectSetInteger(0, "rangeBelowBox "+ (string)drawStartTime, OBJPROP_COLOR, clrGreen);
    ObjectSetInteger(0, "rangeBelowBox "+ (string)drawStartTime, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, "rangeBelowBox "+ (string)drawStartTime, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, "rangeBelowBox "+ (string)drawStartTime, OBJPROP_BACK, true); // Set the box in the background
    ObjectSetInteger(0, "rangeBelowBox "+ (string)drawStartTime, OBJPROP_FILL, true); // Fill the box
   }
   else
     {
         drawStartTime=0;
     }
}

void ShowInfo()
{
  if (InpShowInfo)
    Comment("Server time: ", TimeCurrent(), "\n",
            "Last price: ", tick.last, "\n",
            "Spread: ", NormalizeDouble(tick.ask-tick.bid,Digits()), "\n",
            "Range: ", AtrValue(InpTimeFrame), "\n",
            "Upper line: ", upperLine, "\n",
            "Lower line: ", lowerLine, "\n",
            "lots: ", NormalizeDouble(Volume(), 2), "\n"
            );
}

void Main()
{
  CalculateZone();
  TakeTrade();
  ShowLines();
  ShowInfo();
}
