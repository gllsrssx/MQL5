//+------------------------------------------------------------------+
//|                                                   newsHedger.mq5 |
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
input long InpMagicNumber = 88888;       // Magic number
input string InpCurrencies = "USD, EUR"; // Currencies
string currencies[];

input group "========= Risk settings =========";
input ENUM_TIMEFRAMES InpTimeFrame = PERIOD_M15; // Range timeframe
input bool fixedLot = true;                      // Fixed lot
input double InpRisk = 0.1;                      // Risk size
input double InpRiskMultiplier = 1.1;            // Risk multiplier
input double InpRiskReward = 4;                  // Risk reward

input group "========= Extra settings =========";
input int InpMaxHedges = 0;                // Max hedges(0 = unlimited)
input bool InpImportance_high = true;      // high news
input bool InpImportance_moderate = false; // moderate news

input group "========= Time filter =========";
input int InpStartHour = 0;   // Start Hour
input int InpStartMinute = 0; // Start Minute
input int InpEndHour = 23;    // End Hour
input int InpEndMinute = 59;  // End Minute

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
input bool debugPrint = false;       // Debug print

MqlCalendarValue news[];
MqlTick tick;

int atrHandle, barsTotalM1, barsTotalM5, barsTotalM15, barsTotalM30, barsTotalH1, barsTotalH4, barsTotalD1;
double upperLine, lowerLine;

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
  StringSplit(InpCurrencies, ',', currencies);
  for (int i = 0; i < ArraySize(currencies); i++)
  {
    StringTrimRight(currencies[i]);
    StringTrimLeft(currencies[i]);
    StringToUpper(currencies[i]);
  }

  atrHandle = iATR(Symbol(), InpTimeFrame, 999);

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
  Print("EA stopped!");
  Comment("EA stopped!");
}

void OnTick()
{
  SymbolInfoTick(Symbol(), tick);
  Hedger();
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

void GetCalendarValue()
{
  if (!IsNewBar(PERIOD_D1))
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

bool IsNewsEvent()
{
  if (!IsNewBar(PERIOD_M5))
    return false;

  MqlDateTime time;
  TimeToStruct(TimeCurrent(), time);
  if (time.hour < InpStartHour || time.hour > InpEndHour)
    return false;
  if (time.hour == InpStartHour && time.min < InpStartMinute)
    return false;
  if (time.hour == InpEndHour && time.min > InpEndMinute)
    return false;

  // check the day
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

    if (event.importance == CALENDAR_IMPORTANCE_NONE || event.importance == CALENDAR_IMPORTANCE_LOW)
      continue;
    if (event.importance == CALENDAR_IMPORTANCE_MODERATE && !InpImportance_moderate)
      continue;
    if (event.importance == CALENDAR_IMPORTANCE_HIGH && !InpImportance_high)
      continue;
    if (!arrayContains(currencies, country.currency) && ArraySize(currencies) != 0 && !arrayContains(currencies, "ALL"))
      continue;
    if (value.time == iTime(Symbol(), InpTimeFrame, 0))
    {
      if (IsNewBar(InpTimeFrame) && InpTimeFrame != PERIOD_M5 && InpTimeFrame != PERIOD_D1)
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

bool IsNewBar(ENUM_TIMEFRAMES timeFrame)
{
  int barsTotal;
  switch (timeFrame)
  {
  case PERIOD_M1:
    barsTotal = barsTotalM1;
    break;
  case PERIOD_M5:
    barsTotal = barsTotalM5;
    break;
  case PERIOD_M15:
    barsTotal = barsTotalM15;
    break;
  case PERIOD_M30:
    barsTotal = barsTotalM30;
    break;
  case PERIOD_H1:
    barsTotal = barsTotalH1;
    break;
  case PERIOD_H4:
    barsTotal = barsTotalH4;
    break;
  case PERIOD_D1:
    barsTotal = barsTotalD1;
    break;
  default:
    return false;
  }

  int bars = iBars(Symbol(), timeFrame);
  if (bars == barsTotal)
    return false;

  switch (timeFrame)
  {
  case PERIOD_M1:
    barsTotalM1 = bars;
    break;
  case PERIOD_M5:
    barsTotalM5 = bars;
    break;
  case PERIOD_M15:
    barsTotalM15 = bars;
    break;
  case PERIOD_M30:
    barsTotalM30 = bars;
    break;
  case PERIOD_H1:
    barsTotalH1 = bars;
    break;
  case PERIOD_H4:
    barsTotalH4 = bars;
    break;
  case PERIOD_D1:
    barsTotalD1 = bars;
    break;
  }

  return true;
}

double AtrValue()
{
  double atrBuffer[];
  ArraySetAsSeries(atrBuffer, true);
  CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
  return NormalizeDouble(atrBuffer[0], Digits());
}

double Volume()
{
  double slDistance = atrValue;
  double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
  double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
  double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
  double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRisk * 0.01;
  double moneyLotStep = slDistance / tickSize * tickValue * lotStep;
  double lots = MathRound(riskMoney / moneyLotStep) * lotStep;
  double minVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
  double maxVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
  if (lots < minVol)
  {
    Print(lots, " > Adjusted to minimum volume > ", minVol);
    lots = minVol;
  }
  else if (lots > maxVol)
  {
    Print(lots, " > Adjusted to minimum volume > ", maxVol);
    lots = maxVol;
  }
  if (fixedLot)
    lots = InpRisk;
  return lots;
}

int stats[9999][5];
int counter = 0;
int highestPosCount = 0;

double baseLots = 0;
double atrValue = 0;
void Hedger()
{
  if (PositionsTotal() > highestPosCount && debugPrint)
  {
    highestPosCount = PositionsTotal();
  }

  if (atrValue == 0)
  {
    atrValue = AtrValue();
    return;
  }
  double highestLotSize = 0;
  int lastDirection = 0;
  int totalProfitPoints = 0;
  int atrPoint = (int)round(atrValue / Point());
  int TpPoints = (int)round(atrPoint * InpRiskReward);
  int DistancePoints = atrPoint / 2;
  double LotsMultiplier = InpRiskMultiplier;

  int profitDistance = 0;
  double openBuyLots = 0;
  double openSellLots = 0;

  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (PositionSelectByTicket(ticket))
    {
      double posLots = PositionGetDouble(POSITION_VOLUME);

      if (posLots > highestLotSize)
      {
        highestLotSize = posLots;
        if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
          lastDirection = 1;
          profitDistance = (int)((tick.bid - PositionGetDouble(POSITION_PRICE_OPEN)) / Point());
        }
        else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
          lastDirection = -1;
          profitDistance = (int)((PositionGetDouble(POSITION_PRICE_OPEN) - tick.ask) / Point());
        }
      }

      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
        totalProfitPoints += (int)((tick.bid - PositionGetDouble(POSITION_PRICE_OPEN)) / Point());
        openBuyLots += posLots;
      }
      else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      {
        totalProfitPoints += (int)((PositionGetDouble(POSITION_PRICE_OPEN) - tick.ask) / Point());
        openSellLots += posLots;
      }
    }
  }

  if (profitDistance > TpPoints || (InpMaxHedges > 0 && PositionsTotal() > InpMaxHedges))
  {
    int posTotal = PositionsTotal();

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
      ulong ticket = PositionGetTicket(i);
      if (PositionSelectByTicket(ticket))
      {
        trade.PositionClose(ticket);
      }
    }

    int profitDistancePercent = (profitDistance * 100 / TpPoints);
    int decreasePerTrade = ((100 - profitDistancePercent) / posTotal);

    stats[counter][0] = posTotal;
    stats[counter][1] = totalProfitPoints;
    stats[counter][2] = profitDistance;
    stats[counter][3] = profitDistancePercent;
    stats[counter][4] = decreasePerTrade;
    counter++;

    for (int i = 0; i < counter; i++)
    {
      posTotal = stats[i][0];
      totalProfitPoints = stats[i][1];
      profitDistance = stats[i][2];
      profitDistancePercent = stats[i][3];
      decreasePerTrade = stats[i][4];

      if (debugPrint)
      {
        Print(" ");
        Print("Total positions: ", posTotal);
        Print("Total profit points: ", totalProfitPoints);
        Print("points away from last trade: ", profitDistance, " / ", TpPoints);
        Print("profitDistance percent: ", profitDistancePercent, "%");
        Print("decrease per trade: ", decreasePerTrade, "%");
        Print(" ");
      }
      // sort array by posTotal
      if (i < counter - 1 && posTotal > stats[i + 1][0])
      {
        int temp[5];
        for (int j = 0; j < 5; j++)
        {
          temp[j] = stats[i][j];
          stats[i][j] = stats[i + 1][j];
          stats[i + 1][j] = temp[j];
        }
      }
    }
    if (debugPrint)
      Print("Highest position count: ", highestPosCount);

    highestLotSize = 0;
    lastDirection = 0;
    upperLine = 0;
    lowerLine = 0;
  }

  if (highestLotSize == 0 && IsNewsEvent() && upperLine == 0 && lowerLine == 0)
  {
    atrValue = AtrValue() * 2;
    upperLine = tick.last + DistancePoints * Point();
    lowerLine = tick.last - DistancePoints * Point();
    baseLots = Volume();
  }

  if (upperLine > 0 && lowerLine > 0)
  {
    double lots = baseLots;

    if (tick.last > upperLine)
    {
      if (highestLotSize == 0 || lastDirection < 0)
      {
        if (highestLotSize > 0)
          lots = ((((InpRiskReward + 1) / InpRiskReward) * openSellLots - openBuyLots) * InpRiskMultiplier) + baseLots;

        trade.Buy(NormalizeDouble(lots, 2));
      }
    }
    else if (tick.last < lowerLine)
    {
      if (highestLotSize == 0 || lastDirection > 0)
      {
        if (highestLotSize > 0)
          lots = ((((InpRiskReward + 1) / InpRiskReward) * openBuyLots - openSellLots) * InpRiskMultiplier) + baseLots;

        trade.Sell(NormalizeDouble(lots, 2));
      }
    }
  }

  if (InpShowInfo)
    Comment("Server time: ", TimeCurrent(), "\n",
            "Upper line: ", upperLine, "\n",
            "Lower line: ", lowerLine, "\n",
            "Last price: ", tick.last, "\n",
            "Profit distance: ", profitDistance, " points / ", TpPoints, " points\n",
            "Last direction: ", lastDirection, "\n",
            "Base lots: ", baseLots, "\n",
            "Highest lot size: ", NormalizeDouble(highestLotSize, 2), "\n",
            "ATR value: ", atrValue, "\n");

  if (!InpShowLines)
    return;
  if (upperLine > 0)
  {
    ObjectCreate(0, "upperLine", OBJ_HLINE, 0, TimeCurrent(), upperLine);
    ObjectSetInteger(0, "upperLine", OBJPROP_COLOR, InpColorRange);
  }
  if (lowerLine > 0)
  {
    ObjectCreate(0, "lowerLine", OBJ_HLINE, 0, TimeCurrent(), lowerLine);
    ObjectSetInteger(0, "lowerLine", OBJPROP_COLOR, InpColorRange);
  }
  if (upperLine == 0 || lowerLine == 0)
  {
    ObjectDelete(0, "upperLine");
    ObjectDelete(0, "lowerLine");
  }
}