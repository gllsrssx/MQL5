
#property copyright "Copyright 2024, GllsRssx Ltd."
#property link "https://www.rssx.eu"
#property version "2.0"
#property description "grid."

#include <Trade\Trade.mqh>
CTrade trade;

input double Risk = 0.1;
input double WinGridDistance = 100;
input double LossGridDistance = 300;
input double TrailDistance = 50;
input double winMoney = 10;

double lastPriceLong;
double lastPriceShort;
double startPriceLong;
double startPriceShort;
double profitLong;
double profitShort;

int OnInit()
{
    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    int longCount = PositionCountLong();
    int shortCount = PositionCountShort();

    if (longCount == 0)
    {
        trade.Buy(0.1);
        lastPriceLong = bid;
        startPriceLong = bid;
    }

    if (shortCount == 0)
    {
        trade.Sell(0.1);
        lastPriceShort = ask;
        startPriceShort = ask;
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
        if (bid > lastPriceLong + WinGridDistance * _Point)
        {
            trade.Buy(0.1);
            lastPriceLong = bid;
        }
        if (bid < lastPriceLong - LossGridDistance * _Point)
        {
            trade.Buy(0.1 * longCount * 3);
            lastPriceLong = bid;
        }
    }

    if (shortCount > 0)
    {
        if (ask < lastPriceShort - WinGridDistance * _Point)
        {
            trade.Sell(0.1);
            lastPriceShort = ask;
        }
        if (ask > lastPriceShort + LossGridDistance * _Point)
        {
            trade.Sell(0.1 * shortCount * 3);
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

    Comment("WM", winMoney, " \n Long Count: ", longCount, " > Profit: ", profitLong, " \n Short Count: ", shortCount, " > Profit: ", profitShort);
}

void CloseIfInProfitLong()
{
    double profit = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket))
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
            if (!PositionSelectByTicket(ticket))
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
        if (!PositionSelectByTicket(ticket))
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
            if (!PositionSelectByTicket(ticket))
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
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double stop = NormalizeDouble(bid - TrailDistance * _Point, _Digits);
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket))
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
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double stop = NormalizeDouble(ask + TrailDistance * _Point, _Digits);
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket))
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
        if (!PositionSelectByTicket(ticket))
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
        if (!PositionSelectByTicket(ticket))
            continue;
        if (PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
            continue;

        count++;
    }
    return count;
}
