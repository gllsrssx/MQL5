//+------------------------------------------------------------------+
//|                                                  RunawayGrid.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

// Input parameters
input int magicNumber = 85858;                       // Magic Number
input double riskPercent = 1.0;                      // Risk percent
input ENUM_TIMEFRAMES InpTimeFrame = PERIOD_CURRENT; // TimeFrame
int AtrPeriod = 999;                                 // ATR Period
int atrFilter = 4;                                   // ATR Filter
input ENUM_TIMEFRAMES MA_TimeFrame = PERIOD_CURRENT; // MA TimeFrame
ENUM_MA_METHOD MA_Method = MODE_EMA;                 // MA Method
ENUM_APPLIED_PRICE MA_Price = PRICE_CLOSE;           // MA Price
input int MA_Period = 20;                            // MA Period
input int changePeriod = 5;                          // Change Period
enum MA_DIRECTION_ENUM
{
    MA_OFF,
    MA_BOTH,
    MA_RANGE,
    MA_TREND
};
input MA_DIRECTION_ENUM InpMaDirection = MA_RANGE; // Ma Direction

input bool takeBuys = true;  // Long
input bool takeSells = true; // Short

input bool CommentFlag = true; // Comment

input bool NewsFilter = true; // News filter
input ENUM_TIMEFRAMES LowNewsTimeFrame = PERIOD_M5;
input ENUM_TIMEFRAMES MediumNewsTimeFrame = PERIOD_M15;
input ENUM_TIMEFRAMES HighNewsTimeFrame = PERIOD_H1;

// Global variables
double gridSize, firstUpperLevel, firstLowerLevel;
MqlTick lastTick;
int atrHandle, arraySize = 10;
double levels[10];
bool levelBuy[10], levelSell[10];
double exitHigh = DBL_MAX, exitLow = 0;
MqlCalendarValue news[];

string symbolName = Symbol();

// Initialization function
int OnInit()
{
    if (TimeCurrent() > StringToTime("2025.01.01 00:00:00") && !MQLInfoInteger(MQL_TESTER))
    {
        Print("INFO: This is a demo version of the EA. It will only work until January 1, 2025. Please contact dev: glls@rssx.be");
        ExpertRemove();
    }

    if (MQLInfoInteger(MQL_TESTER))
        Print("INFO: Please run the EA in real mode first to download the history.");
    else
        downloadNews();

    if (MA_Period == 0 && InpMaDirection != MA_OFF)
    {
        Print("MA VALUE TOO LOW, DISABLE MA OR SET VALUE > 0!");
        ExpertRemove();
    }

    atrHandle = iATR(symbolName, InpTimeFrame, AtrPeriod);
    // maHandle = iMA(symbolName, InpTimeFrame, MA_Period, 0, MA_Method, MA_Price);
    //  Initialize grid size
    gridSize = NormalizeDouble(AtrValue(), Digits());

    trade.SetExpertMagicNumber(magicNumber);
    return INIT_SUCCEEDED;
}
bool newsFlag;
int barsTotalNewsEvent;
void OnTick()
{
    MqlDateTime mdt;
    TimeCurrent(mdt);
    int hour = mdt.hour;
    MovingAverage();
    SymbolInfoTick(symbolName, lastTick);
    lastTick.last = iClose(symbolName, PERIOD_CURRENT, 0);
    if (IsNewBar(PERIOD_M1, barsTotalNewsEvent))
        newsFlag = IsNewsEvent();
    CommentFunction();
    if (((hour >= 22 || hour < 2) && CountPositions() == 0) || (CountPositions() == 0 && newsFlag && NewsFilter) || gridSize == 0)
    {
        CloseAllOrders();
        gridSize = NormalizeDouble(AtrValue(), Digits());
        return;
    }
    UpdateGridLevels();
    ManageTrades();
}

void CommentFunction()
{
    if (!CommentFlag)
        return;
    Comment(
        "time: ", lastTick.time, "\n",
        "Last: ", lastTick.last, "\n",
        "gridSize: ", gridSize * Point(), "\n",
        "Levels: ", levels[8], " | ", levels[1], "\n",
        "Levels: ", levels[6], " | ", levels[3], "\n",
        "Levels: ", levels[4], " | ", levels[5], "\n",
        "Levels: ", levels[2], " | ", levels[7], "\n",
        "Levels: ", levels[0], " | ", levels[9], "\n",
        "Exit: ", exitHigh, " | ", exitLow, "\n",
        "MaDirection: ", lastDirection, "\n",
        "news: ", newsFlag, "\n");
}

// Function to calculate ATR based grid size
double AtrValue()
{
    double atrArray[];
    ArraySetAsSeries(atrArray, true);
    CopyBuffer(atrHandle, 0, 0, 1, atrArray);
    return NormalizeDouble(atrArray[0], Digits());
}

int CountPositions()
{
    int count = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket > 0)
        {
            if (PositionGetInteger(POSITION_MAGIC) != magicNumber || PositionGetString(POSITION_SYMBOL) != symbolName)
                continue;
            count++;
        }
    }
    return count;
}

void UpdateGridLevels()
{
    if (CountPositions() > 0)
        return;

    firstUpperLevel = NormalizeDouble(MathCeil(lastTick.last / gridSize) * gridSize, Digits());

    int count = 0;
    for (int i = 0; i < arraySize; i += 2)
    {
        levels[i] = NormalizeDouble(firstUpperLevel + count * gridSize, Digits());
        levels[i + 1] = NormalizeDouble(firstUpperLevel - (count + 1) * gridSize, Digits());
        count++;
    }

    // draw grid levels
    for (int i = 0; i < arraySize; i++)
    {
        DrawGridLevels("GridLevel " + (string)i, levels[i]);
    }
}

void DrawGridLevels(string name, double level)
{
    ObjectCreate(0, name, OBJ_TREND, 0, iTime(symbolName, Period(), 5), level, TimeCurrent() + PeriodSeconds(PERIOD_D1), level);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlue);
    ObjectSetString(0, name, OBJPROP_TEXT, name);

    ChartRedraw();
}

// Function to manage trades based on grid levels
void ManageTrades()
{
    if (CountPositions() == 0)
        PlaceOrders();

    UpdateTrades();
}

void UpdateTrades()
{
    if (CountPositions() == 0)
        return;

    if (lastTick.last > exitHigh || lastTick.last < exitLow)
        CloseAllPositions();

    if (exitHigh == DBL_MAX || exitLow == 0 || exitHigh > levels[8] || exitLow < levels[9])
    {
        exitHigh = levels[8];
        exitLow = levels[9];
    }

    if (lastTick.last > levels[6] && exitLow < levels[4])
    {
        exitLow = levels[4];
    }
    else if (lastTick.last > levels[4] && exitLow < levels[2])
    {
        exitLow = levels[2];
    }
    else if (lastTick.last > levels[2] && exitLow < levels[0])
    {
        exitLow = levels[0];
    }

    if (lastTick.last < levels[7] && exitHigh > levels[5])
    {
        exitHigh = levels[5];
    }
    else if (lastTick.last < levels[5] && exitHigh > levels[3])
    {
        exitHigh = levels[3];
    }
    else if (lastTick.last < levels[3] && exitHigh > levels[1])
    {
        exitHigh = levels[1];
    }
}

void CloseAllPositions()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket > 0)
        {
            if (PositionGetInteger(POSITION_MAGIC) != magicNumber || PositionGetString(POSITION_SYMBOL) != symbolName)
                continue;
            trade.PositionClose(ticket);
        }
    }

    CloseAllOrders();
}

void CloseAllOrders()
{
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if (ticket > 0)
        {
            if (OrderGetInteger(ORDER_MAGIC) != magicNumber || OrderGetString(ORDER_SYMBOL) != symbolName)
                continue;
            trade.OrderDelete(ticket);
        }
    }
}

// Function to place an order
void PlaceOrders()
{
    if (CountPositions() > 0)
        return;

    exitLow = 0;
    exitHigh = DBL_MAX;
    int levelsCount = arraySize;

    // Initialize level flags
    for (int i = 0; i < 10; i++)
    {
        levelBuy[i] = true;
        levelSell[i] = true;
    }

    // Check if there are orders on the grid levels
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if (ticket > 0)
        {
            if (OrderGetInteger(ORDER_MAGIC) != magicNumber || OrderGetString(ORDER_SYMBOL) != symbolName)
                continue;

            double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
            long orderType = OrderGetInteger(ORDER_TYPE);

            // Check if the order is at any of the levels
            for (int j = 0; j < levelsCount; j++)
            {
                if (orderPrice == levels[j])
                {
                    if (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT)
                        levelBuy[j] = false;
                    else if (orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_STOP || orderType == ORDER_TYPE_SELL_LIMIT)
                        levelSell[j] = false;
                }
            }
        }
    }

    // Place orders at all levels
    for (int i = 0; i < levelsCount; i++)
    {
        if (levelBuy[i] && takeBuys && (InpMaDirection == MA_OFF || (InpMaDirection == MA_RANGE && lastDirection == 0) || (InpMaDirection == MA_TREND && lastDirection == 1) || (InpMaDirection == MA_BOTH && lastDirection != -1)))
        {
            double tp = levels[i] + gridSize;
            if (levels[i] > lastTick.last)
                trade.BuyStop(Volume(), levels[i], symbolName, 0, tp, 0, 0, "Level " + (string)i);
            else if (levels[i] < lastTick.last)
                trade.BuyLimit(Volume(), levels[i], symbolName, 0, tp, 0, 0, "Level " + (string)i);
        }
        if (levelSell[i] && takeSells && (InpMaDirection == MA_OFF || (InpMaDirection == MA_RANGE && lastDirection == 0) || (InpMaDirection == MA_TREND && lastDirection == -1) || (InpMaDirection == MA_BOTH && lastDirection != 1)))
        {
            double tp = levels[i] - gridSize;
            if (levels[i] < lastTick.last)
                trade.SellStop(Volume(), levels[i], symbolName, 0, tp, 0, 0, "Level " + (string)i);
            else if (levels[i] > lastTick.last)
                trade.SellLimit(Volume(), levels[i], symbolName, 0, tp, 0, 0, "Level " + (string)i);
        }
    }
}

double Volume()
{

    double tickSize = SymbolInfoDouble(symbolName, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(symbolName, SYMBOL_TRADE_TICK_VALUE);
    double lotStep = SymbolInfoDouble(symbolName, SYMBOL_VOLUME_STEP);

    double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercent / 100;
    double moneyLotStep = gridSize / tickSize * tickValue * lotStep;

    double lots = MathFloor(riskMoney / moneyLotStep) * lotStep;

    double minVol = SymbolInfoDouble(symbolName, SYMBOL_VOLUME_MIN);
    double maxVol = SymbolInfoDouble(symbolName, SYMBOL_VOLUME_MAX);

    if (lots < minVol)
    {
        lots = minVol;
        Print(lots, " Adjusted to minimum volume ", minVol);
    }
    else if (lots > maxVol)
    {
        lots = maxVol;
        Print(lots, " Adjusted to maximum volume ", maxVol);
    }

    return lots;
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

int barsTotalCalendarValue;
void GetCalendarValue()
{
    if (!IsNewBar(PERIOD_D1, barsTotalCalendarValue))
        return;
    if (MQLInfoInteger(MQL_TESTER))
    {
        ArrayFree(newsHist);
        getBTnews(PeriodSeconds(PERIOD_D1), newsHist);
        return;
    }
    datetime startTime = iTime(symbolName, PERIOD_D1, 0);
    datetime endTime = startTime + PeriodSeconds(PERIOD_D1);
    ArrayFree(news);
    CalendarValueHistory(news, startTime, endTime, symbolName, symbolName);
}

string lastNewsEvent;
datetime iDay;
datetime holiDay;
int totalBarsEvent;
bool IsNewsEvent()
{
    GetCalendarValue();
    int amount = MQLInfoInteger(MQL_TESTER) ? ArraySize(newsHist) : ArraySize(news);
    if (amount == 0)
        Print("No news downloaded.");
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

        if (!(country.currency == SymbolInfoString(symbolName, SYMBOL_CURRENCY_MARGIN) || country.currency == SymbolInfoString(symbolName, SYMBOL_CURRENCY_BASE) || country.currency == SymbolInfoString(symbolName, SYMBOL_CURRENCY_PROFIT)))
            continue;

        int importanceTime = 1;

        if (event.importance == CALENDAR_IMPORTANCE_NONE)
            continue;
        if (event.importance == CALENDAR_IMPORTANCE_LOW)
            importanceTime = PeriodSeconds(LowNewsTimeFrame);
        if (event.importance == CALENDAR_IMPORTANCE_MODERATE)
            importanceTime = PeriodSeconds(MediumNewsTimeFrame);
        if (event.importance == CALENDAR_IMPORTANCE_HIGH)
            importanceTime = PeriodSeconds(HighNewsTimeFrame);

        if (value.time <= TimeCurrent() + importanceTime && value.time >= TimeCurrent() - importanceTime)
            return true;
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

bool IsNewBar(ENUM_TIMEFRAMES timeFrame, int &barsTotal)
{
    int bars = iBars(symbolName, timeFrame);
    if (bars == barsTotal)
        return false;

    barsTotal = bars;
    return true;
}

int barsTotalMovingAverage;
int lastDirection;
double ma_value;
void MovingAverage()
{
    if (MA_Period <= 0)
        return;
    int maHandle = iMA(symbolName, MA_TimeFrame, MA_Period, 0, MA_Method, MA_Price);
    double maBuffer[];
    ArraySetAsSeries(maBuffer, true);
    CopyBuffer(maHandle, 0, 0, changePeriod * 2, maBuffer);
    ma_value = NormalizeDouble(maBuffer[0], Digits());
    IsNewBar(MA_TimeFrame, barsTotalMovingAverage);
    for (int i = 0; i < changePeriod; i++)
    {
        double close = iClose(symbolName, MA_TimeFrame, i);
        double ma = maBuffer[i];
        int direction = close > ma ? 1 : close < ma ? -1
                                                    : 0;
        if (i == 0)
            lastDirection = direction;
        if (direction != lastDirection)
            lastDirection = 0;

        datetime start_time = iTime(symbolName, MA_TimeFrame, i);
        datetime end_time = start_time + PeriodSeconds(MA_TimeFrame);
        ObjectCreate(0, "Ma " + (string)start_time, OBJ_TREND, 0, start_time, maBuffer[i + 1], end_time, ma);
        ObjectSetInteger(0, "Ma " + (string)start_time, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, "Ma " + (string)start_time, OBJPROP_WIDTH, 4);
        ObjectSetInteger(0, "Ma " + (string)start_time, OBJPROP_BACK, true);
        ObjectSetInteger(0, "Ma " + (string)start_time, OBJPROP_COLOR, lastDirection == 1 ? clrGreen : lastDirection == -1 ? clrRed
                                                                                                                           : clrBlue);
    }
}
