//+------------------------------------------------------------------+
//|                                                          hlb.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

static input long InpMagic = 123456; // Magic number
static input double InpLots = 1;     // Risk
input int InpBars = 24;              // Bars
input int InpIndexFilter = 0;        // Index Filter
input int InpSizeFilter = 0;         // Size Filter
input int InpTakeProfit = 0;         // Take profit (0 = off)
input int InpStopLoss = 0;           // Stop loss (0 = off)
input bool InpTrailingSL = true;     // Trailing Stop loss

double high = 0;   // highest price of the last N bars
double low = 0;    // lowest price of the last N bars
int highIndex = 0; // index of the highest price
int lowIndex = 0;  // index of the lowest price
MqlTick currentTick, previousTick;

int OnInit()
{
  trade.SetExpertMagicNumber(InpMagic);
  return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
  if (!IsNewBar())
  {
    return;
  }

  // get tick
  previousTick = currentTick;
  if (!SymbolInfoTick(Symbol(), currentTick))
  {
    Print("Failed to get tick");
    return;
  }

  int cntBuy, cntSell;
  if (!CountOpenPositions(cntBuy, cntSell))
  {
    return;
  }

  // check for buy position
  if (cntBuy == 0 && high != 0 && previousTick.ask < high && currentTick.ask >= high && CheckIndexFilter(highIndex) && CheckSizeFilter())
  {
    double distance = NormalizeDouble(currentTick.last - low, Digits());
    double sl = InpStopLoss == 0 ? 0 : currentTick.bid - distance * InpStopLoss * 0.01;
    double tp = InpTakeProfit == 0 ? 0 : currentTick.bid + distance * InpTakeProfit * 0.01;

    if (!NormalizePrice(sl))
    {
      Print("Failed to normalize stop loss price");
      return;
    }
    if (!NormalizePrice(tp))
    {
      Print("Failed to normalize take profit price");
      return;
    }

    trade.PositionOpen(Symbol(), ORDER_TYPE_BUY, InpStopLoss > 0 ? Volume(distance) : InpLots, currentTick.ask, sl, tp, "HighLowBreakout");
  }

  // check for sell position
  if (cntSell == 0 && low != 0 && previousTick.bid > low && currentTick.bid <= low && CheckIndexFilter(lowIndex) && CheckSizeFilter())
  {
    double distance = NormalizeDouble(high - currentTick.last, Digits());
    double sl = InpStopLoss == 0 ? 0 : currentTick.ask + distance * InpStopLoss * 0.01;
    double tp = InpTakeProfit == 0 ? 0 : currentTick.ask - distance * InpTakeProfit * 0.01;

    if (!NormalizePrice(sl))
    {
      Print("Failed to normalize stop loss price");
      return;
    }
    if (!NormalizePrice(tp))
    {
      Print("Failed to normalize take profit price");
      return;
    }

    trade.PositionOpen(Symbol(), ORDER_TYPE_SELL, InpStopLoss > 0 ? Volume(distance) : InpLots, currentTick.bid, sl, tp, "HighLowBreakout");
  }

  // update stop loss
  if (InpTrailingSL && InpStopLoss > 0)
  {
    UpdateStopLoss(InpStopLoss * 0.01 * NormalizeDouble(high - low, Digits()));
  }

  // calc high and low
  highIndex = iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, InpBars, 1);
  lowIndex = iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, InpBars, 1);
  high = iHigh(Symbol(), PERIOD_CURRENT, highIndex);
  low = iLow(Symbol(), PERIOD_CURRENT, lowIndex);

  DrawObjects();
}

bool CheckInputs()
{

  return true;
}

bool CheckIndexFilter(int index)
{
  if (InpIndexFilter > 0 && (index <= round(InpBars * InpIndexFilter * 0.01) || index > InpBars - round(InpBars * InpIndexFilter * 0.01)))
  {
    return false;
  }
  return true;
}

bool CheckSizeFilter()
{
  if (InpSizeFilter > 0 && (high - low) > InpSizeFilter * Point())
  {
    return false;
  }
  return true;
}

void DrawObjects()
{
  datetime time1 = iTime(Symbol(), PERIOD_CURRENT, InpBars);
  datetime time2 = iTime(Symbol(), PERIOD_CURRENT, 1);

  // high
  ObjectDelete(NULL, "high");
  ObjectCreate(NULL, "high", OBJ_TREND, 0, time1, high, time2, high);
  ObjectSetInteger(NULL, "high", OBJPROP_WIDTH, 3);
  ObjectSetInteger(NULL, "high", OBJPROP_COLOR, CheckIndexFilter(highIndex) && CheckSizeFilter() ? clrBlue : clrBlack);

  // low
  ObjectDelete(NULL, "low");
  ObjectCreate(NULL, "low", OBJ_TREND, 0, time1, low, time2, low);
  ObjectSetInteger(NULL, "low", OBJPROP_WIDTH, 3);
  ObjectSetInteger(NULL, "low", OBJPROP_COLOR, CheckIndexFilter(lowIndex) && CheckSizeFilter() ? clrBlue : clrBlack);

  // index filter
  ObjectDelete(NULL, "indexFilter");
  if (InpIndexFilter > 0)
  {
    datetime timeIF1 = iTime(Symbol(), PERIOD_CURRENT, (int)(InpBars - round(InpBars * InpIndexFilter * 0.01)));
    datetime timeIF2 = iTime(Symbol(), PERIOD_CURRENT, (int)(round(InpBars * InpIndexFilter * 0.01)));
    ObjectCreate(NULL, "indexFilter", OBJ_RECTANGLE, 0, timeIF1, low, timeIF2, high);
    ObjectSetInteger(NULL, "indexFilter", OBJPROP_BACK, true);
    ObjectSetInteger(NULL, "indexFilter", OBJPROP_FILL, true);
    ObjectSetInteger(NULL, "indexFilter", OBJPROP_COLOR, clrGray);
  }

  // text
  ObjectDelete(NULL, "text");
  ObjectCreate(NULL, "text", OBJ_TEXT, 0, time1, low);
  ObjectSetInteger(NULL, "text", OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
  ObjectSetInteger(NULL, "text", OBJPROP_COLOR, clrBlue);
  ObjectSetString(NULL, "text", OBJPROP_TEXT, "Bars: " + (string)InpBars + " Index Filter: " + DoubleToString(round(InpBars * InpIndexFilter * 0.01), 0) + " High Index: " + (string)highIndex + " Low Index: " + (string)lowIndex + " Size: " + DoubleToString((high - low) / Point(), 0));
}

bool IsNewBar()
{

  static datetime previousTime = 0;
  datetime currentTime = iTime(Symbol(), PERIOD_CURRENT, 0);
  if (currentTime != previousTime)
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
  for (int i = total - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (ticket <= 0)
    {
      Print("Failed to get ticket");
      return false;
    }
    if (!PositionSelectByTicket(ticket))
    {
      Print("Failed to select position by ticket");
      return false;
    }
    long magic;
    if (!PositionGetInteger(POSITION_MAGIC, magic))
    {
      Print("Failed to get magic number");
      return false;
    }
    if (magic == InpMagic)
    {
      long type;
      if (!PositionGetInteger(POSITION_TYPE, type))
      {
        Print("Failed to get position type");
        return false;
      }
      if (type == POSITION_TYPE_BUY)
      {
        cntBuy++;
      }
      if (type == POSITION_TYPE_SELL)
      {
        cntSell++;
      }
    }
  }
  return true;
}

// normalize price
bool NormalizePrice(double &price)
{
  double tickSize = 0;
  if (!SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE, tickSize))
  {
    Print("Failed to get tick size");
    return false;
  }
  price = NormalizeDouble(MathRound(price / tickSize) * tickSize, Digits());

  return true;
}

// close positions
bool ClosePositions(int all_buy_sell)
{
  int total = PositionsTotal();
  for (int i = total - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (ticket <= 0)
    {
      Print("Failed to get ticket");
      return false;
    }
    if (!PositionSelectByTicket(ticket))
    {
      Print("Failed to select position by ticket");
      return false;
    }
    long magic;
    if (!PositionGetInteger(POSITION_MAGIC, magic))
    {
      Print("Failed to get position magic");
      return false;
    }
    if (magic == InpMagic)
    {
      long type;
      if (!PositionGetInteger(POSITION_TYPE, type))
      {
        Print("Failed to get position type");
        return false;
      }
      if ((all_buy_sell == 1 && type == POSITION_TYPE_SELL) || (all_buy_sell == 2 && type == POSITION_TYPE_BUY))
      {
        continue;
      }
      trade.PositionClose(ticket);
      if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
      {
        Print("Failed to close position. ticket: ", (string)ticket, "result: ", (string)trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
    }
  }

  return true;
}

// update stop loss
void UpdateStopLoss(double slDistance)
{

  // loop through open positions
  int total = PositionsTotal();
  for (int i = total - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (ticket <= 0)
    {
      Print("Failed to get ticket");
      return;
    }
    if (!PositionSelectByTicket(ticket))
    {
      Print("Failed to select position by ticket");
      return;
    }
    ulong magic;
    if (!PositionGetInteger(POSITION_MAGIC, magic))
    {
      Print("Failed to get position magic");
      return;
    }
    if (magic == InpMagic)
    {
      long type;
      if (!PositionGetInteger(POSITION_TYPE, type))
      {
        Print("Failed to get position type");
        return;
      }

      double currSL, currTP;
      if (!PositionGetDouble(POSITION_SL, currSL))
      {
        Print("Failed to get stop loss");
        return;
      }
      if (!PositionGetDouble(POSITION_TP, currTP))
      {
        Print("Failed to get take profit");
        return;
      }
      double currPrice = POSITION_TYPE_BUY == type ? currentTick.bid : currentTick.ask;
      int n = type == POSITION_TYPE_BUY ? 1 : -1;
      double newSL = currPrice - slDistance * n;
      if (!NormalizePrice(newSL))
      {
        Print("Failed to normalize stop loss price");
        return;
      }
      if ((newSL * n) < (currSL * n) || NormalizeDouble(MathAbs(newSL - currSL), Digits()) < Point())
      {
        continue;
      }
      // check for stop level
      long level = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
      if (level != 0 && MathAbs(currPrice - newSL) <= level * Point())
      {
        Print("Stop level violation");
        continue;
      }
      // modify position with new stop loss
      if (!trade.PositionModify(ticket, newSL, currTP))
      {
        Print("Failed to modify position. ticket: ", (string)ticket, "result: ", (string)trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
    }
  }
}

double Volume(double slDistance)
{
  double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
  double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
  double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

  double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpLots / 100;
  double moneyLotStep = (slDistance / tickSize) * tickValue * lotStep;

  double lots = MathFloor(riskMoney / moneyLotStep) * lotStep;

  double minVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
  double maxVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);

  if (lots < minVol)
  {
    lots = minVol;
    Print(lots, " Adjusted to minimum volume ", minVol);
  }
  else if (lots > maxVol)
  {
    lots = maxVol;
    Print(lots, " Adjusted to maximum volume ", minVol);
  }

  return lots;
}

// double AtrValue()
// {
//     double priceArray[];
//     int atrDef = iATR(Symbol(), PERIOD_CURRENT, InpBars);
//     ArraySetAsSeries(priceArray, true);
//     CopyBuffer(atrDef, 0, 0, 1, priceArray);
//     double atrValue = NormalizeDouble(priceArray[0], Digits());
//     return atrValue * InpATRMultiplier;
// }