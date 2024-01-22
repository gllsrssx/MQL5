//+------------------------------------------------------------------+
//|                                                       slGrid.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

// create a grid trading ea
// to calculate the grid distance, use the ATR indicator with period 480. 
// when the price touches the grid level, open a buy and sell position with 1% of the account balance
// have 6 levels of grid up and 6 levels of grid down
// example:
// price hits the grid level, we take a buy and sell position with 1% of the account balance
// the tp is at the next grid level
// we trail the stop loss at the previous grid level

#include <Trade\Trade.mqh>
CTrade trade;

// Input parameters
input double riskPercent = 0.01; // Risk percentage per trade
input int AtrPeriod = 480; // Period for ATR
input bool takeBuys = true; // Flag to take buy positions
input bool takeSells = true; // Flag to take sell positions
input bool trailGrid = true; // Flag to enable trailing stop loss
input int TrailingStop = 50; // Trailing stop in points

// Global variables
double gridSize, firstUpperLevel, firstLowerLevel, secondUpperLevel, secondLowerLevel;
double bid, ask;

// Initialization function
int OnInit()
{
    // Initialize grid size
    gridSize = AtrValue();
    return INIT_SUCCEEDED;
}

// Main execution function
void OnTick()
{
    // Update bid and ask prices
    bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);

    UpdateGridLevels();
    ManageTrades();
    if (trailGrid) TrailStopLoss();
}

// Function to calculate ATR based grid size
double AtrValue()
{
    double atrArray[];
    int atrHandle = iATR(Symbol(), PERIOD_CURRENT, AtrPeriod);
    ArraySetAsSeries(atrArray, true);
    CopyBuffer(atrHandle, 0, 0, 1, atrArray);
    return NormalizeDouble(atrArray[0], Digits());
}

// Function to update grid levels
void UpdateGridLevels()
{
    bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double currentPrice = NormalizeDouble((ask + bid) / 2, Digits());

    firstUpperLevel = NormalizeDouble(MathCeil(currentPrice / gridSize) * gridSize, Digits());
    firstLowerLevel = NormalizeDouble(firstUpperLevel - gridSize, Digits());
    secondUpperLevel = NormalizeDouble(firstUpperLevel + gridSize, Digits());
    secondLowerLevel = NormalizeDouble(firstLowerLevel - gridSize, Digits());
}

// Function to manage trades based on grid levels
void ManageTrades()
{
    double levels[4] = {firstUpperLevel, firstLowerLevel, secondUpperLevel, secondLowerLevel};
    for (int i = 0; i < ArraySize(levels); i++)
    {
        double level = NormalizeDouble(levels[i], Digits());

        // Place Buy and Sell Orders
        PlaceOrder(level, ORDER_TYPE_BUY);
        PlaceOrder(level, ORDER_TYPE_SELL);
    }
}

// Function to place an order
void PlaceOrder(double level, int type)
{
    string label = (type == ORDER_TYPE_BUY ? "Buy " : "Sell ") + DoubleToString(level, Digits());
    double volume = Volume();
    double tp = (type == ORDER_TYPE_BUY ? level + gridSize : level - gridSize);

    if (type == ORDER_TYPE_BUY && level < bid && takeBuys)
    {
        trade.BuyLimit(volume, level, Symbol(), 0, tp, ORDER_TIME_DAY, 0, label);
    }
    else if (type == ORDER_TYPE_SELL && level > ask && takeSells)
    {
        trade.SellLimit(volume, level, Symbol(), 0, tp, ORDER_TIME_DAY, 0, label);
    }
}

// Function to implement trailing stop loss
void TrailStopLoss()
{
    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket > 0)
        {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double symbolPoint = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
            double trailDistance = TrailingStop * symbolPoint;

            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                double newSL = bid - trailDistance;
                if (newSL > openPrice && newSL > currentSL)
                {
                    trade.PositionModify(ticket, newSL, 0);
                }
            }
            else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
                double newSL = ask + trailDistance;
                if (newSL < openPrice && newSL < currentSL)
                {
                    trade.PositionModify(ticket, newSL, 0);
                }
            }
        }
    }
}

double Volume()
{
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * riskPercent / 100;
    double volume = riskAmount / (gridSize * SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE));
    return NormalizeDouble(volume, 2); // Adjust this to match your broker's volume step size
}
