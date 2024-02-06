//+------------------------------------------------------------------+
//|                                                RangeBreakout.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>

// Input parameters

input group "========= General settings =========";
input long InpMagicNumber = 777;     // Magic number
input double InpLots = 1.0;          // Risk size
input int InpTakeProfit = 0;         // Take Profit in % of the range (0 = disabled)
input int InpStopLoss = 100;         // Stop Loss in % of the range (0 = disabled)
input int InpPercentBreakEven = 100; // sl% to break even (0 = disabled)
input bool InpTakeLongs = true;      // long trades
input bool InpTakeShorts = true;     // short trades

input group "========= Range settings =========";
enum BREAKOUT_PAIR_ENUM
{
    OFF,
    US,
    EU
};

input BREAKOUT_PAIR_ENUM InpBreakoutPair = US; // time preset

int InpRangeStart = 0;    // Range start time in minutes
int InpRangeDuration = 0; // Range duration in minutes
int InpRangeClose = 0;    // Range close time in minutes (-1 = disabled)

enum BREAKOUT_MODE_ENUM
{
    ONE_SIGNAL, // One breakout per range
    TWO_SIGNALS // high and low breakout
};
input BREAKOUT_MODE_ENUM InpBreakoutMode = TWO_SIGNALS; // Breakout mode

// input group "========= Day settings =========";
bool InpMonday = true;    // Range on Monday
bool InpTuesday = true;   // Range on Tuesday
bool InpWednesday = true; // Range on Wednesday
bool InpThursday = true;  // Range on Thursday
bool InpFriday = true;    // Range on Friday

struct RANGE_STRUCT
{
    datetime start_time;  // start of the range
    datetime end_time;    // end of the range
    datetime close_time;  // close of the range
    double high;          // high of the range
    double low;           // low of the range
    bool f_entry;         // flag if we are in the range
    bool f_high_breakout; // flag if a high breakout occured
    bool f_low_breakout;  // flag if a low breakout occured

    RANGE_STRUCT() : start_time(0), end_time(0), close_time(0), high(0), low(DBL_MAX), f_entry(false), f_high_breakout(false), f_low_breakout(false){};
};

RANGE_STRUCT range;
MqlTick prevTick, lastTick;
CTrade trade;

double slDistance;

int OnInit()
{
    if (InpBreakoutPair == EU)
    {
        InpRangeStart = 60 * 1;
        InpRangeDuration = 60 * 6;
        InpRangeClose = 60 * 13;
    }
    else if (InpBreakoutPair == US)
    {
        InpRangeStart = 60 * 6;
        InpRangeDuration = 60 * 6;
        InpRangeClose = 60 * 18;
    }

    trade.SetExpertMagicNumber(InpMagicNumber);

    // check user inputs
    if (!CheckInputs())
        return INIT_PARAMETERS_INCORRECT;

    // set magic number
    trade.SetExpertMagicNumber(InpMagicNumber);

    // calculated new range if inputs are changed
    if (_UninitReason == REASON_PARAMETERS && CountOpenPositions() == 0)
        CalculateRange();

    // draw objects
    DrawObjects();

    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    // delete objects
    ObjectsDeleteAll(NULL, "range");
}

void OnTick()
{

    // get current tick
    prevTick = lastTick;
    SymbolInfoTick(Symbol(), lastTick);

    // range calculation
    if (lastTick.time >= range.start_time && lastTick.time < range.end_time)
    {
        // set flag
        range.f_entry = true;

        // new high
        if (lastTick.ask > range.high)
        {
            range.high = lastTick.ask;
            DrawObjects();
        }

        // new low
        if (lastTick.bid < range.low)
        {
            range.low = lastTick.bid;
            DrawObjects();
        }
    }

    // close position
    if (InpRangeClose >= 0 && lastTick.time >= range.close_time)
    {
        if (!ClosePositions())
            return;
    }

    // calculate new range if ...
    if (((InpRangeClose >= 0 && lastTick.time >= range.close_time)                     // close time reached
         || (range.f_high_breakout && range.f_low_breakout)                            // both breakout flags are true
         || (range.end_time == 0)                                                      // range not calculated
         || (range.end_time != 0 && lastTick.time > range.end_time && !range.f_entry)) // there was a range calculated but no tick inside
        && CountOpenPositions() == 0)                                                  // no open positions
    {
        CalculateRange();
    }

    // check for breakouts
    CheckBreakouts();

    // breakeven
    BreakEven();
}

// check user inputs
bool CheckInputs()
{
    if (InpMagicNumber <= 0)
    {
        Alert("Magic number must be greater than zero");
        return false;
    }
    if (InpLots <= 0 || InpLots > 100)
    {
        Alert("Lot size must be greater than zero and less than 100");
        return false;
    }
    if (InpStopLoss < 0 || InpStopLoss > 1000)
    {
        Alert("Stop Loss must be greater than zero and less than 1000");
        return false;
    }
    if (InpTakeProfit < 0 || InpTakeProfit > 1000)
    {
        Alert("Take Profit must be greater than zero and less than 1000");
        return false;
    }
    if (InpRangeClose < 0 && InpStopLoss == 0)
    {
        Alert("Close time and stop loss is off");
        return false;
    }
    if (InpRangeStart < 0 || InpRangeStart > 1440)
    {
        Alert("Range start time must be greater than zero and less than 1440");
        return false;
    }
    if (InpRangeDuration < 0 || InpRangeDuration > 1440)
    {
        Alert("Range duration must be greater than zero and less than 1440");
        return false;
    }
    if (InpRangeClose >= 1440 || (InpRangeStart + InpRangeDuration) % 1440 == InpRangeClose)
    {
        Alert("Range close time must be greater than zero and less than 1440 and not equal to range start time + range duration");
        return false;
    }
    if (InpMonday + InpTuesday + InpWednesday + InpThursday + InpFriday == 0)
    {
        Alert("At least one day must be selected");
        return false;
    }

    return true;
}

// calculate a new range
void CalculateRange()
{

    // reset range variables
    range.start_time = 0;
    range.end_time = 0;
    range.close_time = 0;
    range.high = 0.0;
    range.low = DBL_MAX;
    range.f_entry = false;
    range.f_high_breakout = false;
    range.f_low_breakout = false;

    // calculate range start time
    int time_cycle = 86400;
    range.start_time = (lastTick.time - (lastTick.time % time_cycle)) + InpRangeStart * 60;
    for (int i = 0; i < 8; i++)
    {
        MqlDateTime tmp;
        TimeToStruct(range.start_time, tmp);
        int dow = tmp.day_of_week;
        if (lastTick.time >= range.start_time || dow == 6 || dow == 0 || (dow == 1 && !InpMonday) || (dow == 2 && !InpTuesday) || (dow == 3 && !InpWednesday) || (dow == 4 && !InpThursday) || (dow == 5 && !InpFriday))
        {
            range.start_time += time_cycle;
        }
    }

    // calculate range end time
    range.end_time = range.start_time + InpRangeDuration * 60;
    for (int i = 0; i < 2; i++)
    {
        MqlDateTime tmp;
        TimeToStruct(range.end_time, tmp);
        int dow = tmp.day_of_week;
        if (dow == 6 || dow == 0)
        {
            range.end_time += time_cycle;
        }
    }

    // calculate range close
    if (InpRangeClose >= 0)
    {
        range.close_time = (range.end_time - (range.end_time % time_cycle)) + InpRangeClose * 60;
        for (int i = 0; i < 3; i++)
        {
            MqlDateTime tmp;
            TimeToStruct(range.close_time, tmp);
            int dow = tmp.day_of_week;
            if (range.close_time <= range.end_time || dow == 6 || dow == 0)
            {
                range.close_time += time_cycle;
            }
        }
    }

    // draw objects
    DrawObjects();
}

// count all open positions
int CountOpenPositions()
{
    int counter = 0;
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0)
        {
            Print("Failed to get position ticket");
            return -1;
        }
        if (!PositionSelectByTicket(ticket))
        {
            Print("Failed to select position by ticket");
            return -1;
        }
        ulong magicNumber;
        if (!PositionGetInteger(POSITION_MAGIC, magicNumber))
        {
            Print("Failed to get position magic number");
            return -1;
        }
        if (InpMagicNumber == magicNumber)
            counter++;
    }

    return counter;
}

// check for breakouts
void CheckBreakouts()
{

    // check if we are after the range end
    if (lastTick.time >= range.end_time && range.end_time > 0 && range.f_entry)
    {
        // check for high breakout
        if (!range.f_high_breakout && lastTick.ask >= range.high && InpTakeLongs)
        {
            range.f_high_breakout = true;
            if (InpBreakoutMode == ONE_SIGNAL)
                range.f_low_breakout = true;

            // calculate stop loss and take profit
            double sl = InpStopLoss == 0 ? 0 : NormalizeDouble(lastTick.bid - ((range.high - range.low) * InpStopLoss * 0.01), Digits());
            double tp = InpTakeProfit == 0 ? 0 : NormalizeDouble(lastTick.bid + ((range.high - range.low) * InpTakeProfit * 0.01), Digits());

            slDistance = NormalizeDouble(MathAbs(lastTick.ask - sl), Digits());

            // open buy position
            trade.PositionOpen(Symbol(), ORDER_TYPE_BUY, sl == 0 ? InpLots : Volume(), lastTick.ask, sl, tp, "Time range ea");
        }

        // check for low breakout
        if (!range.f_low_breakout && lastTick.bid <= range.low && InpTakeShorts)
        {
            range.f_low_breakout = true;
            if (InpBreakoutMode == ONE_SIGNAL)
                range.f_high_breakout = true;

            // calculate stop loss and take profit
            double sl = InpStopLoss == 0 ? 0 : NormalizeDouble(lastTick.ask + ((range.high - range.low) * InpStopLoss * 0.01), Digits());
            double tp = InpTakeProfit == 0 ? 0 : NormalizeDouble(lastTick.ask - ((range.high - range.low) * InpTakeProfit * 0.01), Digits());

            slDistance = NormalizeDouble(MathAbs(sl - lastTick.bid), Digits());

            // open sell position
            trade.PositionOpen(Symbol(), ORDER_TYPE_SELL, sl == 0 ? InpLots : Volume(), lastTick.bid, sl, tp, "Time range ea");
        }
    }
}

// close all open positions
bool ClosePositions()
{

    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--)
    {
        if (total != PositionsTotal())
        {
            total = PositionsTotal();
            i = total;
            continue;
        }
        ulong ticket = PositionGetTicket(i); // select position
        if (ticket <= 0)
        {
            Print("Failed to get position ticket");
            return false;
        }
        if (!PositionSelectByTicket(ticket))
        {
            Print("Failed to select position by ticket");
            return false;
        }
        long magicNumber;
        if (!PositionGetInteger(POSITION_MAGIC, magicNumber))
        {
            Print("Failed to get position magic number");
            return false;
        }
        if (InpMagicNumber == magicNumber)
        {
            trade.PositionClose(ticket);
            if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
            {
                Print("Failed to close position. Result: " + (string)trade.ResultRetcode() + " - " + trade.ResultRetcodeDescription());
                return false;
            }
        }
    }

    return true;
}

// draw chart objects
void DrawObjects()
{

    // start time
    ObjectDelete(NULL, "range start");
    if (range.start_time > 0)
    {
        ObjectCreate(NULL, "range start", OBJ_VLINE, 0, range.start_time, 0);
        ObjectSetString(NULL, "range start", OBJPROP_TOOLTIP, "start of the range \n" + TimeToString(range.start_time, TIME_DATE | TIME_MINUTES));
        ObjectSetInteger(NULL, "range start", OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(NULL, "range start", OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, "range start", OBJPROP_BACK, true);
    }

    // end time
    ObjectDelete(NULL, "range end");
    if (range.end_time > 0)
    {
        ObjectCreate(NULL, "range end", OBJ_VLINE, 0, range.end_time, 0);
        ObjectSetString(NULL, "range end", OBJPROP_TOOLTIP, "end of the range \n" + TimeToString(range.end_time, TIME_DATE | TIME_MINUTES));
        ObjectSetInteger(NULL, "range end", OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(NULL, "range end", OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, "range end", OBJPROP_BACK, true);
    }

    // close time
    ObjectDelete(NULL, "range close");
    if (range.close_time > 0)
    {
        ObjectCreate(NULL, "range close", OBJ_VLINE, 0, range.close_time, 0);
        ObjectSetString(NULL, "range close", OBJPROP_TOOLTIP, "close of the range \n" + TimeToString(range.close_time, TIME_DATE | TIME_MINUTES));
        ObjectSetInteger(NULL, "range close", OBJPROP_COLOR, clrRed);
        ObjectSetInteger(NULL, "range close", OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, "range close", OBJPROP_BACK, true);
    }

    // high
    ObjectsDeleteAll(NULL, "range high");
    if (range.high > 0)
    {
        ObjectCreate(NULL, "range high", OBJ_TREND, 0, range.start_time, range.high, range.end_time, range.high);
        ObjectSetString(NULL, "range high", OBJPROP_TOOLTIP, "high of the range \n" + DoubleToString(range.high, Digits()));
        ObjectSetInteger(NULL, "range high", OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(NULL, "range high", OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, "range high", OBJPROP_BACK, true);

        ObjectCreate(NULL, "range high ", OBJ_TREND, 0, range.end_time, range.high, InpRangeClose >= 0 ? range.close_time : INT_MAX, range.high);
        ObjectSetString(NULL, "range hig h", OBJPROP_TOOLTIP, "high of the range \n" + DoubleToString(range.high, Digits()));
        ObjectSetInteger(NULL, "range high ", OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(NULL, "range high ", OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(NULL, "range high ", OBJPROP_BACK, true);
    }

    // low
    ObjectsDeleteAll(NULL, "range low");
    if (range.low < DBL_MAX)
    {
        ObjectCreate(NULL, "range low", OBJ_TREND, 0, range.start_time, range.low, range.end_time, range.low);
        ObjectSetString(NULL, "range low", OBJPROP_TOOLTIP, "low of the range \n" + DoubleToString(range.low, Digits()));
        ObjectSetInteger(NULL, "range low", OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(NULL, "range low", OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, "range low", OBJPROP_BACK, true);

        ObjectCreate(NULL, "range low ", OBJ_TREND, 0, range.end_time, range.low, InpRangeClose >= 0 ? range.close_time : INT_MAX, range.low);
        ObjectSetString(NULL, "range low ", OBJPROP_TOOLTIP, "low of the range \n" + DoubleToString(range.low, Digits()));
        ObjectSetInteger(NULL, "range low ", OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(NULL, "range low ", OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(NULL, "range low ", OBJPROP_BACK, true);
    }

    // refresh chart
    ChartRedraw();
}

double Volume()
{
    double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

    double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpLots / 100;
    double moneyLotStep = (slDistance / tickSize) * tickValue * lotStep;

    double lots = MathRound(riskMoney / moneyLotStep) * lotStep;

    double minVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);

    if (lots < minVol)
    {
        Print(lots, " > Adjusted to minimum volume > ", minVol);
        lots = minVol;
    }
    else if (lots > maxVol)
    {
        Print(lots, " > Adjusted to minimum volume > ", maxVol);
        lots = maxVol;
    }

    return lots;
}

void BreakEven()
{
    if (InpPercentBreakEven == 0 && InpStopLoss == 0)
        return;

    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket))
        {
            Print("Failed to select position by ticket");
            continue;
            ;
        }
        long magic;
        if (!PositionGetInteger(POSITION_MAGIC, magic))
        {
            Print("Failed to get position magic");
            continue;
        }
        if (magic != InpMagicNumber)
            continue;
        long type;
        double entry;
        double stopLoss;
        double takeProfit;
        if (!PositionGetInteger(POSITION_TYPE, type))
        {
            Print("Failed to get position type");
            continue;
        }
        if (!PositionGetDouble(POSITION_PRICE_OPEN, entry))
        {
            Print("Failed to get position entry price");
            continue;
        }
        if (!PositionGetDouble(POSITION_SL, stopLoss))
        {
            Print("Failed to get position take profit");
            continue;
        }
        if (!PositionGetDouble(POSITION_TP, takeProfit))
        {
            Print("Failed to get position take profit");
            continue;
        }
        if (entry == stopLoss)
            continue;

        // calculate a new stop loss distance based on the InpPercentBreakEven percentage
        double beDistance = NormalizeDouble(slDistance * InpPercentBreakEven / 100, Digits());

        if (((long)type == (long)ORDER_TYPE_BUY && lastTick.bid > entry + beDistance) || ((long)type == (long)ORDER_TYPE_SELL && lastTick.ask < entry - beDistance))
        {
            trade.PositionModify(ticket, entry, takeProfit);
        }
    }
    return;
}
