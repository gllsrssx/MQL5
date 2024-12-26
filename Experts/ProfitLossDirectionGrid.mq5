
#property copyright "Copyright 2024, GllsRssx Ltd."
#property link "https://www.rssx.eu"
#property version "2.0"
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
input ENUM_RISK_VALUE RiskValue = RISK_VALUE_LOT; // Risk Value
enum ENUM_RISK_TYPE
{
    RISK_TYPE_BALANCE,
    RISK_TYPE_EQUITY,
    RISK_TYPE_STATIC
};
input ENUM_RISK_TYPE RiskType = RISK_TYPE_STATIC; // Risk Type
input group "Grid";
input double WinGridDistance = 200;   // Win Grid Distance
input double LossGridDistance = 1000; // Loss Grid Distance
input double TrailPercent = 0.5;      // Trail Percent

input group "Info";
input bool IsChartComment = true;  // Chart Comment
input long MagicNumber = 88888888; // Magic Number
input group "Time";
input int StartHour = 00;   // Start Hour
input int startMinute = 06; // Start Minute
input int StopHour = 22;    // Stop Hour
input int StopMinute = 53;  // Stop Minute

double TrailDistance = WinGridDistance * TrailPercent; // Trail Distance
int Multiplier = 1;                                    // Multiplier
double winMoney;                                       // Win Money

double lastPriceLong;
double lastPriceShort;
double startPriceLong;
double startPriceShort;
double profitLong;
double profitShort;
double distance = WinGridDistance * Point();

string pair = Symbol();

int OnInit()
{
    double bid = SymbolInfoDouble(pair, SYMBOL_BID);
    double ask = SymbolInfoDouble(pair, SYMBOL_ASK);
    winMoney = CalculateWinMoney();
    lastPriceLong = bid;
    lastPriceShort = ask;
    startPriceLong = bid;
    startPriceShort = ask;
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
    int longCount = PositionCountLong();
    int shortCount = PositionCountShort();
    double lotSize = Volume();
    winMoney = CalculateWinMoney();

    if (longCount == 0)
    {
        trade.Buy(lotSize);
        lastPriceLong = bid;
        startPriceLong = bid;
        return;
    }

    if (shortCount == 0)
    {
        trade.Sell(lotSize);
        lastPriceShort = ask;
        startPriceShort = ask;
        return;
    }

    if (longCount > 1 && bid > startPriceLong && bid > lastPriceLong + WinGridDistance * _Point)
    {
        TrailLong();
    }

    if (shortCount > 1 && ask < startPriceShort && ask < lastPriceShort - WinGridDistance * _Point)
    {
        TrailShort();
    }

    if (longCount > 0)
    {
        if (bid > lastPriceLong + WinGridDistance * _Point && bid > startPriceLong)
        {
            trade.Buy(lotSize);
            lastPriceLong = bid;
        }
        if (bid < lastPriceLong - LossGridDistance * _Point && bid < startPriceLong)
        {
            trade.Buy(lotSize * longCount * Multiplier);
            lastPriceLong = bid;
        }
    }

    if (shortCount > 0)
    {
        if (ask < lastPriceShort - WinGridDistance * _Point && ask < startPriceShort)
        {
            trade.Sell(lotSize);
            lastPriceShort = ask;
        }
        if (ask > lastPriceShort + LossGridDistance * _Point && ask > startPriceShort)
        {
            trade.Sell(lotSize * shortCount * Multiplier);
            lastPriceShort = ask;
        }
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
        Comment("Win Money: ", NormalizeDouble(winMoney, 2),
                "\nLong: Count: ", longCount, " > Profit: ", NormalizeDouble(profitLong, 2),
                " | Last Price: ", NormalizeDouble(lastPriceLong, Digits()),
                " | Start Price: ", NormalizeDouble(startPriceLong, Digits()),
                "\nShort: Count: ", shortCount, " > Profit: ", NormalizeDouble(profitShort, 2),
                " | Last Price: ", NormalizeDouble(lastPriceShort, Digits()),
                " | Start Price: ", NormalizeDouble(startPriceShort, Digits()));

    if (longCount == 1)
        SetStartPriceLong();
    if (shortCount == 1)
        SetStartPriceShort();
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
    double stop = NormalizeDouble(bid - TrailDistance * _Point, _Digits);
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
    double stop = NormalizeDouble(ask + TrailDistance * _Point, _Digits);
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