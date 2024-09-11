//+------------------------------------------------------------------+
//|                                                   SimpleGrid.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

// Define the indicator and input parameters
input group "========= Risk settings =========";
input double riskPercent = 0.01;
input bool trailGrid = false; // Flag to enable trailing stop loss
input int maxGridAway = 0;   // close X away
input group "========= Grid settings =========";
input int AtrPeriod = 999;       // atr grid size
input double gridMultiplier = 1; // grid size multiplier
input bool takeBuys = true;      // take buys
input bool takeSells = true;     // take sells
input group "========= MA settings =========";
input int maPeriod = 0;  // ma period
input int maDivider = 0; // ma divider

double currentPrice, gridSize, firstUpperLevel, firstLowerLevel, secondUpperLevel, secondLowerLevel;
double maxDrawDownAmount, maxDrawDownPercentage, profitAmount, profitPercentage;
double bid, ask, spread;

int barsTotal;

// Define handles
int atrHandle;
int maHandle;

int maDirection = 0;
int lastMaDirection = 0;
int periodSinceLastDirectionChange = 0;
datetime previousTime = TimeCurrent();

bool isTrailing = false, longTrailing = false, shortTrailing = false;
double startPrice = 0, longTrailPrice = 0, shortTrailPrice = 0, longTrailFirstLevel = 0, longTrailSecondLevel = 0, longTrailThirdLevel = 0, longTrailFourthLevel = 0, shortTrailFirstLevel = 0, shortTrailSecondLevel = 0, shortTrailThirdLevel = 0, shortTrailFourthLevel = 0;
int symbolPosCount = 0;

// Define the OnInit function
int OnInit()
{
    barsTotal = iBars(Symbol(), PERIOD_CURRENT);

    if (maPeriod > 0)
        maHandle = iMA(Symbol(), PERIOD_CURRENT, maPeriod, 0, MODE_EMA, PRICE_CLOSE);

    return (INIT_SUCCEEDED);
}

// Define the OnDeinit function, make it delete all objects created by the indicator and close all orders
void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0, "firstUpperLevel");
    ObjectsDeleteAll(0, "firstLowerLevel");
    ObjectsDeleteAll(0, "secondUpperLevel");
    ObjectsDeleteAll(0, "secondLowerLevel");
    for (int j = 0; j < OrdersTotal(); j++)
    {
        if (OrderGetTicket(j))
        {
            trade.OrderDelete(OrderGetTicket(j));
        }
    }
}

// Define the OnTick function
void OnTick()
{
    if (gridSize == 0)
    {
        gridSize = NormalizeDouble(AtrValue() * gridMultiplier, Digits());
        return;
    }

    bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    currentPrice = NormalizeDouble((ask + bid) / 2, Digits());
    spread = NormalizeDouble(MathAbs(ask - bid), Digits());
    bool highSpread = spread * 10 > gridSize;
    if (highSpread)
    {
        ObjectsDeleteAll(0, "firstUpperLevel");
        ObjectsDeleteAll(0, "firstLowerLevel");
        ObjectsDeleteAll(0, "secondUpperLevel");
        ObjectsDeleteAll(0, "secondLowerLevel");
        for (int j = 0; j < OrdersTotal(); j++)
        {
            if (OrderGetTicket(j))
            {
                if (Symbol() == OrderGetString(ORDER_SYMBOL))
                    trade.OrderDelete(OrderGetTicket(j));
            }
        }
        return;
    }

    // update levels
    if (secondUpperLevel < bid || secondLowerLevel > ask)
    {
        firstUpperLevel = NormalizeDouble(MathCeil(currentPrice / gridSize) * gridSize, Digits());
        firstLowerLevel = NormalizeDouble(firstUpperLevel - gridSize, Digits());
        secondUpperLevel = NormalizeDouble(firstUpperLevel + gridSize, Digits());
        secondLowerLevel = NormalizeDouble(firstLowerLevel - gridSize, Digits());

        ObjectCreate(0, "firstUpperLevel", OBJ_HLINE, 0, 0, firstUpperLevel);
        ObjectSetInteger(0, "firstUpperLevel", OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(0, "firstUpperLevel", OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, "firstUpperLevel", OBJPROP_WIDTH, 1);
        ObjectCreate(0, "firstLowerLevel", OBJ_HLINE, 0, 0, firstLowerLevel);
        ObjectSetInteger(0, "firstLowerLevel", OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(0, "firstLowerLevel", OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, "firstLowerLevel", OBJPROP_WIDTH, 1);
        ObjectCreate(0, "secondUpperLevel", OBJ_HLINE, 0, 0, secondUpperLevel);
        ObjectSetInteger(0, "secondUpperLevel", OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(0, "secondUpperLevel", OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, "secondUpperLevel", OBJPROP_WIDTH, 1);
        ObjectCreate(0, "secondLowerLevel", OBJ_HLINE, 0, 0, secondLowerLevel);
        ObjectSetInteger(0, "secondLowerLevel", OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(0, "secondLowerLevel", OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, "secondLowerLevel", OBJPROP_WIDTH, 1);
    }

    UpdateTakeProfitPositions();
    UpdateStopLossPositions();
    CloseLosingPositions();

    if (maPeriod > 0)
        Ema();

    // check all positions and orders for this level, if there is no position or order, place a trade
    double levels[4] = {firstUpperLevel, firstLowerLevel, secondUpperLevel, secondLowerLevel};
    for (int i = 0; i < ArraySize(levels); i++)
    {
        double level = NormalizeDouble(levels[i], Digits());
        string levelString = DoubleToString(level, Digits());

        string labelBuy = "Buy " + DoubleToString(level, Digits());
        string labelSell = "Sell " + DoubleToString(level, Digits());

        bool placeBuyTrade = true;
        bool placeSellTrade = true;

        for (int j = 0; j < PositionsTotal(); j++)
        {
            if (PositionGetTicket(j))
            {
                string comment = PositionGetString(POSITION_COMMENT);
                string commentParts[];
                int num = StringSplit(comment, ' ', commentParts);
                if (num == 2 && commentParts[1] == levelString)
                {
                    if (commentParts[0] == "Buy")
                    {
                        placeBuyTrade = false;
                    }
                    if (commentParts[0] == "Sell")
                    {
                        placeSellTrade = false;
                    }
                }
            }
        }

        for (int k = 0; k < OrdersTotal(); k++)
        {
            if (OrderGetTicket(k))
            {
                string comment = OrderGetString(ORDER_COMMENT);
                string commentParts[];
                int num = StringSplit(comment, ' ', commentParts);
                if (num == 2 && commentParts[1] == levelString)
                {
                    if (commentParts[0] == "Buy")
                    {
                        placeBuyTrade = false;
                    }
                    if (commentParts[0] == "Sell")
                    {
                        placeSellTrade = false;
                    }
                }
            }
        }

        if (maPeriod > 0)
        {
            if (maDirection > 0)
                placeSellTrade = false;
            if (maDirection < 0)
                placeBuyTrade = false;
        }

        double tpBuy = level + gridSize;
        double tpSell = level - gridSize;

        if (placeBuyTrade && !highSpread && takeBuys)
        {
            double volume = Volume();
            if (level < bid)
            {
                trade.BuyLimit(volume, level, Symbol(), 0, tpBuy, ORDER_TIME_DAY, 0, labelBuy);
            }
            if (level > ask)
            {
                trade.BuyStop(volume, level, Symbol(), 0, tpBuy, ORDER_TIME_DAY, 0, labelBuy);
            }
        }
        if (placeSellTrade && !highSpread && takeSells)
        {
            double volume = Volume();
            if (level > ask)
            {
                trade.SellLimit(volume, level, Symbol(), 0, tpSell, ORDER_TIME_DAY, 0, labelSell);
            }
            if (level < bid)
            {
                trade.SellStop(volume, level, Symbol(), 0, tpSell, ORDER_TIME_DAY, 0, labelSell);
            }
        }
    }

    Comment("\nGrid Size: ", DoubleToString(gridSize, Digits()), "\n",
            "Spread: ", DoubleToString(spread, Digits()), "\n",
            highSpread ? "High Spread" : "Low Spread", "\n",

            "\nPositions: ", PositionsTotal(), "\n",
            "Orders: ", OrdersTotal(), "\n",
            "Total: ", PositionsTotal() + OrdersTotal(), "\n \n",
            maPeriod > 0 && maDirection > 0 ? "Bull" : maPeriod > 0 && maDirection > 0 ? "Bear"
                                                   : maPeriod > 0                      ? "Range"
                                                                                       : "",
            "\n",
            "isTrailing: ", isTrailing, "\n",
            "trail direction: ", longTrailing ? "long" : shortTrailing ? "short"
                                                                       : "none",
            "\n",
            "trail price: ", longTrailing ? longTrailPrice : shortTrailing ? shortTrailPrice
                                                                           : 0,
            "\n",
            "start price: ", startPrice, "\n");
}

void UpdateTakeProfitPositions()
{
    string symbol = Symbol();
    for (int i = 0; i < PositionsTotal(); i++)
    {
        if (PositionGetTicket(i))
        {
            ulong ticket = PositionGetTicket(i);
            string positionSymbol = PositionGetString(POSITION_SYMBOL);
            long positionType = PositionGetInteger(POSITION_TYPE);
            double entryPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), Digits());
            double takeProfit = NormalizeDouble(PositionGetDouble(POSITION_TP), Digits());
            double expectedLong = NormalizeDouble(entryPrice + gridSize, Digits());
            double expectedShort = NormalizeDouble(entryPrice - gridSize, Digits());

            if (positionSymbol != symbol)
                return;
            if (positionType == POSITION_TYPE_BUY && takeProfit != expectedLong)
                trade.PositionModify(ticket, 0, expectedLong);
            if (positionType == POSITION_TYPE_SELL && takeProfit != expectedShort)
                trade.PositionModify(ticket, 0, expectedShort);
        }
    }
}

void UpdateStopLossPositions()
{
    if (!trailGrid)
        return;

    string symbol = Symbol();
    if (!isTrailing)
    {

        for (int i = PositionsTotal() - 1; i >= 0; i--)
        {
            if (PositionGetTicket(i))
            {
                ulong ticket = PositionGetTicket(i);
                string positionSymbol = PositionGetString(POSITION_SYMBOL);
                if (positionSymbol == symbol)
                    symbolPosCount++;
            }
        }

        if (symbolPosCount > 2)
        {
            startPrice = NormalizeDouble(MathRound(currentPrice / gridSize) * gridSize, Digits());
            ;
            longTrailFirstLevel = NormalizeDouble(startPrice + gridSize, Digits());
            longTrailSecondLevel = NormalizeDouble(startPrice + (gridSize * 2), Digits());
            longTrailThirdLevel = NormalizeDouble(startPrice + (gridSize * 3), Digits());
            longTrailFourthLevel = NormalizeDouble(startPrice + (gridSize * 4), Digits());
            shortTrailFirstLevel = NormalizeDouble(startPrice - gridSize, Digits());
            shortTrailSecondLevel = NormalizeDouble(startPrice - (gridSize * 2), Digits());
            shortTrailThirdLevel = NormalizeDouble(startPrice - (gridSize * 3), Digits());
            shortTrailFourthLevel = NormalizeDouble(startPrice - (gridSize * 4), Digits());
            isTrailing = true;
            longTrailing = false;
            shortTrailing = false;
        }
    }

    if (isTrailing)
    {
        if ((longTrailing && (currentPrice < longTrailPrice || currentPrice > longTrailFourthLevel)) || (shortTrailing && (currentPrice > shortTrailPrice || currentPrice < shortTrailFourthLevel)))
        {
            for (int j = PositionsTotal() - 1; j >= 0; j--)
            {
                if (PositionSelectByTicket(PositionGetTicket(j)))
                {
                    ulong ticket = PositionGetTicket(j);
                    string positionSymbol = PositionGetString(POSITION_SYMBOL);
                    if (positionSymbol == Symbol())
                    {
                        trade.PositionClose(ticket);
                    }
                }
            }
            isTrailing = false;
            longTrailing = false;
            shortTrailing = false;
            symbolPosCount = 0;
            longTrailPrice = 0.0;
            shortTrailPrice = 0.0;
        }
    }

    if (isTrailing)
    {
        if (!shortTrailing && !longTrailing && currentPrice > longTrailFirstLevel)
            longTrailing = true;
        else if (!longTrailing && !shortTrailing && currentPrice < shortTrailFirstLevel)
            shortTrailing = true;

        if (longTrailing)
        {
            if (currentPrice > longTrailThirdLevel && longTrailSecondLevel > longTrailPrice)
                longTrailPrice = longTrailSecondLevel;
            else if (currentPrice > longTrailSecondLevel && longTrailFirstLevel > longTrailPrice)
                longTrailPrice = longTrailFirstLevel;
            else if (currentPrice > longTrailFirstLevel && startPrice > longTrailPrice)
                longTrailPrice = startPrice;
        }
        else if (shortTrailing)
        {
            if (currentPrice < shortTrailThirdLevel && shortTrailSecondLevel < shortTrailPrice)
                shortTrailPrice = shortTrailSecondLevel;
            else if (currentPrice < shortTrailSecondLevel && shortTrailFirstLevel < shortTrailPrice)
                shortTrailPrice = shortTrailFirstLevel;
            else if (currentPrice < shortTrailFirstLevel && startPrice < shortTrailPrice)
                shortTrailPrice = startPrice;
        }
    }
}

// Function to calculate trading volume based on risk and market conditions
double Volume()
{
    double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

    double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * riskPercent / 100;
    double moneyLotStep = (MathAbs(gridSize) / tickSize) * tickValue * lotStep;

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
        Print(lots, " Adjusted to maximum volume ", minVol);
    }

    return lots;
}

double AtrValue()
{
    double priceArray[];
    int atrDef = iATR(Symbol(), PERIOD_CURRENT, AtrPeriod);
    ArraySetAsSeries(priceArray, true);
    CopyBuffer(atrDef, 0, 0, 1, priceArray);
    double atrValue = NormalizeDouble(priceArray[0], Digits());
    return atrValue;
}

void Ema()
{
    int bars = iBars(Symbol(), PERIOD_CURRENT);

    if (barsTotal < bars)
    {
        barsTotal = bars;

        double ma[];
        ArraySetAsSeries(ma, true);
        CopyBuffer(maHandle, MAIN_LINE, 0, barsTotal, ma);

        int newMaDirection = 0;
        if (currentPrice > ma[0])
            newMaDirection = 1;
        else if (currentPrice < ma[0])
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

        int changePeriod = maDivider; // MathRound(maPeriod / 4);
        if (periodSinceLastDirectionChange >= changePeriod)
        {
            maDirection = newMaDirection;
        }
        else
        {
            maDirection = 0;
        }

        ObjectCreate(0, "Ma " + (string)previousTime, OBJ_TREND, 0, TimeCurrent(), ma[0], previousTime, ma[1]);
        ObjectSetInteger(0, "Ma " + (string)previousTime, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, "Ma " + (string)previousTime, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, "Ma " + (string)previousTime, OBJPROP_COLOR, maDirection > 0 ? clrGreen : maDirection < 0 ? clrRed
                                                                                                              : clrYellow);

        previousTime = TimeCurrent();
    }
}

void CloseLosingPositions()
{
    if (maxGridAway == 0)
        return;
    if (maPeriod > 0 && maDirection == 0)
        return;

    string symbol = Symbol();
    double slBuys = NormalizeDouble(currentPrice + (maxGridAway * gridSize), Digits());
    double slSells = NormalizeDouble(currentPrice - (maxGridAway * gridSize), Digits());

    for (int i = 0; i < PositionsTotal(); i++)
    {
        if (PositionGetTicket(i))
        {
            ulong ticket = PositionGetTicket(i);
            string positionSymbol = PositionGetString(POSITION_SYMBOL);
            long positionType = PositionGetInteger(POSITION_TYPE);
            double entryPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), Digits());

            if (positionSymbol != symbol)
                return;

            if (positionType == POSITION_TYPE_BUY && entryPrice > slBuys)
                trade.PositionClose(ticket);
            if (positionType == POSITION_TYPE_SELL && entryPrice < slSells)
                trade.PositionClose(ticket);
        }
    }
}
