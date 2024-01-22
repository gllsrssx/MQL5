#include <Trade\Trade.mqh>
CTrade trade;

// Input parameters
input double risk = 0.01;                          // Risk percentage
input int inpPeriod = 120;                          // EMA period
ENUM_TIMEFRAMES timeFrame = PERIOD_CURRENT;        // Time frame for EMA

// Global variables
double close[], ema[];
int trendEMA = 0;

// Initialization function
int OnInit()
{
    return (INIT_SUCCEEDED);
}

// Main function called on every tick
void OnTick()
{
    // Update market and calculate EMA
    UpdateMarketInfo();
    CalculateEMA(inpPeriod);

    // Determine the trend
    trendEMA = TrendEMA();

    // Execute trades based on trend
    ExecuteTrades();

    // Display useful information
    DisplayComment();
}

// Function to calculate EMA
void CalculateEMA(int period)
{
    int copied = CopyClose(Symbol(), timeFrame, 0, period, close);
    if(copied <= 0) return;
    
    ArrayResize(ema, copied);
    for (int i = 0; i < copied; i++)
    {
        ema[i] = i > 0 ? ema[i - 1] + 2.0 / (1.0 + period) * (close[i] - ema[i - 1]) : close[i];
    }
}

// Function to determine the trend based on EMA
int TrendEMA()
{
    if (inpPeriod == 0) return 0;
    if (ArraySize(close) < inpPeriod) return 0;

    bool isBull = close[ArraySize(close) - 1] > ema[ArraySize(ema) - 1];
    bool isBear = close[ArraySize(close) - 1] < ema[ArraySize(ema) - 1];

    if (isBull) return 1;   // Bull trend
    if (isBear) return -1;  // Bear trend
    return 0;               // Ranging
}

// Function to execute trades based on trend
void ExecuteTrades()
{
    switch(trendEMA)
    {
        case 1: // Bull trend
            CloseAllSellOrders();
            PlaceBuyOrder();
            break;
        case -1: // Bear trend
            CloseAllBuyOrders();
            PlaceSellOrder();
            break;
        default: // Ranging
            CloseAllOrders();
            break;
    }
}

// Function to place a buy order
void PlaceBuyOrder()
{
    //double lotSize = OptimumLotSize(risk, /* define stop loss points */);
    trade.Buy(risk, Symbol());
}

// Function to place a sell order
void PlaceSellOrder()
{
    //double lotSize = OptimumLotSize(risk, /* define stop loss points */);
    trade.Sell(risk, Symbol());
}

// Function to close all orders
void CloseAllOrders()
{
    // Close all open orders
    for(int i = 0; i < PositionsTotal(); i++)
    {
       
    }
}

// Function to calculate the optimal lot size
double OptimumLotSize(double riskPercent, double stopPoints)
{
    // Calculate and return the optimum lot size
    return 0.0;
}

// Function to update market info
void UpdateMarketInfo()
{
    // Update market information like current price, spread, etc.
}

// Function to display information on the chart
void DisplayComment()
{
    string commentText = "Trend: " + (trendEMA == 1 ? "Bull" : trendEMA == -1 ? "Bear" : "Ranging") + "\n";
    Comment(commentText);
}
