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
input double riskPercent = 0.1; // Risk percentage per trade

input int AtrPeriod = 120;   // Period for ATR
input int InpMaPeriod = 120; // MA period (0 = off)

input bool takeBuys = true;  // Flag to take buy positions
input bool takeSells = true; // Flag to take sell positions

// Global variables
double gridSize, firstUpperLevel, firstLowerLevel;
MqlTick lastTick;
int atrHandle, maHandle, lastMaDirection, periodSinceLastDirectionChange, maDirection, magicNumber = 68544651, arraySize = 10;
double levels[9];
bool levelBuy[9], levelSell[9];
double exitHigh = DBL_MAX, exitLow = 0;

// Initialization function
int OnInit()
{
    atrHandle = iATR(Symbol(), PERIOD_CURRENT, AtrPeriod);
    maHandle = iMA(Symbol(), Period(), InpMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
    // Initialize grid size
    gridSize = AtrValue();

    trade.SetExpertMagicNumber(magicNumber);
    return INIT_SUCCEEDED;
}

// Main execution function
void OnTick()
{
    if (gridSize == 0)
    {
        gridSize = AtrValue();
        return;
    }

    Comment("Grid Size: ", gridSize);

    SymbolInfoTick(Symbol(), lastTick);
    MA();
    Print("!MA Direction: ", maDirection);
    UpdateGridLevels();
    Print("Levels: ", levels[0], " ", levels[1], " ", levels[2], " ", levels[3], " ", levels[4], " ", levels[5], " ", levels[6], " ", levels[7], " ", levels[8]);
    ManageTrades();
    Print("Exit High: ", exitHigh, " Exit Low: ", exitLow);
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
    Print("UpdateGridLevels");
    firstUpperLevel = NormalizeDouble(MathCeil(lastTick.last / gridSize) * gridSize, Digits());

    Print("First Upper Level: ", firstUpperLevel);

    for (int i = 0; i < arraySize; i += 2)
    {
        levels[i] = NormalizeDouble(firstUpperLevel + (i * gridSize), Digits());
        levels[i + 1] = NormalizeDouble(firstLowerLevel - (i * gridSize), Digits());
        Print("Level ", i, ": ", levels[i], " Level ", i + 1, ": ", levels[i + 1]);
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
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlue);

    ChartRedraw();
}

// Function to manage trades based on grid levels
void ManageTrades()
{
    if (!CountPositions() > 0)
        PlaceOrders();

    UpdateTrades();
}

void UpdateTrades()
{
    if (!CountPositions() > 0)
        return;

    if (lastTick.last > exitHigh || lastTick.last < exitLow)
        CloseAllPositions();

    if (exitHigh == DBL_MAX || exitLow == 0 || exitHigh > levels[8] || exitLow < levels[9])
    {
        exitHigh = levels[8];
        exitLow = levels[9];
    }

    if (lastTick.last > levels[6])
    {
        exitLow = levels[4];
    }
    else if (lastTick.last > levels[4])
    {
        exitLow = levels[2];
    }
    else if (lastTick.last > levels[2])
    {
        exitLow = levels[0];
    }
    else if (lastTick.last < levels[7])
    {
        exitHigh = levels[5];
    }
    else if (lastTick.last < levels[5])
    {
        exitHigh = levels[3];
    }
    else if (lastTick.last < levels[3])
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
                    if (orderType == ORDER_TYPE_BUY)
                        levelBuy[j] = false;
                    else if (orderType == ORDER_TYPE_SELL)
                        levelSell[j] = false;
                }
            }
        }
    }

    // Place orders at all levels
    for (int i = 0; i < levelsCount; i++)
    {
        if (levelBuy[i] && takeBuys && (maDirection >= 0 || InpMaPeriod == 0))
        {
            if (levels[i] > lastTick.last)
                trade.BuyStop(Volume(), levels[i], Symbol(), 0, 0, ORDER_TIME_DAY, 0, "Level " + (string)i);
            else if (levels[i] < lastTick.last)
                trade.BuyLimit(Volume(), levels[i], Symbol(), 0, 0, ORDER_TIME_DAY, 0, "Level " + (string)i);
        }
        if (levelSell[i] && takeSells && (maDirection <= 0 || InpMaPeriod == 0))
        {
            if (levels[i] < lastTick.last)
                trade.SellStop(Volume(), levels[i], Symbol(), 0, 0, ORDER_TIME_DAY, 0, "Level " + (string)i);
            else if (levels[i] > lastTick.last)
                trade.SellLimit(Volume(), levels[i], Symbol(), 0, 0, ORDER_TIME_DAY, 0, "Level " + (string)i);
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

    int changePeriod = 24;
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
    ObjectSetInteger(0, "Ma " + (string)TimeCurrent(), OBJPROP_WIDTH, 4);
    ObjectSetInteger(0, "Ma " + (string)TimeCurrent(), OBJPROP_BACK, true);
    ObjectSetInteger(0, "Ma " + (string)TimeCurrent(), OBJPROP_COLOR, maDirection == 1 ? clrGreen : maDirection == -1 ? clrRed
                                                                                                                      : clrGold);

    ChartRedraw();
}
