#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property description "Multi time range breakout trading strategy, XAUUSD/EURUSD/USDJPY "

#include <Trade\Trade.mqh>
#include <Generic\HashMap.mqh>
#include <Strings\String.mqh>

// Input parameters
input bool fixedRisk = false; // fixed risk
input group "========= Symbol settings =========";
input string InpSymbol = "AUDUSD, EURUSD, GBPUSD, USDCAD, USDCHF, USDJPY, XAUUSD"; // Symbol
string symbols[];

input group "========= Entry settings =========";
input double InpLots = 1.0;      // Risk %
input bool InpTakeLongs = true;  // Long trades
input bool InpTakeShorts = true; // Short trades
input int InpDeviation = 0;      // Deviation (0 = off)
long InpMagicNumber;

input group "========= Exit settings =========";
input int InpTakeProfit = 0;         // TP % range (0 = off)
input int InpStopLoss = 100;         // SL % range (0 = off)
input int InpPercentBreakEven = 100; // BE % range (0 = off)

input group "========= Time settings =========";
input int InpTimezone = 3;           // Timezone
input bool InpDaylightSaving = true; // DST zone
int DSToffset;                       // DST offset

input group "========= Range settings =========";
input int InpRangeStart = 6;  // Range start hour
input int InpRangeStop = 10;  // Range stop hour
input int InpRangeClose = 17; // Range close hour (0 = off)
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

input group "========= Filter settings =========";
input int InpMaPeriod = 120; // EMA period (0 = off)
enum MA_FILTER_MODE_ENUM
{
  // no filter, filter in direction of trend, filter against trend, filter in direction of trend and against trend
  NO_FILTER,
  TREND_FILTER,
  COUNTER_TREND_FILTER,
  TREND_AND_COUNTER_TREND_FILTER
};
input MA_FILTER_MODE_ENUM InpMaFilterMode = NO_FILTER; // MA Filter mode

struct RANGE_STRUCT
{
  string symbol;                      // symbol
  datetime start_time;                // start of the range
  datetime end_time;                  // end of the range
  datetime close_time;                // close of the range
  MqlTick prevTick;                   // previous tick
  MqlTick lastTick;                   // last tick
  double high;                        // high of the range
  double low;                         // low of the range
  bool f_entry;                       // flag if we are in the range
  bool f_high_breakout;               // flag if a high breakout occured
  bool f_low_breakout;                // flag if a low breakout occured
  int maHandle;                       // EMA handle
  int maDirection;                    // EMA direction
  int lastMaDirection;                // last EMA direction
  int periodSinceLastDirectionChange; // period since last EMA direction change

  RANGE_STRUCT() : symbol(""), start_time(0), end_time(0), close_time(0), high(0.0), low(DBL_MAX), f_entry(false), f_high_breakout(false), f_low_breakout(false) {}
};

CTrade trade;
RANGE_STRUCT ranges[];

int OnInit()
{
  long accountNumbers[] = {11028867, 7216275, 7222732, 10000973723};
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

  // clear arrays
  ArrayFree(symbols);
  ArrayFree(ranges);
  StringSplit(InpSymbol, ',', symbols);
  ArrayResize(ranges, ArraySize(symbols));
  for (int i = 0; i < ArraySize(symbols); i++)
  {
    string symbol = symbols[i];
    StringTrimRight(symbol); // remove trailing spaces
    StringTrimLeft(symbol);  // remove leading spaces
    StringToUpper(symbol);   // convert to uppercase
    symbols[i] = symbol;
    // check if symbol is in market watch
    if (!SymbolSelect(symbol, true))
    {
      Alert("Symbol " + symbol + " is not in market watch");
      return INIT_FAILED;
    }
    RANGE_STRUCT range;
    range.symbol = symbol; // set range.symbol to the symbol
    // initialize other range members here...
    if (InpMaPeriod > 0)
      range.maHandle = iMA(symbol, 0, InpMaPeriod, 0, MODE_EMA, PRICE_CLOSE);
    // Add the range to the ranges array
    ranges[i] = range;
  }

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
  ObjectsDeleteAll(NULL);
  ClosePositions();
  Print("\n" + InpSymbol + " | " + Profit() + " | " + DrawDown() + "\n");
}

void OnTick()
{
  for (int r = 0; r < ArraySize(ranges); r++)
  {
    RANGE_STRUCT range = ranges[r];
    range.prevTick = range.lastTick;
    SymbolInfoTick(range.symbol, range.lastTick);
    ranges[r] = range;
  }

  // ma
  MA();
  // check if we are in the range
  RangeCheck();
  // check for breakouts
  CheckBreakouts();
  // breakeven
  BreakEven();
  // DST
  DSTAdjust();
  // stats
  Stats();
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

void MA()
{
  if (InpMaPeriod <= 0 || InpMaFilterMode == NO_FILTER)
    return;

  static int barsTotal;
  int bars = iBars(Symbol(), Period());
  if (barsTotal >= bars)
    return;
  barsTotal = bars;

  for (int r = 0; r < ArraySize(ranges); r++)
  {
    RANGE_STRUCT range = ranges[r];

    double ma[];
    ArraySetAsSeries(ma, true);
    CopyBuffer(range.maHandle, MAIN_LINE, 0, barsTotal, ma);

    double high = iHigh(range.symbol, 0, 0);
    double low = iLow(range.symbol, 0, 0);

    int newMaDirection = 0;
    if (low > ma[0])
      newMaDirection = 1;
    if (high < ma[0])
      newMaDirection = -1;
   
    if (newMaDirection != range.lastMaDirection)
    {
      range.periodSinceLastDirectionChange = 1;
      range.lastMaDirection = newMaDirection;
    }
    else
    {
      range.periodSinceLastDirectionChange++;
    }

    int changePeriod = InpMaPeriod / 5;
    if (range.periodSinceLastDirectionChange >= changePeriod)
    {
      range.maDirection = newMaDirection;
    }
    else
    {
      range.maDirection = 0;
    }
    ranges[r] = range;

    // draw ma
    if (range.symbol != Symbol())
      continue;

    ObjectCreate(0, "Ma " + (string)range.lastTick.time, OBJ_TREND, 0, range.lastTick.time, ma[0], range.prevTick.time, ma[1]);
    ObjectSetInteger(0, "Ma " + (string)range.lastTick.time, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, "Ma " + (string)range.lastTick.time, OBJPROP_WIDTH, 4);
    ObjectSetInteger(0, "Ma " + (string)range.lastTick.time, OBJPROP_BACK, true);
    ObjectSetInteger(0, "Ma " + (string)range.lastTick.time, OBJPROP_COLOR, range.maDirection == 1 ? clrGreen : range.maDirection == -1 ? clrRed
                                                                                                                                        : clrGold);
  }
}

void RangeCheck()
{
  for (int r = 0; r < ArraySize(ranges); r++)
  {
    RANGE_STRUCT range = ranges[r];

    // range calculation
    if (range.lastTick.time > range.start_time && range.lastTick.time < range.end_time)
    {
      // set flag
      range.f_entry = true;
      ranges[r] = range;
      // new high
      if (range.lastTick.ask > range.high)
      {
        range.high = range.lastTick.ask;
        ranges[r] = range;
        DrawObjects();
      }
      // new low
      if (range.lastTick.bid < range.low)
      {
        range.low = range.lastTick.bid;
        ranges[r] = range;
        DrawObjects();
      }
    }

    if (range.lastTick.time > range.end_time && range.lastTick.time < range.close_time)
    {

      ranges[r] = range;
      BreakEven();
    }

    // close position
    if (rangeClose >= 0 && range.lastTick.time > range.close_time)
    {
      ranges[r] = range;
      if (!ClosePositions())
        return;
    }

    // calculate new range if ...
    if (((rangeClose >= 0 && range.lastTick.time > range.close_time)                         // close time reached
         || (range.f_high_breakout && range.f_low_breakout)                                  // both breakout flags are true
         || (range.end_time == 0)                                                            // range not calculated
         || (range.end_time != 0 && range.lastTick.time > range.end_time && !range.f_entry)) // there was a range calculated but no tick inside
        && CountOpenPositions() == 0)                                                        // no open positions
    {
      ranges[r] = range;
      CalculateRange();
    }
  }
}

// calculate a new range
void CalculateRange()
{
  for (int r = 0; r < ArraySize(ranges); r++)
  {
    RANGE_STRUCT range = ranges[r];

    // reset range variables
    range.start_time = 0;
    range.end_time = 0;
    range.close_time = 0;
    range.high = 0.0;
    range.low = DBL_MAX;
    range.f_entry = false;
    range.f_high_breakout = false;
    range.f_low_breakout = false;
    ranges[r] = range;

    // calculate range start time
    int time_cycle = 86400;
    range.start_time = (range.lastTick.time - (range.lastTick.time % time_cycle)) + rangeStart * 60;
    if (range.lastTick.time >= range.start_time)
      range.start_time += time_cycle;
    for (int i = 0; i < 8; i++)
    {
      MqlDateTime tmp;
      TimeToStruct(range.start_time, tmp);
      int dow = tmp.day_of_week;
      if (range.lastTick.time >= range.start_time || dow == 6 || dow == 0 || (dow == 1 && !InpMonday) || (dow == 2 && !InpTuesday) || (dow == 3 && !InpWednesday) || (dow == 4 && !InpThursday) || (dow == 5 && !InpFriday))
      {
        range.start_time += time_cycle;
      }
    }

    // calculate range end time
    range.end_time = range.start_time + rangeDuration * 60;
    if (range.lastTick.time >= range.end_time)
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
    ranges[r] = range;
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
  for (int r = 0; r < ArraySize(ranges); r++)
  {
    RANGE_STRUCT range = ranges[r];
    // Calculate the deviation
    double deviation = (range.high - range.low) * InpDeviation * 0.01;

    // check if we are after the range end
    if (range.lastTick.time >= range.end_time && range.end_time > 0 && range.f_entry)
    {
      // check for high breakout
      if (!range.f_high_breakout && range.lastTick.last >= (range.high + deviation) && InpTakeLongs)
      {
        range.f_high_breakout = true;
        if (InpBreakoutMode == ONE_SIGNAL)
          range.f_low_breakout = true;

        // calculate stop loss and take profit
        double sl = InpStopLoss == 0 ? 0 : NormalizeDouble(range.lastTick.ask - ((range.lastTick.ask - range.low) * InpStopLoss * 0.01), Digits());
        double tp = InpTakeProfit == 0 ? 0 : NormalizeDouble(range.lastTick.ask + ((range.lastTick.ask - range.low) * (InpTakeProfit * 0.01)), Digits());
        double slDistance = (range.lastTick.ask - range.low) * InpStopLoss * 0.01;

        // open buy position
        if (InpTakeLongs && (InpMaPeriod == 0 || InpMaFilterMode == NO_FILTER || (InpMaFilterMode == TREND_FILTER && range.maDirection > 0) || (InpMaFilterMode == COUNTER_TREND_FILTER && range.maDirection < 0) || (InpMaFilterMode == TREND_AND_COUNTER_TREND_FILTER && range.maDirection != 0)))
          trade.PositionOpen(range.symbol, ORDER_TYPE_BUY, sl == 0 ? InpLots : Volume(range.symbol, slDistance), range.lastTick.ask, sl, tp, "Breakout ");
      }

      // check for low breakout
      if (!range.f_low_breakout && range.lastTick.last <= (range.low - deviation) && InpTakeShorts)
      {
        range.f_low_breakout = true;
        if (InpBreakoutMode == ONE_SIGNAL)
          range.f_high_breakout = true;

        // calculate stop loss and take profit
        double sl = InpStopLoss == 0 ? 0 : NormalizeDouble(range.lastTick.bid + ((range.high - range.lastTick.bid) * (InpStopLoss * 0.01)), Digits());
        double tp = InpTakeProfit == 0 ? 0 : NormalizeDouble(range.lastTick.bid - ((range.high - range.lastTick.bid) * (InpTakeProfit * 0.01)), Digits());
        double slDistance = (range.high - range.lastTick.bid) * InpStopLoss * 0.01;

        // open sell position
        if (InpTakeShorts && (InpMaPeriod == 0 || InpMaFilterMode == NO_FILTER || (InpMaFilterMode == TREND_FILTER && range.maDirection < 0) || (InpMaFilterMode == COUNTER_TREND_FILTER && range.maDirection > 0) || (InpMaFilterMode == TREND_AND_COUNTER_TREND_FILTER && range.maDirection != 0)))
          trade.PositionOpen(range.symbol, ORDER_TYPE_SELL, sl == 0 ? InpLots : Volume(range.symbol, slDistance), range.lastTick.bid, sl, tp, "Breakout ");
      }
    }
    ranges[r] = range;
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
    for (int r = 0; r < ArraySize(ranges); r++)
    {
      RANGE_STRUCT range = ranges[r];
      if (range.symbol != symbol)
        continue;
      if (InpMagicNumber != magicNumber)
        continue;
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

void DrawTrendLine(string name, datetime x1, double y1, datetime x2, double y2, color clr, int width, int style, bool back, string tooltip)
{
  ObjectDelete(NULL, name);
  ObjectCreate(NULL, name, OBJ_TREND, 0, x1, y1, x2, y2);
  ObjectSetInteger(NULL, name, OBJPROP_COLOR, clr);
  ObjectSetInteger(NULL, name, OBJPROP_WIDTH, width);
  ObjectSetInteger(NULL, name, OBJPROP_STYLE, style);
  ObjectSetInteger(NULL, name, OBJPROP_BACK, back);
  ObjectSetString(NULL, name, OBJPROP_TOOLTIP, tooltip);
}

// draw chart objects
void DrawObjects()
{
  for (int r = 0; r < ArraySize(ranges); r++)
  {
    RANGE_STRUCT range = ranges[r];
    if (range.symbol != Symbol())
      continue;

    if (range.start_time > 0)
      DrawTrendLine("range start " + TimeToString(range.start_time, TIME_DATE), range.start_time, range.high, range.start_time, range.low, InpColorRange, 2, STYLE_SOLID, true, TimeToString(range.start_time, TIME_MINUTES));
    if (range.end_time > 0)
      DrawTrendLine("range end " + TimeToString(range.end_time, TIME_DATE), range.end_time, range.high, range.end_time, range.low, InpColorRange, 2, STYLE_SOLID, true, TimeToString(range.end_time, TIME_MINUTES));
    if (range.close_time > 0)
      DrawTrendLine("range close " + TimeToString(range.close_time, TIME_DATE), range.close_time, range.high, range.close_time, range.low, InpColorBreakout, 2, STYLE_SOLID, true, TimeToString(range.close_time, TIME_MINUTES));
    if (range.high > 0)
    {
      DrawTrendLine("range high " + TimeToString(range.end_time, TIME_DATE), range.start_time, range.high, range.end_time, range.high, InpColorRange, 2, STYLE_SOLID, true, DoubleToString(range.high, Digits()));
      DrawTrendLine(" range high " + TimeToString(range.end_time, TIME_DATE), range.end_time, range.high, rangeClose >= 0 ? range.close_time : INT_MAX, range.high, InpColorBreakout, 2, STYLE_DOT, true, DoubleToString(range.high, Digits()));
    }
    if (range.low < DBL_MAX)
    {
      DrawTrendLine("range low " + TimeToString(range.end_time, TIME_DATE), range.start_time, range.low, range.end_time, range.low, InpColorRange, 2, STYLE_SOLID, true, DoubleToString(range.low, Digits()));
      DrawTrendLine(" range low " + TimeToString(range.end_time, TIME_DATE), range.end_time, range.low, rangeClose >= 0 ? range.close_time : INT_MAX, range.low, InpColorBreakout, 2, STYLE_DOT, true, DoubleToString(range.low, Digits()));
    }

    // refresh chart
    ChartRedraw();
  }
}

double Volume(string symbol, double slDistance)
{
  double balance = AccountInfoDouble(ACCOUNT_BALANCE);
  if (fixedRisk)
    balance = startCapital;
  double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
  double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
  double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
  double riskMoney = balance * InpLots / 100;
  double moneyLotStep = (slDistance / tickSize) * tickValue * lotStep;
  double lots = MathRound(riskMoney / moneyLotStep) * lotStep;
  double minVol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
  double maxVol = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

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
  if (InpPercentBreakEven == 0 || InpStopLoss == 0)
    return;

  int total = PositionsTotal();
  for (int i = total - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (!PositionSelectByTicket(ticket))
    {
      Print("Failed to select position by ticket");
      continue;
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
      Print("Failed to get position symbol");
      continue;
    }
    for (int r = 0; r < ArraySize(ranges); r++)
    {
      RANGE_STRUCT range = ranges[r];
      if (range.symbol != symbol)
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

      if (((long)type == (long)ORDER_TYPE_BUY && range.lastTick.last >= entry + beDistance) || ((long)type == (long)ORDER_TYPE_SELL && range.lastTick.last <= entry - beDistance))
      {
        if ((long)type == (long)ORDER_TYPE_BUY)
          trade.PositionModify(ticket, newStopLoss, takeProfit);

        if ((long)type == (long)ORDER_TYPE_SELL)
          trade.PositionModify(ticket, newStopLoss, takeProfit);
      }
    }
    return;
  }
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
  if (!IsNewBar(PERIOD_D1))
    return;

  // get DST offset
  DSToffset = DSTOffset();

  // adjust range times
  rangeStart = (InpRangeStart + DSToffset) * 60;       // Range start time in minutes
  rangeDuration = (InpRangeStop - InpRangeStart) * 60; // Range duration in minutes
  rangeClose = (InpRangeClose + DSToffset) * 60;       // Range close time in minutes
}

double realBalance;
double maxDrawdown;
string DrawDown()
{
  string result = "";
  double balance = AccountInfoDouble(ACCOUNT_BALANCE);
  if (balance > realBalance)
    realBalance = balance;
  double equity = AccountInfoDouble(ACCOUNT_EQUITY);
  double drawdown = 100 - equity / realBalance * 100;
  if (drawdown > maxDrawdown)
    maxDrawdown = drawdown;
  maxDrawdown = NormalizeDouble(maxDrawdown, 2);
  if (maxDrawdown == 0)
    return result;
  return "Drawdown: " + (string)maxDrawdown + "%";
  return result;
}

datetime startDate = TimeCurrent();
double startCapital = AccountInfoDouble(ACCOUNT_BALANCE);
string Profit()
{
  string result = "";
  double balance = AccountInfoDouble(ACCOUNT_BALANCE);
  double profit = balance - startCapital;
  double profitPercent = profit / startCapital * 100;
  datetime endDate = TimeCurrent();
  int days = (int)(endDate - startDate) / 86400;
  int tradingDays = days * 5 / 7;
  double profitPerDay = profitPercent / tradingDays;
  double profitPerMonth = profitPerDay * 20;
  profitPercent = NormalizeDouble(profitPercent, 2);
  profitPerDay = NormalizeDouble(profitPerDay, 2);
  profitPerMonth = NormalizeDouble(profitPerMonth, 2);
  result = "Profit: " + (string)profitPercent + "%";
  if (tradingDays > 0)
    result += " | Profit per day: " + (string)profitPerDay + "%";
  if (tradingDays > 20)
    result += " | Profit per month: " + (string)profitPerMonth + "%";
  return result;
}
void Stats()
{
  if (!IsNewBarStats(PERIOD_D1))
    return;

  string stats = "\n" + " | " + Profit() + " | " + DrawDown() + "\n";
  for (int r = 0; r < ArraySize(ranges); r++)
  {
    RANGE_STRUCT range = ranges[r];
    string rangeString = range.symbol + " " + (range.maDirection == 1 ? "Up" : range.maDirection == -1 ? "Down"
                                                                           : range.maDirection == 0    ? "Flat"
                                                                                                       : "Unknown") +
                         "\n";
    stats += rangeString;
  }
  Comment(stats);
  Print(stats);
}

bool IsNewBar(ENUM_TIMEFRAMES timeFrame)
{
  static int barsTotal;
  int bars = iBars(Symbol(), timeFrame);
  if (bars > barsTotal)
  {
    barsTotal = bars;
    return true;
  }
  return false;
}
bool IsNewBarStats(ENUM_TIMEFRAMES timeFrame)
{
  static int barsTotal;
  int bars = iBars(Symbol(), timeFrame);
  if (bars > barsTotal)
  {
    barsTotal = bars;
    return true;
  }
  return false;
}