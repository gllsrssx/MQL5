//+------------------------------------------------------------------+
//|                                                   NewsHedger.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property description "This EA starts a hedge trade when a high impact news event is detected."

#include <Trade\Trade.mqh>
CTrade trade;

input group "========= General settings =========";
input long InpMagicNumber = 88888; // Magic number
input int atrPeriod = 1000;         // ATR period
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

input group "========= Risk settings =========";
input ENUM_TIMEFRAMES InpTimeFrame = PERIOD_H1; // Range time frame
input double InpRisk = 0.25;                      // Risk size
input double InpRiskReward = 0.25;                // Risk reward
double InpRiskMultiplier = 0.9;            // Risk multiplier

input group "========= Extra settings =========";
input int InpStopOut = 0;  // Stop out (0 = off)
input int InpMaxHedges = 0; // Max hedges(0 = off)
enum NEWS_IMPORTANCE_ENUM
{
  IMPORTANCE_ALL,    // ALL
  IMPORTANCE_BOTH,   // HIGH and MEDIUM
  IMPORTANCE_HIGH,   // HIGH
  IMPORTANCE_MEDIUM, // MEDIUM
  IMPORTANCE_LOW     // LOW

};
input NEWS_IMPORTANCE_ENUM InpImportance = IMPORTANCE_HIGH; // News importance
bool InpImportance_high = InpImportance == IMPORTANCE_ALL || InpImportance == IMPORTANCE_HIGH || InpImportance == IMPORTANCE_BOTH;
bool InpImportance_moderate = InpImportance == IMPORTANCE_ALL || InpImportance == IMPORTANCE_MEDIUM || InpImportance == IMPORTANCE_BOTH;
bool InpImportance_low = InpImportance == IMPORTANCE_ALL || InpImportance == IMPORTANCE_LOW;

input group "========= Time filter =========";
input int InpStartHour = -1;   // Start Hour (-1 = off)
input int InpStartMinute = 0; // Start Minute
input int InpEndHour = -1;    // End Hour (-1 = off)
input int InpEndMinute = 0;  // End Minute

input bool InpMonday = true;    // Monday
input bool InpTuesday = true;   // Tuesday
input bool InpWednesday = true; // Wednesday
input bool InpThursday = true;  // Thursday
input bool InpFriday = true;    // Friday
input bool InpSaturday = false; // Saturday
input bool InpSunday = false;   // Sunday

input group "========= Plot settings =========";
input bool InpShowInfo = true;       // Show Info
input bool InpShowLines = true;      // Show Lines
input color InpColorRange = clrBlue; // Range color

MqlCalendarValue news[];
MqlTick tick;

int atrHandle;
double upperLine, lowerLine, baseLots;

int OnInit()
{
  long accountNumbers[] = {11028867, 7216275, 7222732, 10000973723, 11153072};
  long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
  if (ArrayBsearch(accountNumbers, accountNumber) == -1 || TimeCurrent() > StringToTime("2025.01.01 00:00:00"))
  {
    Print("This is a demo version of the EA. It will only work until January 1, 2025.");
    Print("The account " + (string)accountNumber + " is not authorized to use this EA.");
    ExpertRemove();
    return INIT_FAILED;
  }

  atrHandle = iATR(Symbol(), InpTimeFrame, atrPeriod);
  trade.SetExpertMagicNumber(InpMagicNumber);

  if (MQLInfoInteger(MQL_TESTER))
    Print("Please run the EA in real mode first to download the history.");
  else
    downloadNews();

  ObjectsDeleteAll(0);
  ChartRedraw();

  Comment("EA running successfully");
  Print("EA running successfully");
  return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
  ObjectsDeleteAll(0);
  ChartRedraw();
  MaxHedges();
  Print("EA stopped!");
  if (!MQLInfoInteger(MQL_TESTER))
    Comment("EA stopped!");
}

void OnTick()
{
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
  if (!IsNewBar1(PERIOD_D1))
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

int totalBarsEvent;
bool IsNewsEvent()
{
  if (PositionCount() > 0)
    return false;
  if (!IsNewBar2(PERIOD_M5))
    return false;

  MqlDateTime time;
  TimeToStruct(TimeCurrent(), time);
  if ((time.hour < InpStartHour || time.hour > InpEndHour) && InpStartHour > -1)
    return false;
  if (time.hour == InpStartHour && time.min < InpStartMinute && InpStartHour > -1)
    return false;
  if (time.hour == InpEndHour && time.min > InpEndMinute && InpEndHour > -1)
    return false;

  if ((time.day_of_week == 0 && !InpSunday) || (time.day_of_week == 1 && !InpMonday) || (time.day_of_week == 2 && !InpTuesday) || (time.day_of_week == 3 && !InpWednesday) || (time.day_of_week == 4 && !InpThursday) || (time.day_of_week == 5 && !InpFriday) || (time.day_of_week == 6 && !InpSaturday))
    return false;

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

    if (event.importance == CALENDAR_IMPORTANCE_NONE)
      continue;
    if (event.importance == CALENDAR_IMPORTANCE_LOW && !InpImportance_low)
      continue;
    if (event.importance == CALENDAR_IMPORTANCE_MODERATE && !InpImportance_moderate)
      continue;
    if (event.importance == CALENDAR_IMPORTANCE_HIGH && !InpImportance_high)
      continue;
    if (!(country.currency == InpCurrency || InpCurrency == "" || InpCurrency == "ALL" || (InpCurrency == "SYMBOL" && (country.currency == SymbolInfoString(Symbol(), SYMBOL_CURRENCY_MARGIN) || country.currency == SymbolInfoString(Symbol(), SYMBOL_CURRENCY_BASE) || country.currency == SymbolInfoString(Symbol(), SYMBOL_CURRENCY_PROFIT)))))
      continue;
    if (value.time == iTime(Symbol(), PERIOD_M5, 0))
    {
      Print("News event detected: ", country.currency, " ", event.name, " ", value.time, " ", event.importance);
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

int barsTotal1, barsTotal2;
bool IsNewBar1(ENUM_TIMEFRAMES timeFrame)
{
  int bars = iBars(Symbol(), timeFrame);
  if (bars == barsTotal1)
    return false;

  barsTotal1 = bars;
  return true;
}
bool IsNewBar2(ENUM_TIMEFRAMES timeFrame)
{
  int bars = iBars(Symbol(), timeFrame);
  if (bars == barsTotal2)
    return false;

  barsTotal2 = bars;
  return true;
}

double AtrValue()
{
  double atrBuffer[];
  ArraySetAsSeries(atrBuffer, true);
  CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
  double result = NormalizeDouble(atrBuffer[0], Digits());

  return result;
}

double Volume(double slDistance)
{
  double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
  double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
  double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
  double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRisk * 0.01;
  double moneyLotStep = slDistance / tickSize * tickValue * lotStep;
  double lots = MathRound(riskMoney / moneyLotStep) * lotStep;
  double minVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
  double maxVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);

  if (lots < minVol || lots == NULL)
  {
    Print(lots, " > Adjusted to minimum volume > ", minVol);
    lots = minVol;
  }
  else if (lots > maxVol)
  {
    Print(lots, " > Adjusted to maximum volume > ", maxVol);
    lots = maxVol;
  }

  return lots;
}

int GetLastDirection()
{
  if (PositionCount() == 0)
    return 0;

  double highestLotSize = 0;
  int lastDirection = 0;
  for (int i = PositionCount() - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (!PositionSelectByTicket(ticket))
      continue;
    if (PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      continue;

    double posLots = PositionGetDouble(POSITION_VOLUME);

    if (posLots <= highestLotSize)
      continue;

    highestLotSize = posLots;

    if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
    {
      lastDirection = 1;
    }
    else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
    {
      lastDirection = -1;
    }
  }
  return lastDirection;
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

double GetPositionSize()
{
  if (PositionCount() == 0)
  {
    baseLots = Volume(AtrValue());
    return baseLots;
  }

  int lastDirection = GetLastDirection();
  double openBuyLots = 0;
  double openSellLots = 0;

  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (!PositionSelectByTicket(ticket))
      continue;
    if (PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      continue;

    if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
    {
      openBuyLots += PositionGetDouble(POSITION_VOLUME);
    }
    else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
    {
      openSellLots += PositionGetDouble(POSITION_VOLUME);
    }
  }

  if (lastDirection == 1)
  {
    return (((((InpRiskReward + 1) / InpRiskReward) * openBuyLots - openSellLots) * 2 + baseLots) * InpRiskMultiplier);
  }
  else if (lastDirection == -1)
  {
    return (((((InpRiskReward + 1) / InpRiskReward) * openSellLots - openBuyLots) * 2 + baseLots) * InpRiskMultiplier);
  }
  else
  {
    return baseLots;
  }
}

void CalculateZone()
{
  if (PositionCount() > 0 || !IsNewsEvent())
    return;
  double atrValue = AtrValue();
  upperLine = NormalizeDouble(tick.last + atrValue, Digits());
  lowerLine = NormalizeDouble(tick.last - atrValue, Digits());
}

void TakeTrade()
{
  MqlDateTime time;
  TimeToStruct(TimeCurrent(), time);

  if (upperLine == 0 || lowerLine == 0 || ((tick.ask - tick.bid) * 2 > upperLine - lowerLine) || ((time.hour < InpStartHour || time.hour > InpEndHour || (time.hour == InpStartHour && time.min < InpStartMinute) || (time.hour == InpEndHour && time.min > InpEndMinute)) && InpStartHour > -1 && InpEndHour > -1) || (time.day_of_week == 0 && !InpSunday) || (time.day_of_week == 1 && !InpMonday) || (time.day_of_week == 2 && !InpTuesday) || (time.day_of_week == 3 && !InpWednesday) || (time.day_of_week == 4 && !InpThursday) || (time.day_of_week == 5 && !InpFriday) || (time.day_of_week == 6 && !InpSaturday))
    return;

  int lastDirection = GetLastDirection();
  double lots = GetPositionSize();

  if (tick.last > upperLine && lastDirection != 1)
  {
    trade.Buy(NormalizeDouble(lots, 2));
  }
  if (tick.last < lowerLine && lastDirection != -1)
  {
    trade.Sell(NormalizeDouble(lots, 2));
  }
}

void CloseTrades()
{
  if (PositionCount() == 0)
    return;

  if ((AccountInfoDouble(ACCOUNT_EQUITY) < AccountInfoDouble(ACCOUNT_BALANCE) * InpStopOut * 0.01 && InpStopOut > 0) || (InpMaxHedges > 0 && PositionCount() > InpMaxHedges) || AccountInfoDouble(ACCOUNT_EQUITY) > AccountInfoDouble(ACCOUNT_BALANCE) * (1 + InpRisk * InpRiskReward * 0.01))
  {
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
      ulong ticket = PositionGetTicket(i);
      if (!PositionSelectByTicket(ticket))
        continue;
      if (PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
        continue;

      trade.PositionClose(ticket);
    }
    upperLine = 0;
    lowerLine = 0;
  }
}
void ShowLines()
{
  if (!InpShowLines)
    return;
  if (upperLine > 0 && lowerLine > 0)
  {
    ObjectCreate(0, "upperLine", OBJ_HLINE, 0, TimeCurrent(), upperLine);
    ObjectSetInteger(0, "upperLine", OBJPROP_COLOR, InpColorRange);
    ObjectSetInteger(0, "upperLine", OBJPROP_STYLE, STYLE_DOT);

    ObjectCreate(0, "lowerLine", OBJ_HLINE, 0, TimeCurrent(), lowerLine);
    ObjectSetInteger(0, "lowerLine", OBJPROP_COLOR, InpColorRange);
    ObjectSetInteger(0, "lowerLine", OBJPROP_STYLE, STYLE_DOT);

    ObjectCreate(0, "middleLine", OBJ_HLINE, 0, TimeCurrent(), (upperLine + lowerLine) / 2);
    ObjectSetInteger(0, "middleLine", OBJPROP_COLOR, InpColorRange);
    ObjectSetInteger(0, "middleLine", OBJPROP_STYLE, STYLE_DASH);

    double tpPoints = ((upperLine - lowerLine) / 2) * InpRiskReward;
    ObjectCreate(0, "upperTP", OBJ_HLINE, 0, TimeCurrent(), upperLine + tpPoints);
    ObjectSetInteger(0, "upperTP", OBJPROP_COLOR, InpColorRange);
    ObjectSetInteger(0, "upperTP", OBJPROP_STYLE, STYLE_DASH);

    ObjectCreate(0, "lowerTP", OBJ_HLINE, 0, TimeCurrent(), lowerLine - tpPoints);
    ObjectSetInteger(0, "lowerTP", OBJPROP_COLOR, InpColorRange);
    ObjectSetInteger(0, "lowerTP", OBJPROP_STYLE, STYLE_DASH);
  }
   if (upperLine == 0 || lowerLine == 0)
   {
     ObjectDelete(0, "upperLine");
     ObjectDelete(0, "lowerLine");
     ObjectDelete(0, "middleLine");
     ObjectDelete(0, "upperTP");
     ObjectDelete(0, "lowerTP");
   }
}

void ShowInfo()
{
  if (InpShowInfo)
    Comment("Server time: ", TimeCurrent(), "\n",
            "Last price: ", tick.last, "\n",
            "Upper line: ", upperLine, "\n",
            "Lower line: ", lowerLine, "\n",
            "Last direction: ", GetLastDirection(), "\n",
            "lots: ", NormalizeDouble(baseLots, 2), "\n",
            "ATR: ", AtrValue(), "\n");
}

int MaxHedges()
{
  static int maxHedges = 0;
  int hedges = PositionCount();
  if (hedges < 1)
    return maxHedges;
  if (hedges > maxHedges)
    maxHedges = hedges;
  return maxHedges;
}

void Hedger()
{
  CloseTrades();
  CalculateZone();
  TakeTrade();
  ShowLines();
  ShowInfo();
}

void Main()
{
  Hedger();
}