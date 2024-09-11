//+------------------------------------------------------------------+
//|                                             SimpleTradeBot.mq5   |
//|                        Copyright 2024, gllsrssx Ltd.             |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
CTrade trade;

// Input parameters
input long InpMagicNumber = 12345678;           // Magic Number
input double InpRisk = 1.0;                     // Risk percentage per trade
input ENUM_TIMEFRAMES InpTimeFrame = PERIOD_D1; // Timeframe for trading
input int InpStartHour = 2;                     // Start trading hour
input int InpEndHour = 22;                      // End trading hour

// Global variables
datetime lastTradeTime = 0;
bool buyOpen = false, sellOpen = false;
ulong buyTicket = 0, sellTicket = 0;

int OnInit()
{
    trade.SetExpertMagicNumber(InpMagicNumber);
    return INIT_SUCCEEDED;
}

void OnTick()
{
    MqlTick tick;
    MqlDateTime time;
    SymbolInfoTick(Symbol(), tick);
    TimeToStruct(TimeCurrent(), time);

    // Only trade within the specified hours
    if (time.hour < InpStartHour || time.hour >= InpEndHour)
        return;

    // If it's a new bar on the selected timeframe
    if (IsNewBar(InpTimeFrame, barsTotalOpen))
    {
        // If we have open positions, close them after the timeframe ends
        if (buyOpen || sellOpen)
        {
            CloseAllPositions();
        }

        // Open a buy and sell position at the start of the new bar
        if(PositionCount() > 0) return;
        OpenPositions();
        lastTradeTime = TimeCurrent();
    }

    // Check if half the timeframe has passed to close the losing position
    if (TimeCurrent() - lastTradeTime >= PeriodSeconds(InpTimeFrame) / 2 && PositionCount() > 1 && IsNewBar(InpTimeFrame, barsTotalClose))
    {
        CloseLosingPosition();
    }
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

int barsTotalOpen, barsTotalClose;
// Function to check if it's a new bar
bool IsNewBar(ENUM_TIMEFRAMES timeFrame, int &barsTotal)
{
    int bars = iBars(Symbol(), timeFrame);
    if (bars == barsTotal)
        return false;
    barsTotal = bars;
    return true;
}

// Function to open buy and sell positions with ATR-based stop loss
void OpenPositions()
{
    double lots = CalculateLotSize();
    double atrValue = CalculateATR();

    double stopLossBuy = SymbolInfoDouble(Symbol(), SYMBOL_BID) - atrValue;
    double stopLossSell = SymbolInfoDouble(Symbol(), SYMBOL_ASK) + atrValue;

    buyTicket = trade.Buy(lots, NULL, stopLossBuy, 0, 0, "Buy Order");
    sellTicket = trade.Sell(lots, NULL, stopLossSell, 0, 0, "Sell Order");

    if (buyTicket > 0)
        buyOpen = true;
    if (sellTicket > 0)
        sellOpen = true;
}

// Function to calculate lot size based on risk percentage
double CalculateLotSize()
{
    double minVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    double atrValue = CalculateATR();
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskMoney = balance * InpRisk * 0.01;
    double slDistance = atrValue;
    double moneyLotStep = slDistance / tickSize * tickValue * lotStep;
    double lots = MathRound(riskMoney / moneyLotStep) * lotStep;

    if (lots < minVol || lots == NULL || atrValue == 0 || atrValue == NULL)
    {
        lots = minVol * 2;
    }
    else if (lots > maxVol)
    {
        lots = maxVol;
    }
    return lots;
}

// Function to calculate ATR
double CalculateATR()
{
    int atrHandle = iATR(Symbol(), InpTimeFrame, 100);
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
    return atrBuffer[0];
}

// Function to close all open positions
void CloseAllPositions()
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
}

// Function to close the losing position after half the timeframe
void CloseLosingPosition()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket))
            continue;
        if (PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
            continue;
        if (PositionGetDouble(POSITION_PROFIT) < 0)
        {
            trade.PositionClose(ticket);
        }
    }
}