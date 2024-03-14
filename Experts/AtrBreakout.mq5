#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

// inputs
input double InpRisk = 1.0;                  // risk
input int atrPeriod = 24;                    // ATR period
input ENUM_TIMEFRAMES timeframe = PERIOD_H1; // timeframe
input bool longTrade = true;                 // long trades
input bool shortTrade = true;                // short trades
input bool plot = true;                      // plot levels
input int InpMagicNumber = 8;                // magic number
input double InpTrailingStop = 0.25;         // trailing stop
input double atrMultiplier = 1;              // ATR multiplier
input int startHour = 1;                     // start hour
input int endHour = 23;                      // end hour

// Declare the ATR handle
int atrHandle;

// Initialize the ATR handle in OnInit()
int OnInit()
{
  atrHandle = iATR(Symbol(), timeframe, atrPeriod);
  if (atrHandle == INVALID_HANDLE)
  {
    Print("Error creating ATR indicator handle: ", GetLastError());
    return INIT_FAILED;
  }

  trade.SetExpertMagicNumber(InpMagicNumber);
  return INIT_SUCCEEDED;
}

double currentPrice;
void OnTick()
{
  Trade();
  Trail();
}

void Trade()
{
  MqlDateTime mdt;
  TimeCurrent(mdt);
  if (mdt.hour < startHour || mdt.hour > endHour)
    return;

  double atrArray[];
  if (CopyBuffer(atrHandle, 0, 1, 1, atrArray) <= 0)
  {
    Print("Error copying ATR buffer: ", GetLastError());
    return;
  }
  double atrValue = atrArray[0] * atrMultiplier;

  double previousHigh = iHigh(Symbol(), timeframe, 1);
  double previousLow = iLow(Symbol(), timeframe, 1);

  double upperLevel = previousHigh + atrValue;
  double lowerLevel = previousLow - atrValue;

  double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
  double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);

  currentPrice = (bid + ask) / 2;
  double stopDistance = NormalizeDouble(MathAbs(upperLevel - lowerLevel), Digits());
  double volume;

  string msg = "Breakout " + (string)stopDistance;

  if (longTrade && currentPrice > upperLevel && IsNewBar())
  {
    volume = Volume(stopDistance);
    trade.Buy(volume, NULL, 0, lowerLevel, 0, msg);
  }
  else if (shortTrade && currentPrice < lowerLevel && IsNewBar())
  {
    volume = Volume(stopDistance);
    trade.Sell(volume, NULL, 0, upperLevel, 0, msg);
  }
}

double Volume(double stopDistance)
{
  double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
  double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
  double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
  double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRisk / 100);
  double moneyLotStep = stopDistance / tickSize * tickValue * lotStep;
  double lots = MathRound(riskMoney / moneyLotStep) * lotStep;
  double minVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
  double maxVol = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);

  if (lots < minVol)
  {
    Print(lots, " > Adjusted to minimum volume > ", minVol);
    return minVol;
  }
  else if (lots > maxVol)
  {
    Print(lots, " > Adjusted to maximum volume > ", maxVol);
    return maxVol;
  }

  return NormalizeDouble(lots, 2);
}

bool IsNewBar()
{
  static int barsTotal;
  int bars = iBars(Symbol(), timeframe);
  if (barsTotal != bars)
  {
    barsTotal = bars;
    return true;
  }
  return false;
}

void Trail()
{
  if (InpTrailingStop <= 0 && InpTrailingStop > 100)
    return;

  int total = PositionsTotal();
  for (int i = total - 1; i >= 0; i--)
  {
    if (total != PositionsTotal())
    {
      total = PositionsTotal();
      i = total;
      continue;
    }
    ulong ticket = PositionGetTicket(i);
    if (ticket <= 0)
    {
      Print("Failed to get position ticket");
      return;
    }
    if (!PositionSelectByTicket(ticket))
    {
      Print("Failed to select position by ticket");
      return;
    }
    long magicNumber;
    if (!PositionGetInteger(POSITION_MAGIC, magicNumber))
    {
      Print("Failed to get position magic number");
      return;
    }
    if (InpMagicNumber != magicNumber)
      continue;
    string symbol;
    if (!PositionGetString(POSITION_SYMBOL, symbol))
    {
      Print("Failed to get position symbol");
      return;
    }
    if (Symbol() != symbol)
      continue;
    long positionType;
    if (!PositionGetInteger(POSITION_TYPE, positionType))
    {
      Print("Failed to get position type");
      return;
    }
    double entryPrice;
    if (!PositionGetDouble(POSITION_PRICE_OPEN, entryPrice))
    {
      Print("Failed to get position open price");
      return;
    }
    double stopLoss;
    if (!PositionGetDouble(POSITION_SL, stopLoss))
    {
      Print("Failed to get position stop loss");
      return;
    }

    string comment = PositionGetString(POSITION_COMMENT);
    string breakout = StringSubstr(comment, 9);
    double stopDistance = StringToDouble(breakout);

    double trail = NormalizeDouble(stopDistance * InpTrailingStop, Digits());
    int multiplier = ((int)MathFloor(MathAbs(currentPrice - entryPrice) / trail));
    double newStopLoss = 0;

    if (multiplier < 1)
      continue;

    if (positionType == POSITION_TYPE_BUY && currentPrice > entryPrice)
    {
      newStopLoss = entryPrice + trail * (multiplier - 1);
    }
    else if (positionType == POSITION_TYPE_SELL && currentPrice < entryPrice)
    {
      newStopLoss = entryPrice - trail * (multiplier - 1);
    }
    newStopLoss = NormalizeDouble(newStopLoss, Digits());

    // draw hline
    // if (plot)
    // {
    //   string name = "Trail" + (string)ticket;
    //   ObjectCreate(0, name, OBJ_HLINE, 0, 0,newStopLoss);
    // }

    if (newStopLoss == stopLoss || newStopLoss == 0 || (positionType == POSITION_TYPE_BUY && newStopLoss < stopLoss) || (positionType == POSITION_TYPE_SELL && newStopLoss > stopLoss))
      continue;

    trade.PositionModify(ticket, newStopLoss, 0);
    if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
    {
      Print("Failed to modify position. Result: " + (string)trade.ResultRetcode() + " - " + trade.ResultRetcodeDescription());
      return;
    }
  }
}