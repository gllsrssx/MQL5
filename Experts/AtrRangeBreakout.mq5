// EXAMPLE: the atr is not increasing for 5 bars, the range high will be the high of the last 5 bars, the range low will be the low of the last 5 bars. if the previous bar atr is increasing, look for a breakout of the range. if no breakout, make a new range.

#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade/Trade.mqh>
#include <Arrays/ArrayLong.mqh>
#include <Arrays/ArrayObj.mqh>

class CSymbol : public CObject
{
public:
    CSymbol(string name) : symbol(name) {};
    ~CSymbol() {};

    string symbol;
    int handleAtr;
    double rangeHigh;
    double rangeLow;
    int rangeBars;
    bool tradeTaken;
};

CArrayObj symbols;

enum ENUM_SYMBOLS
{
    SYMBOLS_ALL,
    SYMBOLS_MAJOR,
    SYMBOLS_EURUSD,
    SYMBOLS_AUDUSD,
    SYMBOLS_GBPUSD,
    SYMBOLS_USDCAD,
    SYMBOLS_USDCHF,
    SYMBOLS_USDJPY,
    SYMBOLS_MINOR,
};
input ENUM_SYMBOLS InpSymbols = SYMBOLS_ALL; // symbols
enum ENUM_RISK_VALUE
{
    RISK_VALUE_LOT,
    RISK_VALUE_PERCENT
};
input ENUM_RISK_VALUE InpRiskValue = RISK_VALUE_PERCENT; // risk value
enum ENUM_RISK_TYPE
{
    RISK_TYPE_BALANCE,
    RISK_TYPE_EQUITY,
    RISK_TYPE_STATIC
};
input ENUM_RISK_TYPE InpRiskType = RISK_TYPE_BALANCE;
input double InpRiskValueAmount = 1.0;                  // risk value amount
input double InpRiskRewardRatio = 0;                    // risk reward ratio (0=off)
input bool InpTrailStop = true;                         // trail stop
input int InpAtrPeriods = 14;                           // ATR period to determine range
input ENUM_TIMEFRAMES InpAtrTimeframe = PERIOD_CURRENT; // ATR timeframe
input int InpMagic = 8;                                 // magic number
input int InpStartTradingHour = 0;                      // start trading hour server time (0=off)
input int InpStopTradingHour = 0;                       // stop trading hour server time (0=off)
input int InpMaxSpread = 0;                             // max spread allowed (0=off)
input bool debug = false;                               // debug mode

int OnInit()
{
    string arrSymbols[];
    if (InpSymbols == SYMBOLS_MAJOR)
    {
        ArrayResize(arrSymbols, 6);
        arrSymbols[0] = "EURUSD";
        arrSymbols[1] = "USDJPY";
        arrSymbols[2] = "GBPUSD";
        arrSymbols[3] = "AUDUSD";
        arrSymbols[4] = "USDCAD";
        arrSymbols[5] = "USDCHF";
    }
    else if (InpSymbols == SYMBOLS_MINOR)
    {
        ArrayResize(arrSymbols, 20);
        arrSymbols[0] = "AUDCHF";
        arrSymbols[1] = "AUDJPY";
        arrSymbols[2] = "AUDNZD";
        arrSymbols[3] = "CADCHF";
        arrSymbols[4] = "CADJPY";
        arrSymbols[5] = "CHFJPY";
        arrSymbols[6] = "EURAUD";
        arrSymbols[7] = "EURCAD";
        arrSymbols[8] = "EURCHF";
        arrSymbols[9] = "EURGBP";
        arrSymbols[10] = "AUDCAD";
        arrSymbols[11] = "EURJPY";
        arrSymbols[12] = "USDSGD";
        arrSymbols[13] = "EURNZD";
        arrSymbols[14] = "GBPAUD";
        arrSymbols[15] = "GBPCAD";
        arrSymbols[16] = "GBPCHF";
        arrSymbols[17] = "GBPJPY";
        arrSymbols[18] = "GBPNZD";
        arrSymbols[19] = "NZDCAD";
    }
    else if (InpSymbols == SYMBOLS_ALL)
    {
        ArrayResize(arrSymbols, 26);
        arrSymbols[0] = "EURUSD";
        arrSymbols[1] = "USDJPY";
        arrSymbols[2] = "GBPUSD";
        arrSymbols[3] = "AUDUSD";
        arrSymbols[4] = "USDCAD";
        arrSymbols[5] = "USDCHF";
        arrSymbols[6] = "AUDCHF";
        arrSymbols[7] = "AUDJPY";
        arrSymbols[8] = "AUDNZD";
        arrSymbols[9] = "CADCHF";
        arrSymbols[10] = "CADJPY";
        arrSymbols[11] = "CHFJPY";
        arrSymbols[12] = "EURAUD";
        arrSymbols[13] = "EURCAD";
        arrSymbols[14] = "EURCHF";
        arrSymbols[15] = "EURGBP";
        arrSymbols[16] = "AUDCAD";
        arrSymbols[17] = "EURJPY";
        arrSymbols[18] = "USDSGD";
        arrSymbols[19] = "EURNZD";
        arrSymbols[20] = "GBPAUD";
        arrSymbols[21] = "GBPCAD";
        arrSymbols[22] = "GBPCHF";
        arrSymbols[23] = "GBPJPY";
        arrSymbols[24] = "GBPNZD";
        arrSymbols[25] = "NZDCAD";
    }
    else if (InpSymbols == SYMBOLS_EURUSD)
    {
        ArrayResize(arrSymbols, 1);
        arrSymbols[0] = "EURUSD";
    }
    else if (InpSymbols == SYMBOLS_USDJPY)
    {
        ArrayResize(arrSymbols, 1);
        arrSymbols[0] = "USDJPY";
    }
    else if (InpSymbols == SYMBOLS_GBPUSD)
    {
        ArrayResize(arrSymbols, 1);
        arrSymbols[0] = "GBPUSD";
    }
    else if (InpSymbols == SYMBOLS_AUDUSD)
    {
        ArrayResize(arrSymbols, 1);
        arrSymbols[0] = "AUDUSD";
    }
    else if (InpSymbols == SYMBOLS_USDCAD)
    {
        ArrayResize(arrSymbols, 1);
        arrSymbols[0] = "USDCAD";
    }
    else if (InpSymbols == SYMBOLS_USDCHF)
    {
        ArrayResize(arrSymbols, 1);
        arrSymbols[0] = "USDCHF";
    }

    symbols.Clear();
    for (int i = ArraySize(arrSymbols) - 1; i >= 0; i--)
    {
        CSymbol *symbol = new CSymbol(arrSymbols[i]);
        symbol.handleAtr = iATR(symbol.symbol, InpAtrTimeframe, InpAtrPeriods);
        symbol.rangeBars = 1;
        symbol.tradeTaken = false;
        symbols.Add(symbol);
        if (debug)
            Print("Symbol: ", symbol.symbol, " initialized.");
    }

    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
    MqlDateTime dt;
    TimeCurrent(dt);

    for (int j = symbols.Total() - 1; j >= 0; j--)
    {
        CSymbol *symbol = symbols.At(j);

        CTrade trade;
        trade.SetExpertMagicNumber(InpMagic);

        string sym = symbol.symbol;
        double atr[];
        ArraySetAsSeries(atr, true);
        CopyBuffer(symbol.handleAtr, MAIN_LINE, 0, symbol.rangeBars + 3, atr);

        // if (debug)
        // {
        //     int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
        //     for (int i = 0; i < symbol.rangeBars + 3; i++)
        //     {
        //         Print("ATR[", i, "]: ", NormalizeDouble(atr[i], digits));
        //     }
        // }

        // Check if ATR is increasing
        bool atrIncreasing = atr[1] > atr[2];
        if (debug)
            Print("Symbol: ", sym, " ATR increasing: ", atrIncreasing, " ATR[1]: ", atr[1], " ATR[2]: ", atr[2]);

        if (atrIncreasing)
            symbol.rangeBars = 1;
        else if (isNewBar(sym, InpAtrTimeframe))
        {
            symbol.tradeTaken = false;
            symbol.rangeBars++;
            symbol.rangeHigh = iHigh(sym, InpAtrTimeframe, iHighest(sym, InpAtrTimeframe, MODE_HIGH, symbol.rangeBars, 0));
            symbol.rangeLow = iLow(sym, InpAtrTimeframe, iLowest(sym, InpAtrTimeframe, MODE_LOW, symbol.rangeBars, 0));
            if (debug)
                Print("Symbol: ", sym, " range high: ", symbol.rangeHigh, " range low: ", symbol.rangeLow, " range bars: ", symbol.rangeBars);

            // Draw the range on the chart
            DrawRange(sym, symbol.rangeHigh, symbol.rangeLow, symbol.rangeBars);
        }

        int tradeCount = 0;
        for (int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if (PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == sym && PositionGetInteger(POSITION_MAGIC) == InpMagic)
            {
                tradeCount++;
                if (!atrIncreasing && InpRiskRewardRatio == 0)
                {
                    trade.PositionClose(ticket);
                    symbol.tradeTaken = false;
                    if (debug)
                        Print("Closed position for symbol: ", sym, " ticket: ", ticket);
                }
                if (InpTrailStop)
                {
                    double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
                    double bid = SymbolInfoDouble(sym, SYMBOL_BID);
                    double positionStopLoss = PositionGetDouble(POSITION_SL);
                    double distance = symbol.rangeHigh - symbol.rangeLow;
                    double buyStopLoss = ask - distance;
                    double sellStopLoss = bid + distance;
                    if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && positionStopLoss < buyStopLoss)
                    {
                        trade.PositionModify(ticket, buyStopLoss, 0);
                        if (debug)
                            Print("Modified buy position for symbol: ", sym, " ticket: ", ticket, " stop loss: ", buyStopLoss);
                    }
                    else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && positionStopLoss > sellStopLoss)
                    {
                        trade.PositionModify(ticket, sellStopLoss, 0);
                        if (debug)
                            Print("Modified sell position for symbol: ", sym, " ticket: ", ticket, " stop loss: ", sellStopLoss);
                    }
                }
            }
        }

        if (debug)
            Print("Symbol: ", sym, " trade count: ", tradeCount);
        long spread = SymbolInfoInteger(sym, SYMBOL_SPREAD);
        if (tradeCount == 0 && atrIncreasing && !symbol.tradeTaken && symbol.rangeHigh - symbol.rangeLow > atr[1] && (InpMaxSpread == 0 || spread < InpMaxSpread) && (InpStartTradingHour == 0 || dt.hour >= InpStartTradingHour) && (InpStopTradingHour == 0 || dt.hour <= InpStopTradingHour))
        {
            double lot = Volume(sym, symbol.rangeHigh - symbol.rangeLow);
            double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
            double bid = SymbolInfoDouble(sym, SYMBOL_BID);
            if (ask > symbol.rangeHigh)
            {
                trade.Buy(lot, sym, 0, symbol.rangeLow, InpRiskRewardRatio > 0 ? ask + (ask - symbol.rangeHigh) * InpRiskRewardRatio : 0, "Breakout");
                symbol.tradeTaken = true;
                if (debug)
                    Print("Buy signal for symbol: ", sym, " lot: ", lot, " ask: ", ask, " range high: ", symbol.rangeHigh);
            }
            else if (bid < symbol.rangeLow)
            {
                trade.Sell(lot, sym, 0, symbol.rangeHigh, InpRiskRewardRatio > 0 ? bid - (symbol.rangeHigh - bid) * InpRiskRewardRatio : 0, "Breakout");
                symbol.tradeTaken = true;
                if (debug)
                    Print("Sell signal for symbol: ", sym, " lot: ", lot, " bid: ", bid, " range low: ", symbol.rangeLow);
            }
        }
    }
}

double capital = AccountInfoDouble(ACCOUNT_BALANCE);
double Volume(string sym, double distance)
{
    if (InpRiskValue == RISK_VALUE_LOT)
        return InpRiskValueAmount;

    if (InpRiskType == RISK_TYPE_BALANCE)
        capital = AccountInfoDouble(ACCOUNT_BALANCE);
    else if (InpRiskType == RISK_TYPE_EQUITY)
        capital = AccountInfoDouble(ACCOUNT_EQUITY);

    double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
    double lotStep = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);

    double riskMoney = capital * InpRiskValueAmount / 100;
    double moneyLotStep = distance / tickSize * tickValue * lotStep;

    double lots = MathFloor(riskMoney / moneyLotStep) * lotStep;

    double minVol = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
    double maxVol = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);

    if (lots < minVol)
        return minVol;

    else if (lots > maxVol)
        return maxVol;

    return lots;
}

void DrawRange(string symbol, double rangeHigh, double rangeLow, int rangeBars)
{
    if (symbol != Symbol())
        return;

    datetime timeStart = iTime(symbol, InpAtrTimeframe, rangeBars);
    datetime timeEnd = iTime(symbol, InpAtrTimeframe, 0);

    // start time
    string nameStart = "range start " + TimeToString(timeStart, TIME_DATE);
    ObjectDelete(NULL, nameStart);
    if (timeStart > 0)
    {
        ObjectCreate(NULL, nameStart, OBJ_TREND, 0, timeStart, rangeHigh, timeStart, rangeLow);
        ObjectSetString(NULL, nameStart, OBJPROP_TOOLTIP, nameStart);
        ObjectSetInteger(NULL, nameStart, OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(NULL, nameStart, OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, nameStart, OBJPROP_BACK, true);
    }

    // end time
    string nameEnd = "range end " + TimeToString(timeEnd, TIME_DATE);
    ObjectDelete(NULL, nameEnd);
    if (timeEnd > 0)
    {
        ObjectCreate(NULL, nameEnd, OBJ_TREND, 0, timeEnd, rangeHigh, timeEnd, rangeLow);
        ObjectSetString(NULL, nameEnd, OBJPROP_TOOLTIP, nameEnd);
        ObjectSetInteger(NULL, nameEnd, OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(NULL, nameEnd, OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, nameEnd, OBJPROP_BACK, true);
    }

    // high
    string nameHigh = "range high " + TimeToString(timeEnd, TIME_DATE);
    ObjectDelete(NULL, nameHigh);
    if (rangeHigh > 0)
    {
        ObjectCreate(NULL, nameHigh, OBJ_TREND, 0, timeStart, rangeHigh, timeEnd, rangeHigh);
        ObjectSetString(NULL, nameHigh, OBJPROP_TOOLTIP, nameHigh);
        ObjectSetInteger(NULL, nameHigh, OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(NULL, nameHigh, OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, nameHigh, OBJPROP_BACK, true);
    }

    // low
    string nameLow = "range low " + TimeToString(timeEnd, TIME_DATE);
    ObjectDelete(NULL, nameLow);
    if (rangeLow < DBL_MAX)
    {
        ObjectCreate(NULL, nameLow, OBJ_TREND, 0, timeStart, rangeLow, timeEnd, rangeLow);
        ObjectSetString(NULL, nameLow, OBJPROP_TOOLTIP, nameLow);
        ObjectSetInteger(NULL, nameLow, OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(NULL, nameLow, OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, nameLow, OBJPROP_BACK, true);
    }

    // refresh chart
    ChartRedraw();
}

bool isNewBar(string symbol, ENUM_TIMEFRAMES timeframe)
{
    static int barsTotal;
    int bars = iBars(symbol, timeframe);
    // if (debug)
    //     Print("Bars: ", bars, " BarsTotal: ", barsTotal);
    if (barsTotal == bars)
        return false;
    barsTotal = bars;
    return true;
}