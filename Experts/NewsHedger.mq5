
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
input bool InpFixedRisk = false; // Fixed risk

input double InpRisk = 1.0;                      // Risk size
input double InpRiskReward = 1.0;                // Risk reward
input ENUM_TIMEFRAMES InpTimeFrame = PERIOD_M15; // Range time frame minutes
input ENUM_TIMEFRAMES InpFastEntry = PERIOD_H1;  // fast entry minutes
input double InpZoneTimeDivider = 10;            // Minutes to enter
input ENUM_TIMEFRAMES InpFrequency = PERIOD_M1;  // trade frequency
enum NEWS_IMPORTANCE_ENUM
{
  IMPORTANCE_ALL,     // ALL
  IMPORTANCE_HIGH,    // HIGH
  IMPORTANCE_MEDIUM,  // MEDIUM
  IMPORTANCE_LOW,     // LOW
  IMPORTANCE_BOTH,    // H&M
  IMPORTANCE_NOT_LOW, // NL
};
input NEWS_IMPORTANCE_ENUM InpImportance = IMPORTANCE_ALL; // News importance
bool InpImportance_high = InpImportance == IMPORTANCE_ALL || InpImportance == IMPORTANCE_HIGH || InpImportance == IMPORTANCE_BOTH || InpImportance == IMPORTANCE_NOT_LOW;
bool InpImportance_moderate = InpImportance == IMPORTANCE_ALL || InpImportance == IMPORTANCE_MEDIUM || InpImportance == IMPORTANCE_BOTH || InpImportance == IMPORTANCE_NOT_LOW;
bool InpImportance_low = InpImportance == IMPORTANCE_ALL || InpImportance == IMPORTANCE_LOW;
bool InpImportance_all = InpImportance == IMPORTANCE_ALL || InpImportance == IMPORTANCE_NOT_LOW;

input bool InpHedgeMore = false;      // increase tp with hedge
input bool InpBreakEvenHedge = false; // break even
input int InpStopOut = 0;             // Stop out (0 = off)
input int InpMaxHedges = 1;           // Max trades(0 = off)

input int InpStartHour = 2; // Start Hour (0 = off)
input int InpEndHour = 22;  // End Hour (0 = off)

bool InpMonday = true;    // Monday
bool InpTuesday = true;   // Tuesday
bool InpWednesday = true; // Wednesday
bool InpThursday = true;  // Thursday
bool InpFriday = true;    // Friday
bool InpSaturday = false; // Saturday
bool InpSunday = false;   // Sunday

input bool InpShowInfo = true;  // Show Info
input bool InpShowLines = true; // Show Range

MqlCalendarValue news[];
MqlTick tick;
MqlDateTime time;

double upperLine, lowerLine, baseLots;

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

  string messageSucces = "SUCCES: EA started successfully.";

  Print(messageSucces);
  Comment(messageSucces);
  return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
  MaxHedges();
  if (InpMaxHedges != 1)
    Print("maximum positions: ", maxPos);
  Print("Last news event: " + lastNewsEvent);
  Print("INFO: EA stopped!");
  if (!MQLInfoInteger(MQL_TESTER))
    Comment("INFO: EA stopped!");
}

void OnTick()
{
  TimeToStruct(TimeCurrent(), time);
  SymbolInfoTick(Symbol(), tick);
  tick.last = NormalizeDouble((tick.ask + tick.bid) / 2, Digits());
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
  if (!IsNewBar(InpFrequency, barsTotal2) || upperLine > 0 || lowerLine > 0 || PositionCount() > 0)
    return false;

  if ((time.hour < InpStartHour && InpStartHour > 0) || (time.hour >= InpEndHour && InpEndHour > 0))
    return false;

  if ((time.day_of_week == 0 && !InpSunday) || (time.day_of_week == 1 && !InpMonday) || (time.day_of_week == 2 && !InpTuesday) || (time.day_of_week == 3 && !InpWednesday) || (time.day_of_week == 4 && !InpThursday) || (time.day_of_week == 5 && !InpFriday) || (time.day_of_week == 6 && !InpSaturday))
    return false;

  iDay = iTime(Symbol(), PERIOD_D1, 0);
  if (holiDay == iDay)
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

    if (!(country.currency == InpCurrency || InpCurrency == "" || InpCurrency == "ALL" || (InpCurrency == "SYMBOL" && (country.currency == SymbolInfoString(Symbol(), SYMBOL_CURRENCY_MARGIN) || country.currency == SymbolInfoString(Symbol(), SYMBOL_CURRENCY_BASE) || country.currency == SymbolInfoString(Symbol(), SYMBOL_CURRENCY_PROFIT)))))
      continue;
    if (event.type == CALENDAR_TYPE_HOLIDAY && (value.time > iDay && value.time < iDay + PeriodSeconds(PERIOD_D1)))
    {
      holiDay = iDay;
      return false;
    }

    if (event.importance == CALENDAR_IMPORTANCE_NONE && !InpImportance_all)
      continue;
    if (event.importance == CALENDAR_IMPORTANCE_LOW && !InpImportance_low)
      continue;
    if (event.importance == CALENDAR_IMPORTANCE_MODERATE && !InpImportance_moderate)
      continue;
    if (event.importance == CALENDAR_IMPORTANCE_HIGH && !InpImportance_high)
      continue;

    if (value.time == iTime(Symbol(), PERIOD_M1, 0))
    {
      lastNewsEvent = country.currency + (string)event.importance + " " + event.name + " " + (string)value.time;
      // Print(lastNewsEvent);
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

double AtrValue(ENUM_TIMEFRAMES timeframe)
{
  int atrHandle = iATR(Symbol(), timeframe, 999);
  double atrBuffer[];
  ArraySetAsSeries(atrBuffer, true);
  CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
  double value = atrBuffer[0];
  double result = NormalizeDouble(value, Digits());

  if (result <= 0 && time.hour > 1)
    Print(" WARNING: ATR malfunction. Please contact DEV. ");

  return result;
}

double minVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
double maxVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
double startCapital = AccountInfoDouble(ACCOUNT_BALANCE);
double Volume(double slDistance)
{
  double balance = InpFixedRisk ? startCapital : AccountInfoDouble(ACCOUNT_BALANCE);
  double riskMoney = balance * InpRisk * 0.01;
  double moneyLotStep = slDistance / tickSize * tickValue * lotStep;
  double lots = MathRound(riskMoney / moneyLotStep) * lotStep;

  if (lots < minVol || lots == NULL)
  {
    lots = minVol;
  }
  if (lots == maxVol)
    lots -= lotStep;

  return lots;
}

int GetLastDirection()
{
  if (PositionCount() == 0)
    return 0;

  double buyLots = 0;
  double sellLots = 0;
  int lastDirection = 0;
  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (!PositionSelectByTicket(ticket))
      continue;
    if (PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      continue;

    double posLots = PositionGetDouble(POSITION_VOLUME);

    if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
    {
      buyLots += posLots;
    }
    else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
    {
      sellLots += posLots;
    }
  }
  if (buyLots > sellLots)
  {
    lastDirection = 1;
  }
  else if (buyLots < sellLots)
  {
    lastDirection = -1;
  }
  else
  {
    lastDirection = 0;
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
    if (PositionGetDouble(POSITION_VOLUME) == maxVol)
      continue;
    count++;
  }
  return count;
}

string RiskMultiplierString;
double GetPositionSize()
{
  int posC = PositionCount();
  baseLots = Volume(upperLine - lowerLine);
  if (posC == 0)
    return baseLots;
  if (InpBreakEvenHedge)
    baseLots = 0;

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

  double hedgeLots;
  double multDivider = 2;
  double advancedMultiplier = multDivider > posC ? 1 : NormalizeDouble(1 / (posC / multDivider), 2);
  // advancedMultiplier=1/(posC*0.1);
  double RiskMultiplier = InpHedgeMore ? (advancedMultiplier > 0.1 ? advancedMultiplier : 0.1) : 1;
  if (RiskMultiplier < 0.1)
  {
    RiskMultiplier = 0.01;
  }
  RiskMultiplierString = (string)RiskMultiplier;
  if (lastDirection == 1)
  {
    hedgeLots = NormalizeDouble((((((InpRiskReward + 1) / InpRiskReward) * openBuyLots - openSellLots) + baseLots) * RiskMultiplier), 2);
  }
  else if (lastDirection == -1)
  {
    hedgeLots = NormalizeDouble((((((InpRiskReward + 1) / InpRiskReward) * openSellLots - openBuyLots) + baseLots) * RiskMultiplier), 2);
  }
  else
  {
    hedgeLots = baseLots;
  }
  if (hedgeLots < minVol || hedgeLots == NULL)
  {
    // Print(hedgeLots, " > Adjusted to minimum volume > ", minVol);
    hedgeLots = minVol;
  }
  if (hedgeLots == maxVol)
    hedgeLots -= lotStep;

  return hedgeLots;
}

double ZoneTimeDivider = InpZoneTimeDivider * 60;
//  double  PS1 = PeriodSeconds(PERIOD_H1) /60 * InpTimeFrame;
//  double  PS2 = InpFastEntry > 0? PeriodSeconds(PERIOD_H1) /60 *InpFastEntry:PS1/2;
//  double fastEntry = PS1/PS2;
datetime calculatedZoneTime;
double upperEntry, lowerEntry;
void CalculateZone()
{
  if (PositionCount() == 0 && TimeCurrent() > calculatedZoneTime + ZoneTimeDivider && upperLine != 0 && lowerLine != 0)
  {
    upperLine = 0;
    lowerLine = 0;
    upperEntry = 0;
    lowerEntry = 0;
  }
  if (PositionCount() > 0 || !IsNewsEvent())
    return;
  //  double atrValue = AtrValue()/2;
  //  if (atrValue<=0) Print("WARNING: ATR value = "+(string)atrValue);
  double rangeValue = AtrValue(InpTimeFrame) / 2;
  double entryValue = AtrValue(InpFastEntry);
  upperLine = NormalizeDouble(tick.last + rangeValue, Digits());
  lowerLine = NormalizeDouble(tick.last - rangeValue, Digits());
  calculatedZoneTime = TimeCurrent();
  upperEntry = NormalizeDouble(tick.last + entryValue, Digits());
  lowerEntry = NormalizeDouble(tick.last - entryValue, Digits());
  // Print("INFO: Calculated zone.");
}

void TakeTrade()
{
  int posC = PositionCount();
  if (holiDay == iDay && posC == 0)
    return;

  if ((upperLine == 0 || lowerLine == 0) || (tick.ask - tick.bid) * 0.01 >= upperLine - lowerLine || (((time.hour < InpStartHour && InpStartHour > 0) || (time.hour >= InpEndHour && InpEndHour > 0)) && posC == 0))
    return;
  int lastDirection = GetLastDirection();
  double lots = GetPositionSize();
  double maxlot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
  double diff = upperLine - lowerLine;
  if (tick.ask >= (posC == 0 ? upperEntry : upperLine) && lastDirection != 1 && tick.bid <= (posC == 0 ? upperEntry + diff : upperLine + diff))
  {

    if (InpMaxHedges > 0 && posC >= InpMaxHedges)
    {
      CloseTrades();
      return;
    }
    while (lots > 0)
    {
      trade.Buy(NormalizeDouble(lots > maxlot ? maxlot : lots, 2), NULL, 0, 0, 0, lastNewsEvent);
      lots -= maxlot;
      if (posC == 0 && PositionCount() == 1)
      {
        upperLine = upperEntry;
        lowerLine = upperEntry - diff;
      }
    }
    Print(lastNewsEvent);
  }
  if (tick.bid <= (posC == 0 ? lowerEntry : lowerLine) && lastDirection != -1 && tick.ask >= (posC == 0 ? lowerEntry - diff : lowerLine - diff))
  {
    if (InpMaxHedges > 0 && posC >= InpMaxHedges)
    {
      CloseTrades();
      return;
    }
    while (lots > 0)
    {
      trade.Sell(NormalizeDouble(lots > maxlot ? maxlot : lots, 2), NULL, 0, 0, 0, lastNewsEvent);
      lots -= maxlot;
      if (posC == 0 && PositionCount() == 1)
      {
        lowerLine = lowerEntry;
        upperLine = lowerEntry + diff;
      }
    }
    Print(lastNewsEvent);
  }
}

void CloseTrades()
{
  if (PositionCount() == 0)
    return;

  int lastDirection = GetLastDirection();
  bool tradeLoss = ((AccountInfoDouble(ACCOUNT_EQUITY) <= AccountInfoDouble(ACCOUNT_BALANCE) * InpStopOut * 0.01 && InpStopOut > 0) || (InpMaxHedges > 0 && PositionCount() >= InpMaxHedges && ((lastDirection == 1 && tick.bid <= lowerLine) || (lastDirection == -1 && tick.ask >= upperLine))));
  bool tradeWin = AccountInfoDouble(ACCOUNT_EQUITY) >= AccountInfoDouble(ACCOUNT_BALANCE) * (1 + InpRisk * InpRiskReward * 0.01);
  bool tradeBe = AccountInfoDouble(ACCOUNT_EQUITY) >= AccountInfoDouble(ACCOUNT_BALANCE) && PositionCount() > 1 && InpBreakEvenHedge;

  if (tradeLoss || tradeWin || tradeBe)
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
    upperEntry = 0;
    lowerEntry = 0;
  }
}

datetime drawStartTime = 0;
void ShowLines()
{
  if (!InpShowLines)
    return;
  if (upperLine > 0 && lowerLine > 0)
  {
    if (drawStartTime == 0)
      drawStartTime = TimeCurrent();
    datetime drawStopTime = TimeCurrent();
    double tpPoints = (upperLine - lowerLine) * InpRiskReward;

    int posC = PositionCount();
    double ul = (posC == 0 ? upperEntry : upperLine);
    double ll = (posC == 0 ? lowerEntry : lowerLine);
    // Create the rectangle for the range
    ObjectCreate(0, "rangeBox " + (string)drawStartTime, OBJ_RECTANGLE, 0, drawStartTime, ul, drawStopTime, ll);
    ObjectSetInteger(0, "rangeBox " + (string)drawStartTime, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, "rangeBox " + (string)drawStartTime, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, "rangeBox " + (string)drawStartTime, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, "rangeBox " + (string)drawStartTime, OBJPROP_BACK, true); // Set the box in the background
    ObjectSetInteger(0, "rangeBox " + (string)drawStartTime, OBJPROP_FILL, true); // Fill the box

    // Create the upper TP box
    ObjectCreate(0, "rangeAboveBox " + (string)drawStartTime, OBJ_RECTANGLE, 0, drawStartTime, ul, drawStopTime, ul + tpPoints);
    ObjectSetInteger(0, "rangeAboveBox " + (string)drawStartTime, OBJPROP_COLOR, clrGreen);
    ObjectSetInteger(0, "rangeAboveBox " + (string)drawStartTime, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, "rangeAboveBox " + (string)drawStartTime, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, "rangeAboveBox " + (string)drawStartTime, OBJPROP_BACK, true); // Set the box in the background
    ObjectSetInteger(0, "rangeAboveBox " + (string)drawStartTime, OBJPROP_FILL, true); // Fill the box

    // Create the lower TP box
    ObjectCreate(0, "rangeBelowBox " + (string)drawStartTime, OBJ_RECTANGLE, 0, drawStartTime, ll, drawStopTime, ll - tpPoints);
    ObjectSetInteger(0, "rangeBelowBox " + (string)drawStartTime, OBJPROP_COLOR, clrGreen);
    ObjectSetInteger(0, "rangeBelowBox " + (string)drawStartTime, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, "rangeBelowBox " + (string)drawStartTime, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, "rangeBelowBox " + (string)drawStartTime, OBJPROP_BACK, true); // Set the box in the background
    ObjectSetInteger(0, "rangeBelowBox " + (string)drawStartTime, OBJPROP_FILL, true); // Fill the box
  }
  else
  {
    drawStartTime = 0;
  }
}

void ShowInfo()
{
  if (InpShowInfo)
    Comment("Server time: ", TimeCurrent(), "\n",
            "Last price: ", tick.last, "\n",
            "Spread: ", (int)(tick.ask - tick.bid) / Point(), "\n",
            "lots: ", NormalizeDouble(baseLots, 2), "\n",
            "Last direction: ", GetLastDirection(), "\n",
            "Range: ", (int)AtrValue(InpTimeFrame) / Point(), "\n",
            "entry: ", (int)AtrValue(InpFastEntry) / Point(), "\n"
                                                              "Upper line: ",
            upperLine, "\n",
            "Lower line: ", lowerLine, "\n",
            "upper entry: ", upperEntry, "\n",
            "Lower enty: ", lowerEntry, "\n"
            //"max pos: ", maxPos, "\n",
            // "multiplier: ", RiskMultiplierString, "\n"
    );
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

int maxPos = 0;
void Main()
{
  Hedger();

  if (InpMaxHedges <= 1)
    return;
  int currPos = PositionCount();
  maxPos = currPos > maxPos ? currPos : maxPos;
}
