
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
input ENUM_RISK_TYPE RiskType = RISK_TYPE_STATIC; // Risk Type
input group "Grid";
input ENUM_TIMEFRAMES WinTimeFrame = PERIOD_M10;  // Win Time Frame
input ENUM_TIMEFRAMES LossTimeFrame = PERIOD_M10; // Loss Time Frame
input double TrailPercent = 0.5;                  // Trail Percent
input bool adaptiveLossGrid = true;               // Adaptive Loss Grid
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
int Multiplier = 1;      // Multiplier

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

    // period is lowest value of barsPeriod, barsWin, barsLoss
    Period = MathMin(barsPeriod, MathMin(barsWin, barsLoss));

    double bid = SymbolInfoDouble(pair, SYMBOL_BID);
    double ask = SymbolInfoDouble(pair, SYMBOL_ASK);
    WinGridDistance = WinAtr();
    LossGridDistance = LossAtr();
    winMoney = CalculateWinMoney();
    lastPriceLong = ask;
    lastPriceShort = bid;
    startPriceLong = ask;
    startPriceShort = bid;
    profitLong = 0;
    profitShort = 0;
    distance = WinGridDistance;

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
    int longCount = PositionCountLong();
    int shortCount = PositionCountShort();
    WinGridDistance = WinAtr();
    if (ask - bid >= WinGridDistance)
        WinGridDistance = WinGridDistance + (ask - bid);
    LossGridDistance = LossAtr();
    if (ask - bid >= LossGridDistance)
        LossGridDistance = LossGridDistance + (ask - bid);
    TrailDistance = WinGridDistance * TrailPercent;
    distance = WinGridDistance;
    if (WinGridDistance == 0 || LossGridDistance == 0)
        return;
    winMoney = CalculateWinMoney();

    if (longCount == 0)
    {
        lotSizeBuy = Volume();
        trade.Buy(lotSizeBuy);
        lastPriceLong = ask;
        startPriceLong = ask;
        return;
    }

    if (shortCount == 0)
    {
        lotSizeSell = Volume();
        trade.Sell(lotSizeSell);
        lastPriceShort = bid;
        startPriceShort = bid;
        return;
    }

    if (longCount > 1 && bid > startPriceLong && bid > lastPriceLong + WinGridDistance)
    {
        TrailLong();
    }

    if (shortCount > 1 && ask < startPriceShort && ask < lastPriceShort - WinGridDistance)
    {
        TrailShort();
    }

    if (longCount > 0)
    {
        if (ask > lastPriceLong + WinGridDistance && ask > startPriceLong)
        {
            trade.Buy(lotSizeBuy);
            lastPriceLong = ask;
        }
        if (adaptiveLossGrid && longCount > 1)
        {
            LossGridDistance = LossAtr();
            Multiplier = 1;
            LossGridDistance = LossGridDistance * longCount;
            Multiplier = longCount;
        }
        if (ask < lastPriceLong - LossGridDistance && ask < startPriceLong)
        {
            trade.Buy(lotSizeBuy * longCount * Multiplier);
            lastPriceLong = ask;
        }
        LossGridDistance = LossAtr();
        Multiplier = 1;
    }

    if (shortCount > 0)
    {
        if (bid < lastPriceShort - WinGridDistance && bid < startPriceShort)
        {
            trade.Sell(lotSizeSell);
            lastPriceShort = bid;
        }
        if (adaptiveLossGrid && shortCount > 1)
        {
            LossGridDistance = LossAtr();
            Multiplier = 1;
            LossGridDistance = LossGridDistance * shortCount;
            Multiplier = shortCount;
        }
        if (bid > lastPriceShort + LossGridDistance && bid > startPriceShort)
        {
            trade.Sell(lotSizeSell * shortCount * Multiplier);
            lastPriceShort = bid;
        }
        LossGridDistance = LossAtr();
        Multiplier = 1;
    }

    if (longCount > 1 && bid < startPriceLong)
    {
        CloseIfInProfitLong();
    }

    if (shortCount > 1 && ask > startPriceShort)
    {
        CloseIfInProfitShort();
    }

    if (IsChartComment)
        Comment("Win Money: ", NormalizeDouble(winMoney, 2), " | Period: ", Period,
                " | win distance: ", MathRound(WinGridDistance * Point()),
                " | loss distance: ", MathRound(LossGridDistance * Point()),
                "\nLong: Count: ", longCount, " > Profit: ", NormalizeDouble(profitLong, 2),
                " | Last Price: ", NormalizeDouble(lastPriceLong, Period()),
                " | Start Price: ", NormalizeDouble(startPriceLong, Period()),
                "\nShort: Count: ", shortCount, " > Profit: ", NormalizeDouble(profitShort, 2),
                " | Last Price: ", NormalizeDouble(lastPriceShort, Period()),
                " | Start Price: ", NormalizeDouble(startPriceShort, Period()));

    if (longCount == 1)
        SetStartPriceLong();
    if (shortCount == 1)
        SetStartPriceShort();
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
    }
}

void CloseIfInProfitLong()
{
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
        }
    }
    profitLong = profit;
}

void CloseIfInProfitShort()
{
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
        }
    }
    profitShort = profit;
}

void TrailLong()
{
    double bid = SymbolInfoDouble(pair, SYMBOL_BID);
    double stop = NormalizeDouble(bid - TrailDistance, _Digits);
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
    double ask = SymbolInfoDouble(pair, SYMBOL_ASK);
    double stop = NormalizeDouble(ask + TrailDistance, _Digits);
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