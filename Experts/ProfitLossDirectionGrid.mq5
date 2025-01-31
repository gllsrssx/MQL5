
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
input group "Win Grid";
input double TrailPercent = 0.5;     // Trail Percent Win
input bool keepLastWinOpen = true;   // Keep Last Win Open
input bool multiplierWinLot = false; // Multiplier Win Lot
input group "Loss Grid";
input bool multiplierLossLot = true;           // Multiplier Loss Lot
input bool adaptiveLossGrid = false;           // Adaptive Loss Grid
input bool closeLossGridInBE = false;          // Close Loss Grid in BE
int Multiplier = 2;                            // Multiplier Loss Lot start
input group "Side";
input bool LongTrades = true;  // Long Trades
input bool ShortTrades = true; // Short Trades
input group "Info";
input long MagicNumber = 88888888; // Magic Number
input bool IsChartComment = true;  // Chart Comment
bool DebugConsole = false;         // Debug Console
input group "Time";
input int StartHour = 0;   // Start Hour
input int startMinute = 6; // Start Minute
input int StopHour = 23;   // Stop Hour
input int StopMinute = 54; // Stop Minute
input group "EMA";
input bool EmaFilter = true; // use ema filter
input int EmaPeriod = 100; // ema period
input ENUM_TIMEFRAMES EmaTimeframe = PERIOD_D1; // ema timeframe 

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
    Period = MathMin(barsPeriod, MathMin(barsWin, barsLoss)) / 2;
    if (InpPeriod > 0)
    {
        Period = InpPeriod;
    }

    longCount = PositionCountLong();
    shortCount = PositionCountShort();
    CheckProfitLong();
    CheckProfitShort();
    if (longCount > 1)
        CheckStartAndLastPriceLong();
    if (shortCount > 1)
        CheckStartAndLastPriceShort();

    trade.SetExpertMagicNumber(MagicNumber);
    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    Comment("");
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
    double winAtr = WinAtr();
    double lossAtr = LossAtr();
    WinGridDistance = winAtr + spread;
    LossGridDistance = lossAtr + spread;
    if (winAtr == 0 || lossAtr == 0)
    {
        Print("ATR FAILED!", " | winAtr: ", winAtr, " | lossAtr: ", lossAtr, " | spread: ", spread, " Period: ", Period);
        return;
    }
    TrailDistance = WinGridDistance * TrailPercent;
    distance = RiskTimeFrame == RISK_TIMEFRAMES_WIN ? WinGridDistance : LossGridDistance;
    winMoney = closeLossGridInBE ? 0 : CalculateWinMoney();
    int direction = GetEMADirection();

    MqlDateTime mdt;
    TimeCurrent(mdt);
    int hour = mdt.hour;
    int minute = mdt.min;
    if (hour < StartHour || hour > StopHour || (hour == StartHour && minute < startMinute) || (hour == StopHour && minute > StopMinute))
        return;

    if (longCount == 0 && LongTrades && direction != -1)
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
    if (shortCount == 0 && ShortTrades && direction != 1)
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

    if (longCount > 1 && lastPriceLong == 0 && startPriceLong == 0)
    {
        CheckStartAndLastPriceLong();
        return;
    }
    if (shortCount > 1 && lastPriceShort == 0 && startPriceShort == 0)
    {
        CheckStartAndLastPriceShort();
        return;
    }

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

    if (longCount > 1)
        ClosedIfInProfitLong();
    if (shortCount > 1)
        ClosedIfInProfitShort();

    CheckProfitLong();
    CheckProfitShort();

    if (IsChartComment)
        Comment("\nWin Money: ", NormalizeDouble(winMoney, 2), " | lots traded: ", NormalizeDouble(totalLotsTraded, 2), " | Multiplier: ", Multiplier, " | Direction: ", direction,
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

int GetEMADirection()
{
   if (!EmaFilter) return 0;
   
    double emaValues[];
    double closePrices[];
    int direction = 0;
    
    // Resize arrays
    ArraySetAsSeries(emaValues, true);
    ArraySetAsSeries(closePrices, true);
    
    // Get EMA values
    if (iMA(Symbol(), EmaTimeframe, EmaPeriod, 0, MODE_EMA, PRICE_CLOSE) == INVALID_HANDLE)
        return 0;
    
    CopyBuffer(iMA(Symbol(), EmaTimeframe, EmaPeriod, 0, MODE_EMA, PRICE_CLOSE), 0, 0, EmaPeriod, emaValues);
    CopyClose(Symbol(), PERIOD_CURRENT, 0, EmaPeriod, closePrices);
    
    // Check if price is above or below EMA for the full period
    bool above = true, below = true;
    for (int i = 0; i < EmaPeriod; i++)
    {
        if (closePrices[i] <= emaValues[i])
            above = false;
        if (closePrices[i] >= emaValues[i])
            below = false;
    }
    
    if (above)
        direction = 1;
    else if (below)
        direction = -1;
    
    return direction;
}

void LongGridExecute()
{
    if (longCount == 0)
        return;
    if (last > lastPriceLong + WinGridDistance && last > startPriceLong)
    {
        double lotSizeAdaptive = multiplierWinLot ? lotSizeBuy * longCount * Multiplier : lotSizeBuy;
        if (DebugConsole)
            Print("lotSizeAdaptive: ", lotSizeAdaptive, " | lotSizeBuy: ", lotSizeBuy, " | longCount: ", longCount, " | Multiplier: ", Multiplier);
        lotSizeAdaptive = MathFloor(lotSizeAdaptive / lotStep) * lotStep;
        do
        {
            if (!trade.Buy(lotSizeAdaptive > maxVol ? maxVol : lotSizeAdaptive))
                return;
            totalLotsTraded += lotSizeAdaptive > maxVol ? maxVol : lotSizeAdaptive;
            lotSizeAdaptive = MathFloor(lotSizeAdaptive - maxVol / lotStep) * lotStep;
        } while (lotSizeAdaptive > lotStep);
        if (!keepLastWinOpen)
            TrailLong();
        lastPriceLong = last;
    }
    if (adaptiveLossGrid && longCount > 1)
    {
        LossGridDistance = LossGridDistance * longCount;
    }
    if (last < lastPriceLong - LossGridDistance && last < startPriceLong)
    {
        double lotSizeAdaptive = multiplierLossLot ? lotSizeBuy * longCount * Multiplier : lotSizeBuy;
        lotSizeAdaptive = MathFloor(lotSizeAdaptive / lotStep) * lotStep;
        do
        {
            if (!trade.Buy(lotSizeAdaptive > maxVol ? maxVol : lotSizeAdaptive))
                return;
            totalLotsTraded += lotSizeAdaptive > maxVol ? maxVol : lotSizeAdaptive;
            lotSizeAdaptive = MathFloor(lotSizeAdaptive - maxVol / lotStep) * lotStep;
        } while (lotSizeAdaptive > lotStep);
        if (!keepLastWinOpen)
            TrailLong();
        lastPriceLong = last;
    }
    if (adaptiveLossGrid && longCount > 1)
    {
        LossGridDistance = LossAtr();
    }
}

void ShortGridExecute()
{
    if (shortCount == 0)
        return;
    if (last < lastPriceShort - WinGridDistance && last < startPriceShort)
    {
        double lotSizeAdaptive = multiplierWinLot ? lotSizeSell * shortCount * Multiplier : lotSizeSell;
        if (DebugConsole)
            Print("lotSizeAdaptive: ", lotSizeAdaptive, " | lotSizeSell: ", lotSizeSell, " | shortCount: ", shortCount, " | Multiplier: ", Multiplier);
        lotSizeAdaptive = MathFloor(lotSizeAdaptive / lotStep) * lotStep;
        do
        {
            if (!trade.Sell(lotSizeAdaptive > maxVol ? maxVol : lotSizeAdaptive))
                return;
            totalLotsTraded += lotSizeAdaptive > maxVol ? maxVol : lotSizeAdaptive;
            lotSizeAdaptive = MathFloor(lotSizeAdaptive - maxVol / lotStep) * lotStep;
        } while (lotSizeAdaptive > lotStep);
        if (!keepLastWinOpen)
            TrailShort();
        lastPriceShort = last;
    }
    if (adaptiveLossGrid && shortCount > 1)
    {
        LossGridDistance = LossGridDistance * shortCount;
    }
    if (last > lastPriceShort + LossGridDistance && last > startPriceShort)
    {
        double lotSizeAdaptive = multiplierLossLot ? lotSizeSell * shortCount * Multiplier : lotSizeSell;
        lotSizeAdaptive = MathFloor(lotSizeAdaptive / lotStep) * lotStep;
        do
        {
            if (!trade.Sell(lotSizeAdaptive > maxVol ? maxVol : lotSizeAdaptive))
                return;
            totalLotsTraded += lotSizeAdaptive > maxVol ? maxVol : lotSizeAdaptive;
            lotSizeAdaptive = MathFloor(lotSizeAdaptive - maxVol / lotStep) * lotStep;
        } while (lotSizeAdaptive > lotStep);
        if (!keepLastWinOpen)
            TrailShort();
        lastPriceShort = last;
    }
    if (adaptiveLossGrid && shortCount > 1)
    {
        LossGridDistance = LossAtr();
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
        if (!PositionSelectByTicket(ticket))
            continue;
        if (PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
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
        if (!PositionSelectByTicket(ticket))
            continue;
        if (PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
            continue;
        startPriceShort = PositionGetDouble(POSITION_PRICE_OPEN);
        lastPriceShort = PositionGetDouble(POSITION_PRICE_OPEN);
    }
}

void ClosedIfInProfitLong()
{
    if (!(longCount > 1 && last < startPriceLong))
        return;
    CheckProfitLong();
    if (profitLong > winMoney)
    {
        for (int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if (!PositionSelectByTicket(ticket))
                continue;
            if (PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
                continue;
            if (!trade.PositionClose(ticket))
                Print("PositionClose() method failed. Return code=", trade.ResultRetcode(), ". Code description: ", trade.ResultRetcodeDescription());
        }
    }
    PositionCountLong();
}

void ClosedIfInProfitShort()
{
    if (!(shortCount > 1 && last > startPriceShort))
        return;
    CheckProfitShort();
    if (profitShort > winMoney)
    {
        for (int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if (!PositionSelectByTicket(ticket))
                continue;
            if (PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
                continue;
            if (!trade.PositionClose(ticket))
                Print("PositionClose() method failed. Return code=", trade.ResultRetcode(), ". Code description: ", trade.ResultRetcodeDescription());
        }
    }
    PositionCountShort();
}

void TrailLong()
{
    if (longCount > 0 && last > startPriceLong && last > lastPriceLong + WinGridDistance)
    {
        double stop = NormalizeDouble(last - TrailDistance, _Digits);
        for (int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if (!PositionSelectByTicket(ticket))
                continue;
            if (PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY || PositionGetDouble(POSITION_SL) == stop)
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
            if (!PositionSelectByTicket(ticket))
                continue;
            if (PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL || PositionGetDouble(POSITION_SL) == stop)
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
        if (!PositionSelectByTicket(ticket))
            continue;
        if (PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
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
        if (PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
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

    return lots;
}

double CalculateWinMoney()
{
    double moneyLotStep = distance / tickSize * tickValue * lotStep;
    if (RiskValue == RISK_VALUE_LOT)
        return (RiskValueAmount / lotStep) * moneyLotStep;
    else
        return (Volume() / lotStep) * moneyLotStep; // capital * RiskValueAmount * 0.01;
}

void CheckProfitLong()
{
    double profit = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket))
            continue;
        if (PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
            continue;
        profit += PositionGetDouble(POSITION_PROFIT);
    }
    profitLong = profit;
}

void CheckStartAndLastPriceLong()
{
    double startPrice = profitLong > 0 ? INT_MAX : 0;
    double lastPrice = profitLong > 0 ? 0 : INT_MAX;

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket))
            continue;
        if (PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
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
    Print("startPrice: ", startPrice, " | lastPrice: ", lastPrice, " | profitLong: ", profitLong);
}

void CheckProfitShort()
{
    double profit = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket))
            continue;
        if (PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
            continue;
        profit += PositionGetDouble(POSITION_PROFIT);
    }
    profitShort = profit;
}

void CheckStartAndLastPriceShort()
{
    double startPrice = profitShort > 0 ? 0 : INT_MAX;
    double lastPrice = profitShort > 0 ? INT_MAX : 0;

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket))
            continue;
        if (PositionGetString(POSITION_SYMBOL) != pair || PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
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
    Print("startPrice: ", startPrice, " | lastPrice: ", lastPrice, " | profitShort: ", profitShort);
}