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
input ENUM_TIMEFRAMES InpTimeFrame = PERIOD_M5; // Range period
input ENUM_TIMEFRAMES InpFastEntry = PERIOD_H2; // Entry period
input int InpZoneTimeDivider = 5;               // Minutes to enter

input group "========= Trading Hours =========";
input int InpStartHour = 2; // Start Hour (0 = off)
input int InpEndHour = 22;  // End Hour (0 = off)

input group "========= Display Settings =========";
input bool InpShowInfo = true;  // Show Info
input bool InpShowLines = true; // Show Range

MqlCalendarValue news[];
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

int barsTotalCalendar, barsTotalEvent, barsTradingAllowed;
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
  if (TimeCurrent() > StringToTime("2025.01.01 00:00:00") && !MQLInfoInteger(MQL_TESTER))
  {
    Comment("INFO: This is a demo version of the EA. It will only work until January 1, 2025.");
    Print("INFO: This is a demo version of the EA. It will only work until January 1, 2025.");
    ExpertRemove();
    return INIT_FAILED;
  }

  string messageSucces = "SUCCES: EA started successfully.";
  Print(messageSucces);
  Comment(messageSucces);

  trade.SetExpertMagicNumber(InpMagicNumber);
  return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
  Print("INFO: EA stopped!");
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

  if (IsNewBar(PERIOD_MN1, barsTradingAllowed) && TimeCurrent() > StringToTime("2025.01.01 00:00:00"))
    ExpertRemove();
}

void GetCalendarValue()
{
  if (!IsNewBar(PERIOD_D1, barsTotalCalendar))
    return;
  datetime startTime = iTime(symbolName, PERIOD_D1, 0);
  datetime endTime = startTime + PeriodSeconds(PERIOD_D1);
  ArrayFree(news);
  CalendarValueHistory(news, startTime, endTime, NULL, NULL);
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

    CalendarEventById(news[i].event_id, event);
    CalendarValueById(news[i].id, value);
    CalendarCountryById(event.country_id, country);

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
  if (tick.ask >= upperEntry && tick.ask < upperEntry + diff && tick.bid < upperEntry + diff)
  {
    while (lots > 0)
    {
      trade.Buy(NormalizeDouble(lots > maxlot ? maxlot : lots, 2), symbolName, 0, tick.ask - diff, tick.ask + diff, lastNewsEvent);
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
  if (tick.bid <= lowerEntry && tick.bid > lowerEntry - diff && tick.ask > lowerEntry - diff)
  {
    while (lots > 0)
    {
      trade.Sell(NormalizeDouble(lots > maxlot ? maxlot : lots, 2), symbolName, 0, tick.bid + diff, tick.bid - diff, lastNewsEvent);
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
