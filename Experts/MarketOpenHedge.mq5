//+------------------------------------------------------------------+
//|                                              MarketOpenHedge.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

input double Lots = 0.01;
input double LotsMultiplier = 1.5;
input int TpPoints = 100;
input int DistancePoints = 100;
input int TimeStartHour = 8;
input int TimeStartMin = 0;

double upperLine, lowerLine;
MqlTick tick;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  //---

  //---
  return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  //---
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  SymbolInfoTick(Symbol(), tick);

  double highestLotSize = 0;
  int lastDirection = 0;
  int totalProfitPoints = 0;
  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong ticket = PositionGetTicket(i);
    if (PositionSelectByTicket(ticket))
    {
      double posLots = PositionGetDouble(POSITION_VOLUME);

      if (posLots > highestLotSize)
      {
        highestLotSize = posLots;
        if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
          lastDirection = 1;
        }
        else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
          lastDirection = -1;
        }
      }

      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
        totalProfitPoints += (int)((tick.bid - PositionGetDouble(POSITION_PRICE_OPEN)) / Point() * posLots / Lots);
      }
      else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      {
        totalProfitPoints += (int)((PositionGetDouble(POSITION_PRICE_OPEN) - tick.ask) / Point() * posLots / Lots);
      }
    }
  }

  if (totalProfitPoints > TpPoints)
  {
    Print("Total profit points: ", totalProfitPoints);
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
      ulong ticket = PositionGetTicket(i);
      if (PositionSelectByTicket(ticket))
      {
        trade.PositionClose(ticket);
      }
    }

    highestLotSize = 0;
    lastDirection = 0;
    upperLine = 0;
    lowerLine = 0;
  }

  MqlDateTime structTime;
  TimeCurrent(structTime);

  structTime.hour = TimeStartHour;
  structTime.min = TimeStartMin;
  structTime.sec = 0;

  datetime startTime = StructToTime(structTime);

  if (TimeCurrent() < startTime && highestLotSize == 0)
  {
    upperLine = 0;
    lowerLine = 0;
  }

  if (TimeCurrent() > startTime && TimeCurrent() < startTime + 10 && upperLine == 0 && lowerLine == 0)
  {
    upperLine = tick.last + DistancePoints * Point();
    lowerLine = tick.last - DistancePoints * Point();
  }

  if (upperLine > 0 && lowerLine > 0)
  {
    double lots = Lots;
    if (highestLotSize > 0)
      lots = highestLotSize * LotsMultiplier;
    lots = NormalizeDouble(lots, 2);

    if (tick.last > upperLine)
    {
      if (highestLotSize == 0 || lastDirection < 0)
      {
        trade.Buy(lots);
      }
    }
    else if (tick.last < lowerLine)
    {
      if (highestLotSize == 0 || lastDirection > 0)
      {
        trade.Sell(lots);
      }
    }
  }

  Comment("Server time: ", TimeCurrent(), "\n",
          "Open time: ", startTime, "\n",
          "Upper line: ", upperLine, "\n",
          "Lower line: ", lowerLine, "\n",
          "Last: ", tick.last, "\n",
          "Profit points: ", totalProfitPoints, "\n",
          "Last direction: ", lastDirection, "\n",
          "Highest lot size: ", highestLotSize);

  // draw lines
  ObjectDelete(NULL, "upperLine");
  ObjectDelete(NULL, "lowerLine");
  ObjectCreate(NULL, "upperLine", OBJ_HLINE, 0, TimeCurrent(), upperLine);
  ObjectCreate(NULL, "lowerLine", OBJ_HLINE, 0, TimeCurrent(), lowerLine);
}
