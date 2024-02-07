#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

input group "========= General settings =========";
input long InpMagicNumber = 9000;                  // Magic number
input double InpRisk = 1.0;                        // Risk size
input ENUM_TIMEFRAMES InpAtrTimeFrame = PERIOD_H1; // atr sl timeFrame
input ENUM_TIMEFRAMES InpCloseTime = PERIOD_H4;    // Close time

input group "========= Importance =========";
input bool InpImportance_low = false;      // low
input bool InpImportance_moderate = false; // moderate
input bool InpImportance_high = true;      // high

MqlCalendarValue hist[];
MqlCalendarValue news[];

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{

   if (IsNewBar(PERIOD_D1))
      GetCalendarValue(hist);
   IsNewsEvent();
   CheckTrades();
}

bool IsNewBar(ENUM_TIMEFRAMES timeFrame)
{
   static datetime previousTime = 0;
   datetime currentTime = iTime(Symbol(), timeFrame, 0);
   if (previousTime != currentTime)
   {
      previousTime = currentTime;
      return true;
   }
   return false;
}

double AtrValue()
{
   double priceArray[];
   int atrDef = iATR(Symbol(), InpAtrTimeFrame, 999);
   ArraySetAsSeries(priceArray, true);
   CopyBuffer(atrDef, 0, 0, 1, priceArray);
   double atrValue = NormalizeDouble(priceArray[0], Digits());
   return atrValue;
}

double Volume()
{
   double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRisk / 100;
   double moneyLotStep = (AtrValue() / tickSize) * tickValue * lotStep;

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

void GetCalendarValue(MqlCalendarValue &values[])
{
   datetime startTime = iTime(Symbol(), PERIOD_D1, 0);
   datetime endTime = startTime + PeriodSeconds(PERIOD_D1);
   ArrayFree(values);
   CalendarValueHistory(values, startTime, endTime, NULL, NULL);
}

void IsNewsEvent()
{
   GetCalendarValue(news);
   int amount = ArraySize(news);
   if (amount != ArraySize(hist))
      return;

   for (int i = amount - 1; i >= 0; i--)
   {

      MqlCalendarEvent event;
      CalendarEventById(news[i].event_id, event);

      MqlCalendarEvent histEvent;
      CalendarEventById(hist[i].event_id, event);
      if (event.id != histEvent.id)
         return;

      MqlCalendarCountry country;
      CalendarCountryById(event.country_id, country);

      if (event.importance == CALENDAR_IMPORTANCE_NONE)
         continue;
      if (event.importance == CALENDAR_IMPORTANCE_LOW && !InpImportance_low)
         continue;
      if (event.importance == CALENDAR_IMPORTANCE_MODERATE && !InpImportance_moderate)
         continue;
      if (event.importance == CALENDAR_IMPORTANCE_HIGH && !InpImportance_high)
         continue;

      string currency = country.currency;
      string margin = SymbolInfoString(Symbol(), SYMBOL_CURRENCY_MARGIN);
      string profit = SymbolInfoString(Symbol(), SYMBOL_CURRENCY_PROFIT);
      if (currency != margin && currency != profit)
         continue;

      ENUM_CALENDAR_EVENT_IMPACT newsImpact = news[i].impact_type;
      ENUM_CALENDAR_EVENT_IMPACT histImpact = hist[i].impact_type;
      if (!(newsImpact != CALENDAR_IMPACT_NA && histImpact == CALENDAR_IMPACT_NA))
         continue;

      string msg = (newsImpact == CALENDAR_IMPACT_POSITIVE ? "+" : "-") + currency + event.name;
      bool isBuy = (currency == margin && newsImpact == CALENDAR_IMPACT_POSITIVE) ||
                   (currency != margin && newsImpact == CALENDAR_IMPACT_NEGATIVE);
      executeTrade(isBuy, msg);
      hist[i] = news[i];
   }
}

void executeTrade(bool isBuy, string msg)
{
   if (isBuy)
   {
      double stopLoss = NormalizeDouble(SymbolInfoDouble(Symbol(), SYMBOL_ASK) - AtrValue(), Digits());
      trade.Buy(Volume(), NULL, 0, stopLoss, 0, msg);
   }
   else
   {
      double stopLoss = NormalizeDouble(SymbolInfoDouble(Symbol(), SYMBOL_BID) + AtrValue(), Digits());
      trade.Sell(Volume(), NULL, 0, stopLoss, 0, msg);
   }
   if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
   {
      Print("Failed to open position. Result: " + (string)trade.ResultRetcode() + " - " + trade.ResultRetcodeDescription());
      return;
   }
   Print(msg);
}

void CheckTrades()
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
      if (symbol != Symbol())
         continue;
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
      double takeProfit;
      if (!PositionGetDouble(POSITION_TP, takeProfit))
      {
         Print("Failed to get position take profit");
         return;
      }
      long positionType;
      if (!PositionGetInteger(POSITION_TYPE, positionType))
      {
         Print("Failed to get position type");
         return;
      }
      datetime openTime;
      if (!PositionGetInteger(POSITION_TIME, openTime))
      {
         Print("Failed to get position open time");
         return;
      }

      // check for close
      if (TimeCurrent() > openTime + PeriodSeconds(InpCloseTime))
      {
         trade.PositionClose(ticket);
         if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
         {
            Print("Failed to close position. Result: " + (string)trade.ResultRetcode() + " - " + trade.ResultRetcodeDescription());
            return;
         }
         continue;
      }

      // check for be
      if (entryPrice == stopLoss)
         continue;

      double bePrice = 0;
      if (positionType == POSITION_TYPE_BUY)
      {
         bePrice = NormalizeDouble(entryPrice + MathAbs(entryPrice - stopLoss), Digits());
      }
      else if (positionType == POSITION_TYPE_SELL)
      {
         bePrice = NormalizeDouble(entryPrice - MathAbs(entryPrice - stopLoss), Digits());
      }
      if (bePrice == 0)
         continue;
      if ((positionType == POSITION_TYPE_BUY && SymbolInfoDouble(Symbol(), SYMBOL_BID) > bePrice) || (positionType == POSITION_TYPE_SELL && SymbolInfoDouble(Symbol(), SYMBOL_ASK) < bePrice))
      {
         trade.PositionModify(ticket, entryPrice, 0);
         if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
         {
            Print("Failed to modify position. Result: " + (string)trade.ResultRetcode() + " - " + trade.ResultRetcodeDescription());
            return;
         }
         continue;
      }
   }
}
