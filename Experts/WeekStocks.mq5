// mq5 EA. opens BUY trades on Monday 6 minutes after market open and closes them on Friday 6 minutes before market close. can set % of account balance to risk on each trade based on the atr.
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>

input long Magic = 123456; // Magic number
input double Risk = 1.0;   // Percentage of account balance to risk
enum TradeDay
{
    MONDAY = 1,
    TUESDAY = 2,
    WEDNESDAY = 3,
    THURSDAY = 4,
    FRIDAY = 5,
    SATURDAY = 6,
    SUNDAY = 0
};
input TradeDay OpenDay = 1;     // Day to open trade
input int OpenHour = 1;         // Hour to open trade on Monday
input int OpenMinute = 6;       // Minute to open trade on Monday
input TradeDay CloseDay = 5;    // Day to close trade
input int CloseHour = 19;       // Hour to close trade on Friday
input int CloseMinute = 54;     // Minute to close trade on Friday
input int MaxOpenDaysCheck = 7; // Max open days check
// atr inputs
input int ATRPeriod = 200;                      // ATR period
input ENUM_TIMEFRAMES ATRTimeFrame = PERIOD_D1; // ATR timeframe
// ma inputs
input int MAPeriod = 200;                       // EMA period
input ENUM_TIMEFRAMES MATimeFrame = PERIOD_D1;  // EMA timeframe
input ENUM_MA_METHOD MAMethod = MODE_EMA;       // EMA method
input ENUM_APPLIED_PRICE MAPrice = PRICE_CLOSE; // EMA price

CTrade trade;
int maHandle, atrHandle;
int barsTotal;

int OnInit()
{
    maHandle = iMA(Symbol(), MATimeFrame, MAPeriod, 0, MAMethod, MAPrice);
    atrHandle = iATR(Symbol(), ATRTimeFrame, ATRPeriod);
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
    CopyBuffer(maHandle, 0, 0, 1, ma);

    if (currentDay == OpenDay && currentHour == OpenHour && currentMinute == OpenMinute && posCount == 0 && ask > ma[0])
    {
        double atr[];
        ArraySetAsSeries(atr, true);
        CopyBuffer(atrHandle, 0, 0, 1, atr);

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

        trade.Buy(lots);
    }

    if (currentDay == CloseDay && currentHour == CloseHour && currentMinute == CloseMinute && posCount > 0)
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
            if (days > MaxOpenDaysCheck)
            {
                trade.PositionClose(ticket);
            }
        }
    }
}
