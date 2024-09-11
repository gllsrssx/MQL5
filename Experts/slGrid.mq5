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
input int magicNumber = 85858; // Magic Number
input double riskPercent = 1.0; // Risk percent
input ENUM_TIMEFRAMES InpTimeFrame = PERIOD_CURRENT; //TimeFrame
input int AtrPeriod = 250;   // ATR Period

input int InpMaPeriod = 250; // MA Period
 int InpMaChangePeriod = InpMaPeriod/10; // MA Change
enum MA_DIRECTION_ENUM{
   MA_OFF,
   MA_BOTH,
   MA_RANGE,
   MA_TREND
};
input MA_DIRECTION_ENUM InpMaDirection = MA_OFF; // Ma Direction

input bool takeBuys = true;  // Long
input bool takeSells = true; // Short

input bool CommentFlag = false; // Comment

// Global variables
double gridSize, firstUpperLevel, firstLowerLevel;
MqlTick lastTick;
int atrHandle, maHandle, lastMaDirection, periodSinceLastDirectionChange, maDirection, arraySize = 10;
double levels[10];
bool levelBuy[10], levelSell[10];
double exitHigh = DBL_MAX, exitLow = 0;

// Initialization function
int OnInit()
{
    if (TimeCurrent() > StringToTime("2025.01.01 00:00:00") && !MQLInfoInteger(MQL_TESTER))
    {
      Print("INFO: This is a demo version of the EA. It will only work until January 1, 2025. Please contact dev: glls@rssx.be");
      ExpertRemove();
    }

    if(InpMaPeriod == 0 && InpMaDirection != MA_OFF){
      Print("MA VALUE TOO LOW, DISABLE MA OR SET VALUE > 0!");
      ExpertRemove();
    }  
    
    atrHandle = iATR(Symbol(), InpTimeFrame, AtrPeriod);
    maHandle = iMA(Symbol(), InpTimeFrame, InpMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
    // Initialize grid size
    gridSize = AtrValue();

    trade.SetExpertMagicNumber(magicNumber);
    return INIT_SUCCEEDED;
}

// Main execution function
void OnTick()
{
    MqlDateTime mdt;
    TimeCurrent(mdt);
    int hour = mdt.hour;
    if ((hour >= 22 || hour <= 2) && CountPositions() == 0)
    {
        CloseAllOrders();
        return;
    }

    if (gridSize == 0)
    {
        gridSize = AtrValue();
        return;
    }
    SymbolInfoTick(Symbol(), lastTick);
    lastTick.last = iClose(Symbol(),PERIOD_CURRENT,0);
    MA();
    UpdateGridLevels();
    ManageTrades();
   
    if(!CommentFlag)return;
    Comment(
        "time: ", lastTick.time, "\n",
        "Last: ", lastTick.last, "\n",
        "gridSize: ", gridSize, "\n",
        "Levels: ", levels[8], " | ", levels[1], "\n",
        "Levels: ", levels[6], " | ", levels[3], "\n",
        "Levels: ", levels[4], " | ", levels[5], "\n",
        "Levels: ", levels[2], " | ", levels[7], "\n",
        "Levels: ", levels[0], " | ", levels[9], "\n",
        "Exit: ", exitHigh, " | ", exitLow, "\n",
        "MaDirection: ", maDirection, "\n");
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
            if (PositionGetInteger(POSITION_MAGIC) != magicNumber || PositionGetString(POSITION_SYMBOL) != Symbol())
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
    ObjectCreate(0, name, OBJ_TREND, 0, iTime(NULL, Period(), 5), level, TimeCurrent() + PeriodSeconds(PERIOD_D1), level);
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
            if (PositionGetInteger(POSITION_MAGIC) != magicNumber || PositionGetString(POSITION_SYMBOL) != Symbol())
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
            if (OrderGetInteger(ORDER_MAGIC) != magicNumber || OrderGetString(ORDER_SYMBOL) != Symbol())
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
            if (OrderGetInteger(ORDER_MAGIC) != magicNumber || OrderGetString(ORDER_SYMBOL) != Symbol())
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
        if (levelBuy[i] && takeBuys && (InpMaDirection == MA_OFF || (InpMaDirection==MA_RANGE && maDirection == 0) || (InpMaDirection==MA_TREND && maDirection == 1) || (InpMaDirection==MA_BOTH && maDirection != -1)))
        {
            double tp = levels[i] + gridSize;
            if (levels[i] > lastTick.last)
                trade.BuyStop(Volume(), levels[i], Symbol(), 0, tp, 0, 0, "Level " + (string)i);
            else if (levels[i] < lastTick.last)
                trade.BuyLimit(Volume(), levels[i], Symbol(), 0, tp, 0, 0, "Level " + (string)i);
        }
        if (levelSell[i] && takeSells && (InpMaDirection == MA_OFF || (InpMaDirection==MA_RANGE && maDirection == 0) || (InpMaDirection==MA_TREND && maDirection == -1) || (InpMaDirection==MA_BOTH && maDirection != 1)))
        {
            double tp = levels[i] - gridSize;
            if (levels[i] < lastTick.last)
                trade.SellStop(Volume(), levels[i], Symbol(), 0, tp, 0, 0, "Level " + (string)i);
            else if (levels[i] > lastTick.last)
                trade.SellLimit(Volume(), levels[i], Symbol(), 0, tp, 0, 0, "Level " + (string)i);
        }
    }
}

double Volume()
{

    double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

    double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercent / 100;
    double moneyLotStep = gridSize / tickSize * tickValue * lotStep;

    double lots = MathFloor(riskMoney / moneyLotStep) * lotStep;

    double minVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);

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

void MA()
{
    if (InpMaPeriod <= 0)
        return;

    static int barsTotal;
    int bars = iBars(Symbol(), Period());
    if (barsTotal >= bars)
        return;
    barsTotal = bars;

    double ma[];
    ArraySetAsSeries(ma, true);
    CopyBuffer(maHandle, MAIN_LINE, 0, barsTotal, ma);

    double high = iHigh(Symbol(), 0, 1);
    double low = iLow(Symbol(), 0, 1);

    int newMaDirection = 0;
    if (low > ma[0])
        newMaDirection = 1;
    else if (high < ma[0])
        newMaDirection = -1;
    else
        newMaDirection = 0;

    if (newMaDirection != lastMaDirection)
    {
        periodSinceLastDirectionChange = 1;
        lastMaDirection = newMaDirection;
    }
    else
    {
        periodSinceLastDirectionChange++;
    }

    int changePeriod = InpMaChangePeriod;
    if (periodSinceLastDirectionChange >= changePeriod)
    {
        maDirection = newMaDirection;
    }
    else
    {
        maDirection = 0;
    }

    // draw ma
    ObjectCreate(0, "Ma " + (string)TimeCurrent(), OBJ_TREND, 0, TimeCurrent(), ma[0], iTime(NULL, Period(), 1), ma[1]);
    ObjectSetInteger(0, "Ma " + (string)TimeCurrent(), OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, "Ma " + (string)TimeCurrent(), OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, "Ma " + (string)TimeCurrent(), OBJPROP_BACK, true);
    ObjectSetInteger(0, "Ma " + (string)TimeCurrent(), OBJPROP_COLOR, maDirection == 1 ? clrGreen : maDirection == -1 ? clrRed
                                                                                                                      : clrGold);

    ChartRedraw();
}
