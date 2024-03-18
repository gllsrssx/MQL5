//+------------------------------------------------------------------+
//|                                                RangeBreakout.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property description "Range breakout trading strategy"

#include <Trade\Trade.mqh>

// Input parameters
input group "========= Entry settings =========";
input double InpLots = 1.0;      // Risk %
input bool InpTakeLongs = true;  // Long trades
input bool InpTakeShorts = true; // Short trades
input int InpDeviation = 1;      // Deviation (0 = off)

input group "========= Exit settings =========";
input int InpTakeProfit = 0;        // TP % range (0 = off)
input int InpStopLoss = 102;        // SL % range (0 = off)
input int InpPercentBreakEven = 90; // BE % range (0 = off)

input group "========= Time settings =========";
input int InpTimezone = 3;           // Timezone
input bool InpDaylightSaving = true; // DST zone

input group "========= Range settings =========";
input int InpRangeStart = 0;  // Range start hour
input int InpRangeStop = 3;   // Range stop hour
input int InpRangeClose = 15; // Range close hour (0 = off)
int rangeStart, rangeDuration, rangeClose;

enum BREAKOUT_MODE_ENUM
{
    ONE_SIGNAL, // One breakout per range
    TWO_SIGNALS // high and low breakout
};
input BREAKOUT_MODE_ENUM InpBreakoutMode = TWO_SIGNALS; // Breakout mode

input group "========= Day settings =========";
input bool InpMonday = true;    // Range on Monday
input bool InpTuesday = true;   // Range on Tuesday
input bool InpWednesday = true; // Range on Wednesday
input bool InpThursday = true;  // Range on Thursday
input bool InpFriday = true;    // Range on Friday

input group "========= Color settings =========";
input color InpColorRange = clrGreen;  // range color
input color InpColorBreakout = clrRed; // breakout color

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

int DSToffset; // DST offset
long InpMagicNumber;

int OnInit()
{
    long accountNumbers[] = {11028867, 7216275, 7222732};
    long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
    if (ArrayBsearch(accountNumbers, accountNumber) == -1)
    {
        Print("The account " + (string)accountNumber + " is not authorized to use this EA.");
        ExpertRemove();
        return INIT_FAILED;
    }
    else
    {
        Print("The account " + (string)accountNumber + " is authorized to use this EA.");
    }
    if (TimeCurrent() < StringToTime("2025.01.01 00:00:00"))
    {
        Print("This is a demo version of the EA. It will only work until January 1, 2025.");
    }
    else
    {
        Print("This is a demo version of the EA. It will only work until January 1, 2025.");
        ExpertRemove();
        return INIT_FAILED;
    }

    // set magic number
    InpMagicNumber = rand();

    // Adjust DST and timezone offset
    DSTAdjust();

    // check user inputs
    if (!CheckInputs())
        return INIT_PARAMETERS_INCORRECT;

    // set magic number
    trade.SetExpertMagicNumber(InpMagicNumber);

    // calculated new range if inputs are changed
    if (_UninitReason == REASON_PARAMETERS && CountOpenPositions() == 0)
    {
        CalculateRange();
    }

    // draw objects
    DrawObjects();

    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    Comment("");

    ObjectsDeleteAll(0, "Range");

    ClosePositions();
}

void OnTick()
{
    // DST
    DSTAdjust();

    // get current tick
    prevTick = lastTick;
    SymbolInfoTick(Symbol(), lastTick);

    // DST
    DSTAdjust();

    // get current tick
    prevTick = lastTick;
    SymbolInfoTick(Symbol(), lastTick);

    // check if we are in the range
    RangeCheck();

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
    if (rangeClose < 0 && InpStopLoss == 0)
    {
        Alert("Close time and stop loss is off");
        return false;
    }
    if (rangeStart < 0 || rangeStart > 1440)
    {
        Alert("Range start time must be greater than zero and less than 1440");
        return false;
    }
    if (rangeDuration < 0 || rangeDuration > 1440)
    {
        Alert("Range duration must be greater than zero and less than 1440");
        return false;
    }
    if (!InpTakeLongs && !InpTakeShorts)
    {
        Alert("At least one trade direction must be selected");
        return false;
    }
    if (rangeClose >= 1440 || (rangeStart + rangeDuration) % 1440 == rangeClose)
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

void RangeCheck()
{
    // range calculation
    if (lastTick.time > range.start_time && lastTick.time < range.end_time)
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

    if (lastTick.time > range.end_time && lastTick.time < range.close_time)
    {
        BreakEven();
    }

    // close position
    if (rangeClose >= 0 && lastTick.time > range.close_time)
    {
        if (!ClosePositions())
            return;
    }

    // calculate new range if ...
    if (((rangeClose >= 0 && lastTick.time > range.close_time)                         // close time reached
         || (range.f_high_breakout && range.f_low_breakout)                            // both breakout flags are true
         || (range.end_time == 0)                                                      // range not calculated
         || (range.end_time != 0 && lastTick.time > range.end_time && !range.f_entry)) // there was a range calculated but no tick inside
        && CountOpenPositions() == 0)                                                  // no open positions
    {
        CalculateRange();
    }
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
    range.start_time = (lastTick.time - (lastTick.time % time_cycle)) + rangeStart * 60;
    if (lastTick.time >= range.start_time)
        range.start_time += time_cycle;
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
    range.end_time = range.start_time + rangeDuration * 60;
    if (lastTick.time >= range.end_time)
        range.end_time += time_cycle;
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
    if (rangeClose >= 0)
    {
        range.close_time = (range.end_time - (range.end_time % time_cycle)) + rangeClose * 60;
        if (range.close_time <= range.end_time)
            range.close_time += time_cycle;
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
        string symbol;
        if (!PositionGetString(POSITION_SYMBOL, symbol))
        {
            Print("Failed to get position magic number");
            return -1;
        }
        if (InpMagicNumber == magicNumber && symbol == Symbol())
            counter++;
    }

    return counter;
}

// check for breakouts
void CheckBreakouts()
{

    // Calculate the deviation
    double deviation = (range.high - range.low) * (InpDeviation * 0.01);

    // check if we are after the range end
    if (lastTick.time >= range.end_time && range.end_time > 0 && range.f_entry)
    {
        // check for high breakout
        if (!range.f_high_breakout && lastTick.ask >= (range.high + deviation) && InpTakeLongs)
        {
            range.f_high_breakout = true;
            if (InpBreakoutMode == ONE_SIGNAL)
                range.f_low_breakout = true;

            // calculate stop loss and take profit
            double sl = InpStopLoss == 0 ? 0 : NormalizeDouble(lastTick.bid - ((range.high - range.low) * (InpStopLoss * 0.01)), Digits());
            double tp = InpTakeProfit == 0 ? 0 : NormalizeDouble(lastTick.bid + ((range.high - range.low) * (InpTakeProfit * 0.01)), Digits());

            // open buy position
            if (InpTakeLongs)
                trade.PositionOpen(Symbol(), ORDER_TYPE_BUY, sl == 0 ? InpLots : Volume(), lastTick.ask, sl, tp, "Breakout ");
        }

        // check for low breakout
        if (!range.f_low_breakout && lastTick.bid <= (range.low - deviation) && InpTakeShorts)
        {
            range.f_low_breakout = true;
            if (InpBreakoutMode == ONE_SIGNAL)
                range.f_high_breakout = true;

            // calculate stop loss and take profit
            double sl = InpStopLoss == 0 ? 0 : NormalizeDouble(lastTick.ask + ((range.high - range.low) * (InpStopLoss * 0.01)), Digits());
            double tp = InpTakeProfit == 0 ? 0 : NormalizeDouble(lastTick.ask - ((range.high - range.low) * (InpTakeProfit * 0.01)), Digits());

            // open sell position
            if (InpTakeShorts)
                trade.PositionOpen(Symbol(), ORDER_TYPE_SELL, sl == 0 ? InpLots : Volume(), lastTick.bid, sl, tp, "Breakout ");
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
        string symbol;
        if (!PositionGetString(POSITION_SYMBOL, symbol))
        {
            Print("Failed to get position magic number");
            return false;
        }
        if (InpMagicNumber == magicNumber && symbol == Symbol())
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
    string nameStart = "range start " + TimeToString(range.start_time, TIME_DATE);
    ObjectDelete(NULL, nameStart);
    if (range.start_time > 0)
    {
        ObjectCreate(NULL, nameStart, OBJ_TREND, 0, range.start_time, range.high, range.start_time, range.low);
        ObjectSetString(NULL, nameStart, OBJPROP_TOOLTIP, nameStart);
        ObjectSetInteger(NULL, nameStart, OBJPROP_COLOR, InpColorRange);
        ObjectSetInteger(NULL, nameStart, OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, nameStart, OBJPROP_BACK, true);
    }

    // end time
    string nameEnd = "range end " + TimeToString(range.end_time, TIME_DATE);
    ObjectDelete(NULL, nameEnd);
    if (range.end_time > 0)
    {
        ObjectCreate(NULL, nameEnd, OBJ_TREND, 0, range.end_time, range.high, range.end_time, range.low);
        ObjectSetString(NULL, nameEnd, OBJPROP_TOOLTIP, nameEnd);
        ObjectSetInteger(NULL, nameEnd, OBJPROP_COLOR, InpColorRange);
        ObjectSetInteger(NULL, nameEnd, OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, nameEnd, OBJPROP_BACK, true);
    }

    // close time
    string nameClose = "range close " + TimeToString(range.close_time, TIME_DATE);
    ObjectDelete(NULL, nameClose);
    if (range.close_time > 0)
    {
        ObjectCreate(NULL, nameClose, OBJ_TREND, 0, range.close_time, range.high, range.close_time, range.low);
        ObjectSetString(NULL, nameClose, OBJPROP_TOOLTIP, nameClose);
        ObjectSetInteger(NULL, nameClose, OBJPROP_COLOR, InpColorBreakout);
        ObjectSetInteger(NULL, nameClose, OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, nameClose, OBJPROP_BACK, true);
    }

    // high
    string nameHigh = "range high " + TimeToString(range.end_time, TIME_DATE);
    ObjectsDeleteAll(NULL, nameHigh);
    if (range.high > 0)
    {
        ObjectCreate(NULL, nameHigh, OBJ_TREND, 0, range.start_time, range.high, range.end_time, range.high);
        ObjectSetString(NULL, nameHigh, OBJPROP_TOOLTIP, nameHigh);
        ObjectSetInteger(NULL, nameHigh, OBJPROP_COLOR, InpColorRange);
        ObjectSetInteger(NULL, nameHigh, OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, nameHigh, OBJPROP_BACK, true);

        ObjectCreate(NULL, " " + nameHigh, OBJ_TREND, 0, range.end_time, range.high, rangeClose >= 0 ? range.close_time : INT_MAX, range.high);
        ObjectSetString(NULL, " " + nameHigh, OBJPROP_TOOLTIP, nameHigh);
        ObjectSetInteger(NULL, " " + nameHigh, OBJPROP_COLOR, InpColorBreakout);
        ObjectSetInteger(NULL, " " + nameHigh, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(NULL, " " + nameHigh, OBJPROP_BACK, true);
    }

    // low
    string nameLow = "range low " + TimeToString(range.end_time, TIME_DATE);
    ObjectsDeleteAll(NULL, nameLow);
    if (range.low < DBL_MAX)
    {
        ObjectCreate(NULL, nameLow, OBJ_TREND, 0, range.start_time, range.low, range.end_time, range.low);
        ObjectSetString(NULL, nameLow, OBJPROP_TOOLTIP, nameLow);
        ObjectSetInteger(NULL, nameLow, OBJPROP_COLOR, InpColorRange);
        ObjectSetInteger(NULL, nameLow, OBJPROP_WIDTH, 2);
        ObjectSetInteger(NULL, nameLow, OBJPROP_BACK, true);

        ObjectCreate(NULL, " " + nameLow, OBJ_TREND, 0, range.end_time, range.low, rangeClose >= 0 ? range.close_time : INT_MAX, range.low);
        ObjectSetString(NULL, " " + nameLow, OBJPROP_TOOLTIP, nameLow);
        ObjectSetInteger(NULL, " " + nameLow, OBJPROP_COLOR, InpColorBreakout);
        ObjectSetInteger(NULL, " " + nameLow, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(NULL, " " + nameLow, OBJPROP_BACK, true);
    }

    // refresh chart
    ChartRedraw();
}

double Volume()
{
    double slDistance = (range.high - range.low) * InpStopLoss * 0.01;
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

        string symbol;
        if (!PositionGetString(POSITION_SYMBOL, symbol))
        {
            Print("Failed to get position magic number");
            continue;
        }
        if (InpMagicNumber != magic && symbol != Symbol())
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

        if (((long)type == (long)ORDER_TYPE_BUY && stopLoss >= entry) || ((long)type == (long)ORDER_TYPE_SELL && stopLoss <= entry))
            continue;

        // calculate a new stop loss distance based on the InpPercentBreakEven percentage
        double beDistance = NormalizeDouble((range.high - range.low) * (InpPercentBreakEven * 0.01), Digits());
        double additionalDistance = NormalizeDouble(MathAbs(entry - stopLoss) * (InpDeviation * 0.01), Digits());
        double newStopLoss = 0;

        if ((long)type == (long)ORDER_TYPE_BUY)
        {
            newStopLoss = entry + additionalDistance;
        }
        else if ((long)type == (long)ORDER_TYPE_SELL)
        {
            newStopLoss = entry - additionalDistance;
        }

        if (((long)type == (long)ORDER_TYPE_BUY && lastTick.bid > entry + beDistance) || ((long)type == (long)ORDER_TYPE_SELL && lastTick.ask < entry - beDistance))
        {
            if ((long)type == (long)ORDER_TYPE_BUY)
                trade.PositionModify(ticket, newStopLoss, takeProfit);

            if ((long)type == (long)ORDER_TYPE_SELL)
                trade.PositionModify(ticket, newStopLoss, takeProfit);
        }
    }
    return;
}

// function to get DST offset
int DSTOffset()
{
    int offset = InpTimezone;
    if (!InpDaylightSaving)
        return offset;

    string current_date = TimeToString(TimeCurrent(), TIME_DATE); // gets result as "yyyy.mm.dd",
    long month = StringToInteger(StringSubstr(current_date, 5, 2));
    long day = StringToInteger(StringSubstr(current_date, 8, 2));

    // check if we are in DST
    int DST_start_month = 3; // March
    int DST_start_day = 11;  // average second Sunday
    int DST_end_month = 10;  // October
    int DST_end_day = 4;     // average first Sunday

    if (month > DST_start_month && month < DST_end_month)
    {
        offset++;
    }
    else if (month == DST_start_month && day > DST_start_day)
    {
        offset++;
    }
    else if (month == DST_end_month && day < DST_end_day)
    {
        offset++;
    }

    return offset;
}

void DSTAdjust()
{
    // get DST offset
    DSToffset = DSTOffset();

    // adjust range times
    rangeStart = (InpRangeStart + DSToffset) * 60;       // Range start time in minutes
    rangeDuration = (InpRangeStop - InpRangeStart) * 60; // Range duration in minutes
    rangeClose = (InpRangeClose + DSToffset) * 60;       // Range close time in minutes
}