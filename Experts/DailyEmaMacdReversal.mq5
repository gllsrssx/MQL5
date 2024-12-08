// mq5 EA. opens BUY trades on Monday 6 minutes after market open and closes them on Friday 6 minutes before market close. can set % of account balance to risk on each trade based on the atr.
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>

input long Magic = 123456;                   // Magic number
input double Risk = 1.0;                     // Percentage of account balance to risk
input int CloseHour = 19;                    // Hour to close trade
input int CloseMinute = 54;                  // Minute to close trade
input ENUM_TIMEFRAMES TimeFrame = PERIOD_D1; // Timeframe
// atr inputs
input int ATRPeriod = 200; // ATR period
// ma inputs
input int MAPeriod = 200;                       // EMA period
input ENUM_MA_METHOD MAMethod = MODE_EMA;       // EMA method
input ENUM_APPLIED_PRICE MAPrice = PRICE_CLOSE; // EMA price
// macd inputs
input int MACDFast = 12;                          // MACD fast period
input int MACDSlow = 26;                          // MACD slow period
input int MACDSignal = 9;                         // MACD signal period
input ENUM_APPLIED_PRICE MACDPrice = PRICE_CLOSE; // MACD price
input bool macdConfirmation = true;               // MACD confirmation

CTrade trade;
int maHandle, atrHandle, macdHandle;
int barsTotal;

int OnInit()
{
    maHandle = iMA(Symbol(), TimeFrame, MAPeriod, 0, MAMethod, MAPrice);
    atrHandle = iATR(Symbol(), TimeFrame, ATRPeriod);
    macdHandle = iMACD(Symbol(), TimeFrame, MACDFast, MACDSlow, MACDSignal, MACDPrice);
    trade.SetExpertMagicNumber(Magic);
    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
    MqlDateTime mdt;
    TimeCurrent(mdt);

    int bars = iBars(Symbol(), PERIOD_M1);
    if (bars == barsTotal)
        return;
    barsTotal = bars;

    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);

    int currentDay = mdt.day_of_week;
    int currentHour = mdt.hour;
    int currentMinute = mdt.min;

    int posCount = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == Magic)
        {
            posCount++;
        }
    }

    double ma[];
    ArraySetAsSeries(ma, true);
    CopyBuffer(maHandle, 0, 0, 3, ma);

    double macdM[];
    double macdS[];
    // Sorting price array from current data for MACD main line, MACD signal line
    ArraySetAsSeries(macdM, true);
    ArraySetAsSeries(macdS, true);
    // Storing results after defining MA, line, current data for MACD main line, MACD signal line
    CopyBuffer(macdHandle, 0, 0, 3, macdM);
    CopyBuffer(macdHandle, 1, 0, 3, macdS);

    int barsBack = macdConfirmation ? 1 : 0;

    // ta.crossover(macd, signal)[macdBackCheck] and macd[macdBackCheck] < 0 and macd > signal and macd < 0 and close > open
    bool macdReversalBuy = macdM[barsBack] > macdS[barsBack] && macdM[barsBack + 1] < macdS[barsBack + 1] && macdM[barsBack] < 0 && macdS[barsBack] < 0;
    bool macdReversalSell = macdM[barsBack] < macdS[barsBack] && macdM[barsBack + 1] > macdS[barsBack + 1] && macdM[barsBack] > 0 && macdS[barsBack] > 0;

    bool emaBuy = ask > ma[0];
    bool emaSell = bid < ma[0];

    if (posCount == 0 && ((emaBuy && macdReversalBuy) || (emaSell && macdReversalSell)))
    {
        double atr[];
        ArraySetAsSeries(atr, true);
        CopyBuffer(atrHandle, 0, 0, 3, atr);

        double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
        double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
        double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
        double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * Risk / 100;
        double moneyLotStep = atr[0] / tickSize * tickValue * lotStep;
        double lots = MathFloor(riskMoney / moneyLotStep) * lotStep;
        double minVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
        double maxVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
        if (lots < minVol)
            lots = minVol;
        else if (lots > maxVol)
            lots = maxVol;

        if (emaBuy && macdReversalBuy)
            trade.Buy(lots);
        if (emaSell && macdReversalSell)
            trade.Sell(lots);
    }

    if (currentHour >= CloseHour && currentMinute >= CloseMinute && posCount > 0)
    {
        for (int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if (PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == Magic)
            {
                trade.PositionClose(ticket);
            }
        }
    }

    // check if trade is open for more than x days
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == Magic)
        {
            datetime position_time = (datetime)PositionGetInteger(POSITION_TIME);
            MqlDateTime openTime;
            TimeToStruct(position_time, openTime);

            int days = mdt.day - openTime.day;
            if (days > 1)
            {
                trade.PositionClose(ticket);
            }
        }
    }
}
