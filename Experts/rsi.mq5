//+------------------------------------------------------------------+
//|                                                          rsi.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

static input long     InpMagic          = 123456;       // Magic number
static input double   InpLotSize        = 0.1;          // Lot size
input int             InpRSIPeriod      = 14;           // RSI period
input int             InpRSILevel       = 70;           // RSI level (upper)
input int             InpMAPeriod       = 0;           // MA period
input ENUM_TIMEFRAMES InpMATimeframe    = PERIOD_H1;    // MA timeframe
input int             InpStopLoss       = 0;          // Stop loss (0 = off)
input int             InpTakeProfit     = 0;          // Take profit (0 = off)
input bool            InpCloseSignal    = true;         // close trades by opposite signal
// input int             InpATRPeriod      = 14;           // ATR period
// input bool            InpATRSL           = true;         // close trades by opposite signal
// input int             InpATRSLMultiplier  = 2;           // ATR multiplier
// input bool            InpATRTP           = true;         // close trades by opposite signal
// input int             InpATRTPMultiplier  = 2;           // ATR multiplier

f
int handleRSI;
int handleMA;
double bufferRSI[];
double bufferMA[];
MqlTick currentTick;
datetime openTimeBuy, openTimeSell;

int OnInit()
{
    trade.SetExpertMagicNumber(InpMagic);

    // create rsi handleRSI
    handleRSI = iRSI(Symbol(), PERIOD_CURRENT, InpRSIPeriod, PRICE_OPEN);
    if(handleRSI == INVALID_HANDLE)
    {
        Print("Failed to create RSI handleRSI");
        return INIT_FAILED;
    }
    ArraySetAsSeries(bufferRSI, true);
    
    if( InpMAPeriod < 1){return INIT_SUCCEEDED;}
    
    handleMA = iMA(Symbol(), InpMATimeframe, InpMAPeriod, 0, MODE_SMA, PRICE_OPEN);
    if(handleMA == INVALID_HANDLE)
    {
        Print("Failed to create MA handleRSI");
        return INIT_FAILED;
    }

    //set buffer as series
    ArraySetAsSeries(bufferMA, true);

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    if (handleRSI != INVALID_HANDLE) {IndicatorRelease(handleRSI);}
    
    if( InpMAPeriod < 1){return;}
    if (handleMA != INVALID_HANDLE) {IndicatorRelease(handleMA);}
}

void OnTick()
{
    if(!IsNewBar()) {return;}

    // get current tick
    if(!SymbolInfoTick(Symbol(), currentTick)){Print("Failed to get current tick"); return;}

    // get rsi value
    int values = CopyBuffer(handleRSI, 0, 0, 2, bufferRSI);
    if(values != 2){Print("Failed to get RSI value"); return;}

    // get ma value
    if( InpMAPeriod > 0)
      {
         values = CopyBuffer(handleMA, 0, 0, 1, bufferMA);
         if(values != 1){Print("Failed to get MA value"); return;}
      }
    

    Comment("bufferRsi[0]: ", bufferRSI[0], "\nbufferRsi[1]: ", bufferRSI[1], "\nbufferMa[0]: ",  InpMAPeriod > 0 ? bufferMA[0] : "");

    // count open positions
    int cntBuy, cntSell;
    if(!CountOpenPositions(cntBuy, cntSell)){ return; }

    // check for buy position
    if(cntBuy == 0 && bufferRSI[1] >= (100-InpRSILevel) && bufferRSI[0] < (100-InpRSILevel) && (InpMAPeriod > 0 ? currentTick.ask > bufferMA[0] : true))
    {
        if(InpCloseSignal){if(!ClosePositions(2)){return;}}
        double sl = InpStopLoss == 0 ? 0 : currentTick.ask - InpStopLoss * Point();
        double tp = InpTakeProfit == 0 ? 0 : currentTick.ask + InpTakeProfit * Point();
        if(!NormalizePrice(sl) || !NormalizePrice(tp)){Print("Failed to normalize price"); return;}

        trade.PositionOpen(Symbol(), ORDER_TYPE_BUY, InpLotSize, currentTick.ask, sl, tp, "RSI MA filter EA");
    }

    // check for sell position
    if(cntSell == 0 && bufferRSI[1] <= InpRSILevel && bufferRSI[0] > InpRSILevel && (InpMAPeriod > 0 ? currentTick.bid < bufferMA[0] : true))
    {
        if(InpCloseSignal){if(!ClosePositions(1)){return;}}
        double sl = InpStopLoss == 0 ? 0 : currentTick.bid + InpStopLoss * Point();
        double tp = InpTakeProfit == 0 ? 0 : currentTick.bid - InpTakeProfit * Point();
        if(!NormalizePrice(sl) || !NormalizePrice(tp)){Print("Failed to normalize price"); return;}

        trade.PositionOpen(Symbol(), ORDER_TYPE_SELL, InpLotSize, currentTick.bid, sl, tp, "RSI MA filter EA");
    }
}

// check if we have a nar open tick
bool IsNewBar()
{
    static datetime previousTime = 0;
    datetime currentTime = iTime(Symbol(), PERIOD_CURRENT, 0);
    if(currentTime != previousTime)
    {
        previousTime = currentTime;
        return true;
    }
    return false;
}

bool CountOpenPositions(int &cntBuy, int &cntSell)
{
    cntBuy = 0;
    cntSell = 0;
    int total = PositionsTotal();
    for (int i = total-1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)){Print("Failed to select position by ticket"); return false;}
        long magic;
        if(!PositionGetInteger(POSITION_MAGIC, magic)){Print("Failed to get position magic"); return false;}
        if(magic == InpMagic)
        {
            long type;
            if(!PositionGetInteger(POSITION_TYPE, type)){Print("Failed to get position type"); return false;}
            if(type == ORDER_TYPE_BUY){cntBuy++;}
            if(type == ORDER_TYPE_SELL){cntSell++;}
        }
    }
    return true;
}

// normalize price
bool NormalizePrice(double &price)
{
    double tickSize = 0;
    if(!SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE, tickSize)){Print("Failed to get tick size"); return false;}
    price = NormalizeDouble(MathRound(price / tickSize) * tickSize, Digits());

    return true;
}

// close positions
bool ClosePositions(int all_buy_sell)
{
    int total = PositionsTotal();
    for (int i = total-1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <=0){Print("Failed to get ticket"); return false;}
        if(!PositionSelectByTicket(ticket)){Print("Failed to select position by ticket"); return false;}
        long magic;
        if(!PositionGetInteger(POSITION_MAGIC, magic)){Print("Failed to get position magic"); return false;}
        if(magic == InpMagic)
        {
            long type;
            if(!PositionGetInteger(POSITION_TYPE, type)){Print("Failed to get position type"); return false;}
            if((all_buy_sell == 1 && type == POSITION_TYPE_SELL) || (all_buy_sell == 2 && type == POSITION_TYPE_BUY)) {continue;}
            trade.PositionClose(ticket);
            if(trade.ResultRetcode() != TRADE_RETCODE_DONE){
                Print("Failed to close position. ticket: ", (string) ticket, "result: ", (string) trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
            }
        }
    }

    return true;
}

// double Volume()
// {
//     double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
//     double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
//     double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

//     double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * riskPercent / 100;
//     double moneyLotStep = (MathAbs(gridSize) / tickSize) * tickValue * lotStep;

//     double lots = MathFloor(riskMoney / moneyLotStep) * lotStep;

//     double minVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
//     double maxVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);

//     if (lots < minVol)
//     {
//         lots = minVol;
//         Print(lots, " Adjusted to minimum volume ", minVol);
//     }
//     else if (lots > maxVol)
//     {
//         lots = maxVol;
//         Print(lots, " Adjusted to maximum volume ", minVol);
//     }

//     return lots;
// }

// double AtrValue()
// {
//     double priceArray[];
//     int atrDef = iATR(Symbol(), PERIOD_CURRENT, AtrPeriod);
//     ArraySetAsSeries(priceArray, true);
//     CopyBuffer(atrDef, 0, 0, 1, priceArray);
//     double atrValue = NormalizeDouble(priceArray[0], Digits());
//     return atrValue;
// }