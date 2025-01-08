
#property copyright "Copyright 2024, GllsRssx Ltd."
#property link "https://www.rssx.be"
#property version "4.3"
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
input int InpPeriod = 0; // Period (0=auto)
enum ENUM_RISK_TIMEFRAMES
{
    RISK_TIMEFRAMES_WIN, // Win Time Frame risk
    RISK_TIMEFRAMES_LOSS // Loss Time Frame risk
};
input ENUM_TIMEFRAMES WinTimeFrame = PERIOD_D1;                  // Win Time Frame
input ENUM_TIMEFRAMES LossTimeFrame = PERIOD_D1;                 // Loss Time Frame
input ENUM_RISK_TIMEFRAMES RiskTimeFrame = RISK_TIMEFRAMES_LOSS; // Risk Time Frame
input double TrailPercent = 0.5;                                 // Trail Percent Win
input bool keepLastWinOpen = true;                               // Keep Last Win Open
input bool multiplierWinLot = false;                             // Multiplier Win Lot
input bool multiplierLossLot = true;                             // Multiplier Loss Lot
input bool adaptiveLossGrid = false;                             // Adaptive Loss Grid
int Multiplier = 2;                                              // Multiplier Loss Lot start
bool multiplierLossLotAdaptive = false;                          // Multiplier Loss Lot Adaptive (c*c)
bool multiplierWinLotAdaptive = false;                           // Multiplier Win Lot Adaptive (c*c)
input bool LongTrades = true;                                    // Long Trades
input bool ShortTrades = true;                                   // Short Trades
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
double totalLotsTraded = 0;
double last;
int longCount;
int shortCount;
double lastPriceLong;
double lastPriceShort;
double startPriceLong;
double startPriceShort;
double profitLong = 0;
double profitShort = 0;
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
    if (InpPeriod > 0)
    {
        Period = InpPeriod;
    }

    longCount = PositionCountLong();
    shortCount = PositionCountShort();
    if (longCount > 1)
        CheckStartAndLastPriceLong();
    if (shortCount > 1)
        CheckStartAndLastPriceShort();

    trade.SetExpertMagicNumber(MagicNumber);
    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    Print("Total lots traded: ", totalLotsTraded);
}

void OnTick()
{
    double bid = SymbolInfoDouble(pair, SYMBOL_BID);
    double ask = SymbolInfoDouble(pair, SYMBOL_ASK);
    last = (bid + ask) / 2;
    double spread = ask - bid;
    longCount = PositionCountLong();
    shortCount = PositionCountShort();
    WinGridDistance = WinAtr() + spread;
    LossGridDistance = LossAtr() + spread;
    TrailDistance = WinGridDistance * TrailPercent;
    distance = RiskTimeFrame == RISK_TIMEFRAMES_WIN ? WinGridDistance : LossGridDistance;
    winMoney = CalculateWinMoney();

    MqlDateTime mdt;
    TimeCurrent(mdt);
    int hour = mdt.hour;
    int minute = mdt.min;
    if (hour < StartHour || hour > StopHour || (hour == StartHour && minute < startMinute) || (hour == StopHour && minute > StopMinute))
        return;

    if (longCount == 0 && LongTrades)
    {
        double vol = Volume();
        if (!trade.Buy(vol))
            return;
        lotSizeBuy = vol;
        totalLotsTraded += lotSizeBuy;
        lastPriceLong = last;
        startPriceLong = last;
        return;
    }
    if (shortCount == 0 && ShortTrades)
    {
        double vol = Volume();
        if (!trade.Sell(vol))
            return;
        lotSizeSell = vol;
        totalLotsTraded += lotSizeSell;
        lastPriceShort = last;
        startPriceShort = last;
        return;
    }

    if (longCount == 1)
        SetStartPriceLong();
    if (shortCount == 1)
        SetStartPriceShort();

    if (longCount > 0)
    {
        TrailLong();
        LongGridExecute();
    }
    if (shortCount > 0)
    {
        TrailShort();
        ShortGridExecute();
    }

    if (ClosedIfInProfitLong())
        return;
    if (ClosedIfInProfitShort())
        return;

    if (IsChartComment)
        Comment("\nWin Money: ", NormalizeDouble(winMoney, 2), " | lots traded: ", NormalizeDouble(totalLotsTraded, 2),
                "\nPeriod: ", Period, " | Win ATR: ", NormalizeDouble(WinAtr(), Digits()), " | Loss ATR: ", NormalizeDouble(LossAtr(), Digits()),
                "\nwin distance: ", NormalizeDouble(WinGridDistance, Digits()),
                " | loss distance: ", NormalizeDouble(LossGridDistance, Digits()),
                "\nLong: Count: ", longCount, " > Profit: ", NormalizeDouble(profitLong, 2),
                " | Last Price: ", NormalizeDouble(lastPriceLong, Period()),
                " | Start Price: ", NormalizeDouble(startPriceLong, Period()),
                "\nShort: Count: ", shortCount, " > Profit: ", NormalizeDouble(profitShort, 2),
                " | Last Price: ", NormalizeDouble(lastPriceShort, Period()),
                " | Start Price: ", NormalizeDouble(startPriceShort, Period()));
}

void LongGridExecute()
{
    if (longCount > 0)
    {
        if (last > lastPriceLong + WinGridDistance && last > startPriceLong)
        {
            double lotSizeAdaptive = multiplierWinLot && longCount > 1 ? lotSizeBuy * (multiplierWinLotAdaptive ? longCount * longCount : longCount) : lotSizeBuy;
            lotSizeAdaptive = MathFloor(lotSizeAdaptive / lotStep) * lotStep;
            if (!trade.Buy(lotSizeAdaptive))
                return;
            if (!keepLastWinOpen)
                TrailLong();
            totalLotsTraded += lotSizeAdaptive;
            lastPriceLong = last;
        }
        if (adaptiveLossGrid && longCount > 1)
        {
            LossGridDistance = LossGridDistance * longCount;
        }
        if (last < lastPriceLong - LossGridDistance && last < startPriceLong)
        {
            double lotSizeAdaptive = multiplierLossLot ? lotSizeBuy * longCount * (multiplierLossLotAdaptive && longCount > 1 ? longCount : Multiplier) : lotSizeBuy;
            lotSizeAdaptive = MathFloor(lotSizeAdaptive / lotStep) * lotStep;
            if (!trade.Buy(lotSizeAdaptive))
                return;
            if (!keepLastWinOpen)
                TrailLong();
            totalLotsTraded += lotSizeAdaptive;
            lastPriceLong = last;
        }
        if (adaptiveLossGrid && longCount > 1)
        {
            LossGridDistance = LossAtr();
        }
    }
}

void ShortGridExecute()
{
    if (shortCount > 0)
    {
        if (last < lastPriceShort - WinGridDistance && last < startPriceShort)
        {
            double lotSizeAdaptive = multiplierWinLot && shortCount > 1 ? lotSizeSell * (multiplierWinLotAdaptive ? shortCount * shortCount : shortCount) : lotSizeSell;
            lotSizeAdaptive = MathFloor(lotSizeAdaptive / lotStep) * lotStep;
            if (!trade.Sell(lotSizeAdaptive))
                return;
            if (!keepLastWinOpen)
                TrailShort();
            totalLotsTraded += lotSizeAdaptive;
            lastPriceShort = last;
        }
        if (adaptiveLossGrid && shortCount > 1)
        {
            LossGridDistance = LossGridDistance * shortCount;
        }
        if (last > lastPriceShort + LossGridDistance && last > startPriceShort)
        {
            double lotSizeAdaptive = multiplierLossLot ? lotSizeSell * shortCount * (multiplierLossLotAdaptive && shortCount > 1 ? shortCount : Multiplier) : lotSizeSell;
            lotSizeAdaptive = MathFloor(lotSizeAdaptive / lotStep) * lotStep;
            if (!trade.Sell(lotSizeAdaptive))
                return;
            if (!keepLastWinOpen)
                TrailShort();
            totalLotsTraded += lotSizeAdaptive;
            lastPriceShort = last;
        }
        if (adaptiveLossGrid && shortCount > 1)
        {
            LossGridDistance = LossAtr();
        }
    }
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
    if (!(longCount > 1 && last < startPriceLong))
        return false;
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
            if (!trade.PositionClose(ticket))
                Print("PositionClose() method failed. Return code=", trade.ResultRetcode(), ". Code description: ", trade.ResultRetcodeDescription());
            closed = true;
        }
    }
    profitLong = profit;
    return closed;
}

bool ClosedIfInProfitShort()
{
    if (!(shortCount > 1 && last > startPriceShort))
        return false;
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
            if (!trade.PositionClose(ticket))
                Print("PositionClose() method failed. Return code=", trade.ResultRetcode(), ". Code description: ", trade.ResultRetcodeDescription());
            closed = true;
        }
    }
    profitShort = profit;
    return closed;
}

void TrailLong()
{
    if (longCount > 0 && last > startPriceLong && last > lastPriceLong + WinGridDistance)
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

            if (!trade.PositionModify(ticket, stop, 0))
                return;
        }
    }
}

void TrailShort()
{
    if (shortCount > 0 && last < startPriceShort && last < lastPriceShort - WinGridDistance)
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

            if (!trade.PositionModify(ticket, stop, 0))
                return;
        }
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

void CheckStartAndLastPriceLong()
{
    double startPrice = profitLong > 0 ? INT_MAX : 0;
    double lastPrice = profitLong > 0 ? 0 : INT_MAX;

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
            continue;

        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

        if (profitLong > 0)
        {
            startPrice = MathMin(startPrice, openPrice);
            lastPrice = MathMax(lastPrice, openPrice);
        }
        else
        {
            startPrice = MathMax(startPrice, openPrice);
            lastPrice = MathMin(lastPrice, openPrice);
        }
    }
}

void CheckStartAndLastPriceShort()
{
    double startPrice = profitShort > 0 ? 0 : INT_MAX;
    double lastPrice = profitShort > 0 ? INT_MAX : 0;

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
            continue;

        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

        if (profitShort > 0)
        {
            startPrice = MathMax(startPrice, openPrice);
            lastPrice = MathMin(lastPrice, openPrice);
        }
        else
        {
            startPrice = MathMin(startPrice, openPrice);
            lastPrice = MathMax(lastPrice, openPrice);
        }
    }
}