#property copyright "Copyright 2024, gllsrssx Ltd."
#property link "https://www.rssx.be"
#property version "1.0"
#property description "PureNews is a trading robot that trades with the momentum of the news."

#include <Trade\Trade.mqh>
CTrade trade;

input group "========= General Settings =========";
input long InpMagicNumber = 88888888; // Magic number

input group "========= Risk Management =========";
input double InpRisk = 1.0;       // Risk size
input double InpRiskReward = 1.0; // Risk reward
input int InpBreakEven = 25;      // Breakeven (0 = off)

input group "========= Time Settings =========";
input ENUM_TIMEFRAMES InpTimeFrame = PERIOD_M5;  // Range period
input ENUM_TIMEFRAMES InpFastEntry = PERIOD_H2; // Entry period
input int InpZoneTimeDivider = 15;               // Minutes to enter

input group "========= Trading Hours =========";
input int InpStartHour = 2; // Start Hour (0 = off)
input int InpEndHour = 22;   // End Hour (0 = off)

input group "========= Display Settings =========";
input bool InpShowInfo = true;  // Show Info
input bool InpShowLines = true; // Show Range

struct economicNews
{
  MqlCalendarEvent event;
  MqlCalendarValue value;
  MqlCalendarCountry country;
};
economicNews news[];
MqlTick tick;
MqlDateTime time;

string symbolName = Symbol();
string currencyMargin = SymbolInfoString(symbolName, SYMBOL_CURRENCY_MARGIN);
string currencyBase = SymbolInfoString(symbolName, SYMBOL_CURRENCY_BASE);
string currencyProfit = SymbolInfoString(symbolName, SYMBOL_CURRENCY_PROFIT);
string lastNewsEvent;

datetime drawStartTime = 0;
datetime calculatedZoneTime;
datetime iDay;
datetime holiDay;

int barsTotalCalendar, barsTotalEvent;
int periodSecondsDay = PeriodSeconds(PERIOD_D1);
int positionCount = 0;

double maxlot = SymbolInfoDouble(symbolName, SYMBOL_VOLUME_MAX);
double ZoneTimeDivider = InpZoneTimeDivider * 60;
double upperLine, lowerLine, upperEntry, lowerEntry;
double minVol = SymbolInfoDouble(symbolName, SYMBOL_VOLUME_MIN);
double maxVol = SymbolInfoDouble(symbolName, SYMBOL_VOLUME_MAX);
double tickSize = SymbolInfoDouble(symbolName, SYMBOL_TRADE_TICK_SIZE);
double tickValue = SymbolInfoDouble(symbolName, SYMBOL_TRADE_TICK_VALUE);
double lotStep = SymbolInfoDouble(symbolName, SYMBOL_VOLUME_STEP);

int OnInit()

{

  if (TimeCurrent() > StringToTime("2025.01.01 00:00:00"))

  {

    Print("INFO: This is a demo version of the EA. It will only work until January 1, 2025.");

    ExpertRemove();
  }

  string messageSucces = "SUCCES: EA started successfully.";

  if (MQLInfoInteger(MQL_TESTER))
  {
    Print("INFO: Please run the EA in live mode first to download the history.");
    messageSucces = "INFO: This EA is for testing only. It will not trade live.";
  }
  else
    downloadNews();

  Print(messageSucces);
  Comment(messageSucces);

  trade.SetExpertMagicNumber(InpMagicNumber);
  return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)

{

  Print("INFO: EA stopped!");
}

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

void OnTick()
{
  TimeToStruct(TimeCurrent(), time);
  SymbolInfoTick(symbolName, tick);
  positionCount = PositionCount();

  TakeTrade();
  CalculateZone();
  MakeTradeBreakEven();
  ShowLines();
  ShowInfo();
}

void MakeTradeBreakEven()
{
  if (InpBreakEven == 0 || positionCount == 0)
    return;

  double offset = (upperLine - lowerLine) * InpBreakEven * 0.01;

  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (!PositionSelectByTicket(ticket))
      continue;
    if (PositionGetString(POSITION_SYMBOL) != symbolName || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      continue;

    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double stopLoss = PositionGetDouble(POSITION_SL);

    if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && stopLoss < openPrice)
    {
      if (tick.bid >= openPrice + offset)
      {
        trade.PositionModify(ticket, openPrice + tickSize, PositionGetDouble(POSITION_TP));
      }
    }
    else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && stopLoss > openPrice)
    {
      if (tick.ask <= openPrice - offset)
      {
        trade.PositionModify(ticket, openPrice - tickSize, PositionGetDouble(POSITION_TP));
      }
    }
  }
}

void GetCalendarValue()
{
  if (!IsNewBar(PERIOD_D1, barsTotalCalendar))
    return;
  ArrayFree(news);
  getBTnews(PeriodSeconds(PERIOD_D1), news);
}

bool IsNewsEvent()
{

  if (!IsNewBar(PERIOD_M1, barsTotalEvent) || upperLine > 0 || lowerLine > 0 || positionCount > 0 || (time.hour < InpStartHour && InpStartHour > 0) || (time.hour >= InpEndHour && InpEndHour > 0) || time.day_of_week == 0 || time.day_of_week == 6)
    return false;
  iDay = iTime(symbolName, PERIOD_D1, 0);
  if (holiDay == iDay)
    return false;
  GetCalendarValue();
  int amount = ArraySize(news);
  for (int i = amount - 1; i >= 0; i--)
  {
    MqlCalendarEvent event;
    MqlCalendarValue value;
    MqlCalendarCountry country;
    event = news[i].event;
    value = news[i].value;
    country = news[i].country;
    if (!(country.currency == currencyMargin || country.currency == currencyBase || country.currency == currencyProfit))
      continue;
    if (event.type == CALENDAR_TYPE_HOLIDAY && (value.time > iDay && value.time < iDay + periodSecondsDay))
    {
      holiDay = iDay;
      return false;
    }
    if (value.time != iTime(symbolName, PERIOD_M1, 0))
      continue;
    lastNewsEvent = country.currency + (string)event.importance + " " + event.name + " " + (string)value.time;
    return true;
  }
  return false;
}

bool IsNewBar(ENUM_TIMEFRAMES timeFrame, int &barsTotal)
{
  int bars = iBars(symbolName, timeFrame);
  if (bars == barsTotal)
    return false;
  barsTotal = bars;
  return true;
}

double AtrValue(ENUM_TIMEFRAMES timeframe)
{
  int atrHandle = iATR(symbolName, timeframe, 999);
  double atrBuffer[];
  ArraySetAsSeries(atrBuffer, true);
  CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
  return atrBuffer[0];
}

double Volume(double slDistance)
{
  double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRisk * 0.01;
  double moneyLotStep = slDistance / tickSize * tickValue * lotStep;
  double lots = MathRound(riskMoney / moneyLotStep) * lotStep;
  if (lots < minVol || lots == NULL)
    lots = minVol;
  else if (lots == maxVol)
    lots -= lotStep;
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
    if (PositionGetString(POSITION_SYMBOL) != symbolName || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || PositionGetDouble(POSITION_VOLUME) == maxVol)
      continue;
    count++;
  }
  return count;
}

void CalculateZone()
{
  datetime currentTime = TimeCurrent();
  if (positionCount == 0 && currentTime > calculatedZoneTime + ZoneTimeDivider && upperLine != 0 && lowerLine != 0)
  {
    upperLine = 0;
    lowerLine = 0;
    upperEntry = 0;
    lowerEntry = 0;
  }
  if (positionCount > 0 || !IsNewsEvent())
    return;
  double openPrice = iOpen(symbolName, PERIOD_M1, 0);
  double rangeValue = AtrValue(InpTimeFrame) / 2;
  double entryValue = AtrValue(InpFastEntry) / 2;
  upperLine = openPrice + rangeValue;
  lowerLine = openPrice - rangeValue;
  upperEntry = openPrice + entryValue;
  lowerEntry = openPrice - entryValue;
  calculatedZoneTime = currentTime;
}

void TakeTrade()
{
  double spread = (tick.ask - tick.bid) * 2;
  int currentHour = time.hour;
  if (holiDay == iDay || positionCount > 0 || upperEntry == 0 || lowerEntry == 0 || spread >= upperLine - lowerLine ||
      (currentHour < InpStartHour && InpStartHour > 0) || (currentHour >= InpEndHour && InpEndHour > 0))
    return;
  double diff = upperLine - lowerLine;
  double lots = Volume(diff);
  if (tick.ask >= upperEntry && tick.bid <= upperEntry + diff)
  {
    while (lots > 0)
    {
      trade.Buy(NormalizeDouble(lots > maxlot ? maxlot : lots, 2), NULL, 0, tick.ask - diff, tick.ask + diff, lastNewsEvent);
      lots -= maxlot;
    }
    if (positionCount == 0)
    {
      upperLine = tick.ask;
      lowerLine = tick.ask - diff;
      upperEntry = 0;
      lowerEntry = 0;
    }
  }
  if (tick.bid <= lowerEntry && tick.ask >= lowerEntry - diff)
  {
    while (lots > 0)
    {
      trade.Sell(NormalizeDouble(lots > maxlot ? maxlot : lots, 2), NULL, 0, tick.bid + diff, tick.bid - diff, lastNewsEvent);
      lots -= maxlot;
    }
    if (positionCount == 0)
    {
      lowerLine = tick.bid;
      upperLine = tick.bid + diff;
      upperEntry = 0;
      lowerEntry = 0;
    }
  }
}

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
    double ul = (positionCount == 0 && upperEntry > 0 ? upperEntry : upperLine);
    double ll = (positionCount == 0 && lowerEntry > 0 ? lowerEntry : lowerLine);
    color rc = (positionCount == 0 && upperEntry > 0 && lowerEntry > 0 ? clrRed : clrGold);
    color uc = (positionCount == 0 && upperEntry > 0 ? clrGreen : clrBlue);
    color lc = (positionCount == 0 && lowerEntry > 0 ? clrGreen : clrBlue);
    string stringTime = TimeToString(drawStartTime, TIME_DATE | TIME_MINUTES);
    CreateRectangle("range " + stringTime, drawStartTime, ul, drawStopTime, ll, clrRed);
    CreateRectangle("upper " + stringTime, drawStartTime, ul, drawStopTime, ul + tpPoints, uc);
    CreateRectangle("lower " + stringTime, drawStartTime, ll, drawStopTime, ll - tpPoints, lc);
  }
  else
  {
    drawStartTime = 0;
  }
}

void CreateRectangle(string name, datetime startTime, double startPrice, datetime stopTime, double stopPrice, color rectColor)
{
  ObjectCreate(0, name, OBJ_RECTANGLE, 0, startTime, startPrice, stopTime, stopPrice);
  ObjectSetInteger(0, name, OBJPROP_COLOR, rectColor);
  ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
  ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
  ObjectSetInteger(0, name, OBJPROP_BACK, true);
  ObjectSetInteger(0, name, OBJPROP_FILL, true);
}

void ShowInfo()
{
  if (!InpShowInfo)
    return;
  double tickLast = NormalizeDouble((tick.ask + tick.bid) / 2, Digits());
  int spread = (int)round((tick.ask - tick.bid) / Point());
  int range = (int)round(AtrValue(InpTimeFrame) / Point());
  int entry = (int)round(AtrValue(InpFastEntry) / Point());
  double volume = NormalizeDouble(Volume(AtrValue(InpTimeFrame)), 2);
  double upperLineNormalized = NormalizeDouble(upperLine, Digits());
  double lowerLineNormalized = NormalizeDouble(lowerLine, Digits());
  double upperEntryNormalized = NormalizeDouble(upperEntry, Digits());
  double lowerEntryNormalized = NormalizeDouble(lowerEntry, Digits());
  string timeCurrent = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);
  string commentText = "Server time: " + timeCurrent + "\n" +
                       "Last price: " + DoubleToString(tickLast, Digits()) + "\n" +
                       "Spread: " + IntegerToString(spread) + "\n" +
                       "Lots: " + DoubleToString(volume, 2) + "\n" +
                       "Range: " + IntegerToString(range) + "\n";
  if (upperLine > 0)
    commentText += "Upper line: " + DoubleToString(upperLineNormalized, Digits()) + "\n";
  if (lowerLine > 0)
    commentText += "Lower line: " + DoubleToString(lowerLineNormalized, Digits()) + "\n";
  if (upperEntry > 0)
    commentText += "Upper entry: " + DoubleToString(upperEntryNormalized, Digits()) + "\n";
  if (lowerEntry > 0)
    commentText += "Lower entry: " + DoubleToString(lowerEntryNormalized, Digits()) + "\n";
  commentText += "Entry: " + IntegerToString(entry) + "\n";
  Comment(commentText);
}
