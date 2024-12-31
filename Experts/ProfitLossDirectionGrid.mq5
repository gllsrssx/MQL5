
#property copyright "Copyright 2024, GllsRssx Ltd."
#property link "https://www.rssx.eu"
#property version "3.0"
#property description "grid."

#include <Trade\Trade.mqh>
CTrade trade;

input group "Risk";
input double RiskValueAmount = 0.1; // Risk Amount
enum ENUM_RISK_VALUE
{
    RISK_VALUE_LOT,
    RISK_VALUE_PERCENT
};
input ENUM_RISK_VALUE RiskValue = RISK_VALUE_PERCENT; // Risk Value
enum ENUM_RISK_TYPE
{
    RISK_TYPE_BALANCE,
    RISK_TYPE_EQUITY,
    RISK_TYPE_STATIC
};
input ENUM_RISK_TYPE RiskType = RISK_TYPE_BALANCE; // Risk Type
input group "Grid";
input ENUM_TIMEFRAMES WinTimeFrame = PERIOD_D1;  // Win Time Frame
input ENUM_TIMEFRAMES LossTimeFrame = PERIOD_D1; // Loss Time Frame
input double TrailPercent = 0.5;                 // Trail Percent
input bool adaptiveLossGrid = false;             // Adaptive Loss Grid
input bool fasterLossGrid = false;               // Faster Loss Grid
input bool multiplierWinLot = false;             // Multiplier Win Lot
input group "Info";
input bool IsChartComment = true;  // Chart Comment
input long MagicNumber = 88888888; // Magic Number
input group "Time";
input int StartHour = 0;   // Start Hour
input int startMinute = 6; // Start Minute
input int StopHour = 23;   // Stop Hour
input int StopMinute = 54; // Stop Minute

int Period;              // Period
double WinGridDistance;  // Win Grid Distance
double LossGridDistance; // Loss Grid Distance
double TrailDistance;    // Trail Distance
double winMoney;         // Win Money
int Multiplier = 2;      // Multiplier

double last;
double lastPriceLong;
double lastPriceShort;
double startPriceLong;
double startPriceShort;
double profitLong;
double profitShort;
double distance;
double lotSizeBuy;
double lotSizeSell;
string pair = Symbol();

int OnInit()
{
    int barsPeriod = iBars(pair, Period());
    int barsWin = iBars(pair, WinTimeFrame);
    int barsLoss = iBars(pair, LossTimeFrame);
    Period = MathMin(barsPeriod, MathMin(barsWin, barsLoss));

    profitLong = 0;
    profitShort = 0;

    trade.SetExpertMagicNumber(MagicNumber);
    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
    MqlDateTime mdt;
    TimeCurrent(mdt);
    int hour = mdt.hour;
    int minute = mdt.min;

    if (hour < StartHour || hour > StopHour || (hour == StartHour && minute < startMinute) || (hour == StopHour && minute > StopMinute))
        return;

    double bid = SymbolInfoDouble(pair, SYMBOL_BID);
    double ask = SymbolInfoDouble(pair, SYMBOL_ASK);
    last = (bid + ask) / 2;
    double spread = ask - bid;
    int longCount = PositionCountLong();
    int shortCount = PositionCountShort();
    WinGridDistance = WinAtr() + spread;
    LossGridDistance = LossAtr() + spread;
    TrailDistance = WinGridDistance * TrailPercent;
    distance = WinGridDistance;
    if (WinGridDistance == 0 || LossGridDistance == 0)
    {
        Comment(WinGridDistance, " | ", LossGridDistance);
        return;
    }
    winMoney = CalculateWinMoney();

    if (longCount == 0)
    {
        lotSizeBuy = Volume();
        trade.Buy(lotSizeBuy);
        lastPriceLong = last;
        startPriceLong = last;
        return;
    }
    if (shortCount == 0)
    {
        lotSizeSell = Volume();
        trade.Sell(lotSizeSell);
        lastPriceShort = last;
        startPriceShort = last;
        return;
    }

    if (longCount == 1)
        SetStartPriceLong();
    if (shortCount == 1)
        SetStartPriceShort();

    if (longCount > 1 && last < startPriceLong && ClosedIfInProfitLong())
        return;
    if (shortCount > 1 && last > startPriceShort && ClosedIfInProfitShort())
        return;

    if (longCount > 0 && last > startPriceLong && last > lastPriceLong + WinGridDistance)
        TrailLong();
    if (shortCount > 0 && last < startPriceShort && last < lastPriceShort - WinGridDistance)
        TrailShort();

    if (longCount > 0)
    {
        if (last > lastPriceLong + WinGridDistance && last > startPriceLong)
        {
            trade.Buy(multiplierWinLot && longCount > 1 ? lotSizeBuy * Multiplier : lotSizeBuy);
            lastPriceLong = last;
        }
        if (adaptiveLossGrid && longCount > 1)
        {
            LossGridDistance = LossAtr();
            Multiplier = 2;
            LossGridDistance = LossGridDistance * longCount;
            Multiplier = longCount;
        }
        if (last < lastPriceLong - LossGridDistance && last < startPriceLong)
        {
            double lotSizeAdaptive = lotSizeBuy * longCount * Multiplier;
            if (fasterLossGrid)
                lotSizeAdaptive = lotSizeBuy * longCount;
            trade.Buy(lotSizeAdaptive);
            lastPriceLong = last;
        }
        if (adaptiveLossGrid && longCount > 1)
        {
            LossGridDistance = LossAtr();
            Multiplier = 2;
        }
    }
    if (shortCount > 0)
    {
        if (last < lastPriceShort - WinGridDistance && last < startPriceShort)
        {
            trade.Sell(multiplierWinLot && shortCount > 1 ? lotSizeSell * Multiplier : lotSizeSell);
            lastPriceShort = last;
        }
        if (adaptiveLossGrid && shortCount > 1)
        {
            LossGridDistance = LossAtr();
            Multiplier = 2;
            LossGridDistance = LossGridDistance * shortCount;
            Multiplier = shortCount;
        }
        if (last > lastPriceShort + LossGridDistance && last > startPriceShort)
        {
            double lotSizeAdaptive = lotSizeSell * shortCount * Multiplier;
            if (fasterLossGrid)
                lotSizeAdaptive = lotSizeSell * shortCount;
            trade.Sell(lotSizeAdaptive);
            lastPriceShort = last;
        }
        if (adaptiveLossGrid && shortCount > 1)
        {
            LossGridDistance = LossAtr();
            Multiplier = 2;
        }
    }

    if (IsChartComment)
        Comment("Win Money: ", NormalizeDouble(winMoney, 2), " | Period: ", Period,
                " | win distance: ", NormalizeDouble(WinGridDistance, Digits()),
                " | loss distance: ", NormalizeDouble(LossGridDistance, Digits()),
                "\nLong: Count: ", longCount, " > Profit: ", NormalizeDouble(profitLong, 2),
                " | Last Price: ", NormalizeDouble(lastPriceLong, Period()),
                " | Start Price: ", NormalizeDouble(startPriceLong, Period()),
                "\nShort: Count: ", shortCount, " > Profit: ", NormalizeDouble(profitShort, 2),
                " | Last Price: ", NormalizeDouble(lastPriceShort, Period()),
                " | Start Price: ", NormalizeDouble(startPriceShort, Period()));
}

double WinAtr()
{
    int atrHandle = iATR(pair, WinTimeFrame, Period);
    double atr[];
    ArraySetAsSeries(atr, true);
    CopyBuffer(atrHandle, MAIN_LINE, 0, 2, atr);
    return atr[0];
}

double LossAtr()
{
    int atrHandle = iATR(pair, LossTimeFrame, Period);
    double atr[];
    ArraySetAsSeries(atr, true);
    CopyBuffer(atrHandle, MAIN_LINE, 0, 2, atr);
    return atr[0];
}

void SetStartPriceLong()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber)
            continue;
        if (PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
            continue;
        startPriceLong = PositionGetDouble(POSITION_PRICE_OPEN);
        lastPriceLong = PositionGetDouble(POSITION_PRICE_OPEN);
    }
}

void SetStartPriceShort()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber)
            continue;
        if (PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
            continue;
        startPriceShort = PositionGetDouble(POSITION_PRICE_OPEN);
        lastPriceShort = PositionGetDouble(POSITION_PRICE_OPEN);
    }
}

bool ClosedIfInProfitLong()
{
    bool closed = false;
    double profit = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber)
            continue;
        if (PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
            continue;
        profit += PositionGetDouble(POSITION_PROFIT);
    }
    if (profit > winMoney)
    {
        for (int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if (!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber)
                continue;
            if (PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
                continue;
            trade.PositionClose(ticket);
            closed = true;
        }
    }
    profitLong = profit;
    return closed;
}

bool ClosedIfInProfitShort()
{
    bool closed = false;
    double profit = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber)
            continue;
        if (PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
            continue;
        profit += PositionGetDouble(POSITION_PROFIT);
    }
    if (profit > winMoney)
    {
        for (int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if (!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber)
                continue;
            if (PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
                continue;
            trade.PositionClose(ticket);
            closed = true;
        }
    }
    profitShort = profit;
    return closed;
}

void TrailLong()
{
    double stop = NormalizeDouble(last - TrailDistance, _Digits);
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber)
            continue;
        if (PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
            continue;
        if (PositionGetDouble(POSITION_SL) == stop)
            continue;

        trade.PositionModify(ticket, stop, 0);
    }
}

void TrailShort()
{
    double stop = NormalizeDouble(last + TrailDistance, _Digits);
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber)
            continue;
        if (PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
            continue;
        if (PositionGetDouble(POSITION_SL) == stop)
            continue;

        trade.PositionModify(ticket, stop, 0);
    }
}

int PositionCountLong()
{
    int count = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber)
            continue;
        if (PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
            continue;

        count++;
    }
    return count;
}

int PositionCountShort()
{
    int count = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber)
            continue;
        if (PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
            continue;

        count++;
    }
    return count;
}

double capital = AccountInfoDouble(ACCOUNT_BALANCE);
double contractSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_CONTRACT_SIZE);
double tickSize = SymbolInfoDouble(pair, SYMBOL_TRADE_TICK_SIZE);
double tickValue = SymbolInfoDouble(pair, SYMBOL_TRADE_TICK_VALUE);
double lotStep = SymbolInfoDouble(pair, SYMBOL_VOLUME_STEP);
double minVol = SymbolInfoDouble(pair, SYMBOL_VOLUME_MIN);
double maxVol = SymbolInfoDouble(pair, SYMBOL_VOLUME_MAX);
double Volume()
{
    if (RiskValue == RISK_VALUE_LOT)
        return RiskValueAmount;

    if (RiskType == RISK_TYPE_BALANCE)
        capital = AccountInfoDouble(ACCOUNT_BALANCE);
    if (RiskType == RISK_TYPE_EQUITY)
        capital = AccountInfoDouble(ACCOUNT_EQUITY);

    double riskMoney = capital * RiskValueAmount * 0.01;
    double moneyLotStep = distance / tickSize * tickValue * lotStep;
    double lots = MathFloor(riskMoney / moneyLotStep) * lotStep;

    if (lots < minVol)
        return minVol;

    if (lots > maxVol)
        return maxVol;

    return lots;
}

double CalculateWinMoney()
{
    double moneyLotStep = distance / tickSize * tickValue * lotStep;
    if (RiskValue == RISK_VALUE_LOT)
        return (RiskValueAmount / lotStep) * moneyLotStep;
    else
        return capital * RiskValueAmount * 0.01;
}