
#property copyright "Copyright 2024, GllsRssx Ltd."
#property link "https://www.rssx.eu"
#property version "2.0"
#property description "This EA starts a hedge trade with recovery zone when a news event is detected."

#include <Trade\Trade.mqh>
CTrade trade;

input group "========= General =========";
input long InpMagicNumber = 8888888; // Magic number
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


input group "========= Risk =========";
input double InpRisk = 0.1;                     // Risk size
input double InpRiskReward = 1.0;               // Risk reward
 double InpRiskMultiplier = 1;                 // Risk multiplier


input group "========= Advanced =========";
input int InpTimeFrame = 60; // Range time frame minutes
//input int InpTimeFrame = 30;                    // Range time frame minutes
// input int InpAtrPeriod = 1000;                  // ATR Period

input int InpFastEntry = 0; // fast entry minutes (0=off)
input ENUM_TIMEFRAMES InpFrequecy = PERIOD_M1; // trade frequency

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

input group "========= Extra =========";
input bool InpFastExitHedge = false; // fast exit
input bool InpBreakEvenHedge = false; // break even
input int InpStopOut = 0;   // Stop out (0 = off)
input int InpMaxHedges = 0; // Max hedges(0 = off)
 
input group "========= Time =========";
 int InpTimezone = 0;           // Timezone
input bool InpDaylightSaving = false; // DST zone
int DSToffset;                       // DST offset

input int InpStartHour = 6;  // Start Hour (0 = off)
input int InpEndHour = 18;    // End Hour (0 = off)
 int StartHour, EndHour;

input bool InpMonday = true;    // Monday
input bool InpTuesday = true;   // Tuesday
input bool InpWednesday = true; // Wednesday
input bool InpThursday = true;  // Thursday
input bool InpFriday = true;    // Friday
input bool InpSaturday = false; // Saturday
input bool InpSunday = false;   // Sunday

input group "========= Plot =========";
input bool InpShowInfo = true;       // Show Info
input bool InpShowLines = true;      // Show Range
//input color InpColorRange = clrBlue; // Range color

MqlCalendarValue news[];
MqlTick tick;
MqlDateTime time;

double upperLine, lowerLine, baseLots;

int OnInit()
{
  //long accountNumbers[] = {11028867, 7216275, 7222732, 10000973723, 11153072};
  //long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
  if (TimeCurrent() > StringToTime("2025.01.01 00:00:00") ) // || ArrayBsearch(accountNumbers, accountNumber) == -1)
  {
    Print("INFO: This is a demo version of the EA. It will only work until January 1, 2025.");
    //Print("The account " + (string)accountNumber + " is not authorized to use this EA.");
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
  //ObjectsDeleteAll(0);
  //ChartRedraw();
  MaxHedges();
  Print("MaxPos: ",maxPos);
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

datetime iDay;
datetime holiDay;
int totalBarsEvent;
bool IsNewsEvent()
{
  if (!IsNewBar(InpFrequecy, barsTotal2) || upperLine > 0 || lowerLine > 0 || PositionCount() > 0)
    return false;

  if ((time.hour < StartHour && InpStartHour > 0) || (time.hour >= EndHour && InpEndHour > 0) )
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

int barsTotal1, barsTotal2, barsTotal3;
bool IsNewBar(ENUM_TIMEFRAMES timeFrame, int &barsTotal)
{
  int bars = iBars(Symbol(), timeFrame);
  if (bars == barsTotal)
    return false;

  barsTotal = bars;
  return true;
}

//int atrPeriod = PeriodSeconds(InpTimeFrame <= PERIOD_D1? PERIOD_W1 : PERIOD_M4) / PeriodSeconds(InpTimeFrame);
double AtrValue()
{
  int atrHandle = iATR(Symbol(), PERIOD_H1, 480);
  double atrBuffer[];
  ArraySetAsSeries(atrBuffer, true);
  CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
  double value = atrBuffer[0] /60 *InpTimeFrame ;
  double result = NormalizeDouble(value,Digits());

  if (result <= 0 && time.hour > 1) Print(" WARNING: ATR malfunction. Please contact DEV. ");

  return result;
}

double startCapital = AccountInfoDouble(ACCOUNT_BALANCE);
double Volume(double slDistance)
{
  double balance = InpFixedRisk ? startCapital : AccountInfoDouble(ACCOUNT_BALANCE);
  double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
  double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
  double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
  double riskMoney = balance * InpRisk * 0.01;
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
  for (int i = PositionsTotal() - 1; i >= 0; i--)
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
  baseLots = Volume(upperLine-lowerLine);
  if (PositionCount() == 0) return baseLots;
  if (InpBreakEvenHedge && !InpFastExitHedge) baseLots=0;
  
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

  double RiskMultiplier = InpFastExitHedge && PositionCount()>0? 1 + (PositionCount()/2*0.1) : 1;
  if (lastDirection == 1)
  {
    return (((((InpRiskReward + 1) / InpRiskReward) * openBuyLots - openSellLots) + baseLots) * RiskMultiplier);
  }
  else if (lastDirection == -1)
  {
    return (((((InpRiskReward + 1) / InpRiskReward) * openSellLots - openBuyLots) + baseLots) * RiskMultiplier);
  }
  else
  {
    return baseLots;
  }
}

  double  PS1 = PeriodSeconds(PERIOD_H1) /60 * InpTimeFrame;
  double  PS2 = InpFastEntry > 0? PeriodSeconds(PERIOD_H1) /60 *InpFastEntry:PS1/2;
  double fastEntry = PS1/PS2;
datetime calculatedZoneTime;
double upperEntry, lowerEntry;
void CalculateZone()
{
  if(PositionCount() == 0 && TimeCurrent() > calculatedZoneTime+PS2 && upperLine != 0 && lowerLine != 0) {
     upperLine = 0;
     lowerLine = 0;
     upperEntry=0;
     lowerEntry=0;
    }
  if (PositionCount() > 0 || !IsNewsEvent())
    return;
  double atrValue = AtrValue()/2;
  if (atrValue<=0) Print("WARNING: ATR value = "+(string)atrValue);
  upperLine = NormalizeDouble(tick.last + atrValue, Digits());
  lowerLine = NormalizeDouble(tick.last - atrValue, Digits());
  calculatedZoneTime = TimeCurrent();
  upperEntry = NormalizeDouble(tick.last + (atrValue*2/fastEntry), Digits());
  lowerEntry = NormalizeDouble(tick.last - (atrValue*2/fastEntry), Digits());
  Print("INFO: Calculated zone.");
}

void TakeTrade()
{
   if(holiDay==iDay)return ;
   
  int posC = PositionCount();

  if ((upperLine == 0 || lowerLine == 0) || (tick.ask - tick.bid)*4 >= upperLine - lowerLine || (((time.hour < StartHour && InpStartHour > 0) || (time.hour >= EndHour && InpEndHour > 0)) && posC == 0))
    return;

  int lastDirection = GetLastDirection();
  double lots = GetPositionSize();
  double maxlot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
  
  if (tick.ask >= (posC == 0 ? upperEntry : upperLine) && lastDirection != 1) {
    while (lots > 0){
      trade.Buy(NormalizeDouble(lots > maxlot ? maxlot : lots, 2));
      lots -= maxlot;
      if(posC==0&&PositionCount()==1){double diff=upperLine-lowerLine; upperLine=upperEntry;lowerLine=upperEntry-diff;}
    }
  }
  if (tick.bid <= (posC == 0 ? lowerEntry : lowerLine) && lastDirection != -1) {
    while (lots > 0){
      trade.Sell(NormalizeDouble(lots > maxlot ? maxlot : lots, 2));
      lots -= maxlot;
      if(posC==0&&PositionCount()==1){double diff=upperLine-lowerLine; lowerLine=lowerEntry;upperLine=lowerEntry+diff;}
    }
  }
  
}

void CloseTrades()
{
  if (PositionCount() == 0)
    return;
   
  bool tradeLoss = ((AccountInfoDouble(ACCOUNT_EQUITY) <= AccountInfoDouble(ACCOUNT_BALANCE) * InpStopOut * 0.01 && InpStopOut > 0) || (InpMaxHedges > 0 && PositionCount() > InpMaxHedges));
  bool tradeWin = AccountInfoDouble(ACCOUNT_EQUITY) >= AccountInfoDouble(ACCOUNT_BALANCE) * (1 + InpRisk * InpRiskReward * 0.01);
  bool tradeBe = AccountInfoDouble(ACCOUNT_EQUITY) >= AccountInfoDouble(ACCOUNT_BALANCE) && PositionCount() >1 && InpBreakEvenHedge;
  
  if ( tradeLoss || tradeWin || tradeBe )
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
    upperEntry =0;
    lowerEntry=0;
  }
}

datetime drawStartTime=0;
void ShowLines()
{
  if (!InpShowLines) return;   
  if (upperLine > 0 && lowerLine > 0)
{
    if(drawStartTime==0) drawStartTime = TimeCurrent();
    datetime drawStopTime = TimeCurrent();
    double tpPoints = (upperLine - lowerLine) * InpRiskReward;
    
   // double middleL = (upperLine-lowerLine)/2 + lowerLine;
    
   // ObjectCreate(0,middleL, OBJ_HLINE, 0, drawStartTime, middleL);
    //ObjectSetInteger(0,middleL, OBJPROP_COLOR,clrBlue);
    int posC = PositionCount();
    double ul = (posC == 0 ? upperEntry : upperLine);
    double ll = (posC == 0 ? lowerEntry : lowerLine);
    // Create the rectangle for the range
    ObjectCreate(0, "rangeBox "+ (string)drawStartTime, OBJ_RECTANGLE, 0, drawStartTime, ul, drawStopTime, ll);
    ObjectSetInteger(0, "rangeBox "+ (string)drawStartTime, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, "rangeBox "+ (string)drawStartTime, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, "rangeBox "+ (string)drawStartTime, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, "rangeBox "+ (string)drawStartTime, OBJPROP_BACK, true); // Set the box in the background
    ObjectSetInteger(0, "rangeBox "+ (string)drawStartTime, OBJPROP_FILL, true); // Fill the box

    // Create the upper TP box
    ObjectCreate(0, "rangeAboveBox "+ (string)drawStartTime, OBJ_RECTANGLE, 0, drawStartTime, ul, drawStopTime, ul+tpPoints);
    ObjectSetInteger(0, "rangeAboveBox "+ (string)drawStartTime, OBJPROP_COLOR, clrGreen);
    ObjectSetInteger(0, "rangeAboveBox "+ (string)drawStartTime, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, "rangeAboveBox "+ (string)drawStartTime, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, "rangeAboveBox "+ (string)drawStartTime, OBJPROP_BACK, true); // Set the box in the background
    ObjectSetInteger(0, "rangeAboveBox "+ (string)drawStartTime, OBJPROP_FILL, true); // Fill the box

    // Create the lower TP box
    ObjectCreate(0, "rangeBelowBox "+ (string)drawStartTime, OBJ_RECTANGLE, 0, drawStartTime, ll, drawStopTime, ll-tpPoints);
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
            "ATR: ", AtrValue(), "\n",
            "Upper line: ", upperLine, "\n",
            "Lower line: ", lowerLine, "\n",
            "upper entry: ", upperEntry, "\n",
            "Lower enty: ", lowerEntry, "\n",
            "fast enty: ", fastEntry, "\n",
            "max pos: ", maxPos, "\n",
            "Last direction: ", GetLastDirection(), "\n",
            "lots: ", NormalizeDouble(baseLots, 2), "\n" );
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

int maxPos=0;
void Main()
{
  Hedger();
  DSTAdjust();
  
  int currPos = PositionCount();
  maxPos = currPos > maxPos ? currPos : maxPos;
}


// function to get DST offset
int DSTOffset()
{
  int offset = InpTimezone;
  if (!InpDaylightSaving)
    return offset;

  string current_date = TimeToString(TimeCurrent(), TIME_DATE); // gets result as "yyyy.mm.dd",
  long month = StringToInteger(StringSubstr(current_date, 5, 2));
  long day = StringToInteger(StringSubstr(current_date, 8, 2));

  // check if we are in DST
  int DST_start_month = 3; // March
  int DST_start_day = 11;  // average second Sunday
  int DST_end_month = 10;  // October
  int DST_end_day = 4;     // average first Sunday

  if (month > DST_start_month && month < DST_end_month)
  {
    offset++;
  }
  else if (month == DST_start_month && day > DST_start_day)
  {
    offset++;
  }
  else if (month == DST_end_month && day < DST_end_day)
  {
    offset++;
  }

  return offset;
}

void DSTAdjust()
{
  if (!IsNewBar(PERIOD_D1, barsTotal3))
    return;

  // get DST offset
  DSToffset = DSTOffset();

  // adjust range times
  StartHour = InpStartHour + DSToffset;       
  EndHour = InpEndHour + DSToffset; 
}
