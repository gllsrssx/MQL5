// mq5 EA. opens BUY trades on Monday 6 minutes after market open and closes them on Friday 6 minutes before market close. can set % of account balance to risk on each trade based on the atr.
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>

input long Magic = 123456;                   // Magic number
input double Risk = 1.0;                     // Percentage of account balance to risk
input int CloseHour = 23;                    // Hour to close trade
input int CloseMinute = 54;                  // Minute to close trade
input ENUM_TIMEFRAMES TimeFrame = PERIOD_D1; // Timeframe
// atr inputs
input int ATRPeriod = 5; // ATR period
// ma inputs
input int MAPeriod = 20;                        // EMA period
input ENUM_MA_METHOD MAMethod = MODE_EMA;       // EMA method
input ENUM_APPLIED_PRICE MAPrice = PRICE_CLOSE; // EMA price
// macd inputs
input int MACDFast = 12;                          // MACD fast period
input int MACDSlow = 26;                          // MACD slow period
input int MACDSignal = 9;                         // MACD signal period
input ENUM_APPLIED_PRICE MACDPrice = PRICE_CLOSE; // MACD price
input int hLine = 5;                              // Horizontal minimum
input bool macdConfirmation = false;              // MACD confirmation

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

double NormalizeValue(double value, double min, double max, double lowest, double highest)
{
    double range = highest - lowest;
    double scaledValue = (value - lowest) / range;              // Scale to 0-1
    double normalizedValue = (scaledValue * (max - min)) + min; // Scale to min-max
    return normalizedValue;
}

void OnTick()
{
    MqlDateTime mdt;
    TimeCurrent(mdt);

    int currentDay = mdt.day_of_week;
    int currentHour = mdt.hour;
    int currentMinute = mdt.min;

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == Symbol() && PositionGetInteger(POSITION_MAGIC) == Magic)
        {
            datetime position_time = (datetime)PositionGetInteger(POSITION_TIME);
            MqlDateTime openTime;
            TimeToStruct(position_time, openTime);
            int days = mdt.day - openTime.day;

            if (days > 1 || (currentHour >= CloseHour && currentMinute >= CloseMinute))
            {
                trade.PositionClose(ticket);
            }
        }
    }

    // if time is after 1.06 am.
    if (currentHour <= 1 && currentMinute <= 6)
        return;

    int bars = iBars(Symbol(), PERIOD_D1);
    if (bars == barsTotal)
        return;
    barsTotal = bars;

    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);

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
    CopyBuffer(macdHandle, 0, 0, 240, macdM);
    CopyBuffer(macdHandle, 1, 0, 240, macdS);
    // Find the lowest and highest MACD values over the last x bars
    double lowestMacdM = macdM[0];
    double highestMacdM = macdM[0];
    // string macdString = "Before > M:" + (int)macdM[0] + " S:" + (int)macdS[0];
    for (int i = 1; i < 240; i++)
    {
        if (macdM[i] < lowestMacdM)
            lowestMacdM = macdM[i];
        if (macdM[i] > highestMacdM)
            highestMacdM = macdM[i];
    }
    for (int i = 0; i < 240; i++)
    {
        macdM[i] = NormalizeValue(macdM[i], -100, 100, lowestMacdM, highestMacdM);
        macdS[i] = NormalizeValue(macdS[i], -100, 100, lowestMacdM, highestMacdM);
    }
    Comment(" M:" + (string)(int)macdM[0] + " S:" + (string)(int)macdS[0]);

    int barsBack = macdConfirmation ? 1 : 0;

    bool macdReversalBuy = macdM[barsBack] > macdS[barsBack] && macdM[barsBack + 1] < macdS[barsBack + 1] && macdM[barsBack] < 0 && macdS[barsBack] < 0;
    bool macdReversalSell = macdM[barsBack] < macdS[barsBack] && macdM[barsBack + 1] > macdS[barsBack + 1] && macdM[barsBack] > 0 && macdS[barsBack] > 0;
    bool macdReversalH = MathAbs(macdM[0]) >= hLine && MathAbs(macdS[0]) >= hLine;
    bool emaBuy = ask > ma[0];
    bool emaSell = bid < ma[0];

    if (posCount == 0 && macdReversalH && ((emaBuy && macdReversalBuy) || (emaSell && macdReversalSell)))
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
}
